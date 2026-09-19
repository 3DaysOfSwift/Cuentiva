import Foundation
import OSLog
import SwiftData

/// Version-one local schema. Each key represents a book, word, day, story or chat turn,
/// never an entire mutable user archive. Payloads are binary property lists.
@Model final class StoredRecord {
    @Attribute(.unique) var identity: String
    var collection: String
    var key: String
    var payload: Data
    init(collection: String, key: String, payload: Data) {
        self.identity = collection + ":" + key
        self.collection = collection
        self.key = key
        self.payload = payload
    }
}

enum CuentivaStoreSchema: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [StoredRecord.self] }
}
enum CuentivaStoreMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [CuentivaStoreSchema.self] }
    static var stages: [MigrationStage] { [] }
}

enum RecordCoding {
    private struct Box<Value: Codable>: Codable { let value: Value }
    static func encode<T: Codable>(_ value: T) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(Box(value: value))
    }
    static func decode<T: Codable>(_ type: T.Type, _ data: Data) throws -> T {
        try PropertyListDecoder().decode(Box<T>.self, from: data).value
    }
}

/// All context access and saves are serialized on this model actor, not MainActor.
@ModelActor actor DatabaseWorker {
    #if DEBUG
        private var failNextSave = false
        func failNextCommitForTesting() { failNextSave = true }
    #endif
    private func commit() throws {
        #if DEBUG
            if failNextSave {
                failNextSave = false
                throw AppFailure.unavailable("Injected database save failure")
            }
        #endif
        try modelContext.save()
    }
    private func fetch(_ collection: String) throws -> [StoredRecord] {
        try modelContext.fetch(FetchDescriptor<StoredRecord>(predicate: #Predicate { $0.collection == collection }))
    }
    func read(_ collection: String) throws -> [String: Data]? {
        let records = try fetch(collection)
        guard records.contains(where: { $0.key == "__ready" }) else { return nil }
        return Dictionary(uniqueKeysWithValues: records.filter { $0.key != "__ready" }.map { ($0.key, $0.payload) })
    }
    @discardableResult func replace(_ collection: String, values: [String: Data], onlyIfAbsent: Bool = false) throws
        -> [String: Data]
    {
        modelContext.autosaveEnabled = false
        let records = try fetch(collection)
        if onlyIfAbsent, records.contains(where: { $0.key == "__ready" }) {
            return Dictionary(uniqueKeysWithValues: records.filter { $0.key != "__ready" }.map { ($0.key, $0.payload) })
        }
        var desired = values
        desired["__ready"] = Data([1])
        do {
            for record in records {
                if let value = desired.removeValue(forKey: record.key) {
                    if record.payload != value { record.payload = value }
                } else {
                    modelContext.delete(record)
                }
            }
            for (key, value) in desired {
                modelContext.insert(StoredRecord(collection: collection, key: key, payload: value))
            }
            if modelContext.hasChanges { try commit() }
            return values
        } catch {
            modelContext.rollback()
            throw error
        }
    }
    /// One transaction for a small set of indexed records. No collection-wide fetch.
    func apply(_ collection: String, changes: RecordChanges) throws {
        guard !changes.isEmpty else { return }
        modelContext.autosaveEnabled = false
        do {
            for key in changes.removals {
                if let record = try record(collection, key: key) { modelContext.delete(record) }
            }
            for (key, payload) in changes.upserts {
                if let record = try record(collection, key: key) {
                    if record.payload != payload { record.payload = payload }
                } else {
                    modelContext.insert(StoredRecord(collection: collection, key: key, payload: payload))
                }
            }
            if modelContext.hasChanges { try commit() }
        } catch {
            modelContext.rollback()
            throw error
        }
    }
    private func record(_ collection: String, key: String) throws -> StoredRecord? {
        let identity = collection + ":" + key
        var query = FetchDescriptor<StoredRecord>(predicate: #Predicate { $0.identity == identity })
        query.fetchLimit = 1
        return try modelContext.fetch(query).first
    }
    func put(_ collection: String, key: String, data: Data) throws {
        var changes = RecordChanges()
        changes[key] = data
        try apply(collection, changes: changes)
    }
    func value(_ collection: String, key: String) throws -> Data? {
        try record(collection, key: key)?.payload
    }
}

/// Core Data container creation is serialized across independent test graphs.
/// Normal database operations remain isolated to each store’s worker actor.
private actor StoreOpener {
    static let shared = StoreOpener()
    func open(at url: URL) throws -> DatabaseWorker {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let schema = Schema(versionedSchema: CuentivaStoreSchema.self)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: schema, migrationPlan: CuentivaStoreMigrationPlan.self, configurations: [configuration])
        return DatabaseWorker(modelContainer: container)
    }
}

/// Lazy opening avoids building a persistent container in AppModel's main-thread initializer.
actor SwiftDataStore {
    private let url: URL
    private var opening: Task<DatabaseWorker, Error>?
    init(url: URL) { self.url = url }
    private func worker() async throws -> DatabaseWorker {
        if let opening { return try await opening.value }
        let url = url
        let task = Task { try await StoreOpener.shared.open(at: url) }
        opening = task
        do { return try await task.value } catch {
            opening = nil
            throw error
        }
    }
    #if DEBUG
        func failNextCommitForTesting() async throws { try await worker().failNextCommitForTesting() }
    #endif
    func read(_ collection: String) async throws -> [String: Data]? { try await worker().read(collection) }
    @discardableResult func replace(_ collection: String, values: [String: Data], onlyIfAbsent: Bool = false)
        async throws -> [String: Data]
    {
        try await worker().replace(collection, values: values, onlyIfAbsent: onlyIfAbsent)
    }
    func apply(_ collection: String, changes: RecordChanges) async throws {
        guard !changes.isEmpty else { return }
        try await worker().apply(collection, changes: changes)
    }
    func put(_ collection: String, key: String, data: Data) async throws {
        try await worker().put(collection, key: key, data: data)
    }
    func value(_ collection: String, key: String) async throws -> Data? {
        try await worker().value(collection, key: key)
    }
}

/// Called only after the replacement database records have been read successfully.
/// A cleanup failure must not turn a committed migration into a failed load.
enum LegacyJSONCleanup {
    static func remove(_ urls: [URL]) {
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            do { try FileManager.default.removeItem(at: url) } catch {
                Logger(subsystem: "com.3DaysOfSwiftConcurrency.Cuentiva", category: "Storage")
                    .error("Could not remove an obsolete local file; cleanup will retry on the next load.")
            }
        }
    }
}
