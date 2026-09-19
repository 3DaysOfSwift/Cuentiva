import Foundation

actor BundledBookRepository: BookRepository {
    let url: URL?
    init(url: URL? = Bundle.main.url(forResource: "Books", withExtension: "json")) { self.url = url }
    func books() throws -> [Book] {
        guard let url else { throw AppFailure.invalidBook }
        let books = try JSONDecoder().decode([Book].self, from: Data(contentsOf: url))
        guard Set(books.map(\.id)).count == books.count,
            books.allSatisfy({
                !$0.sentences.isEmpty && Set($0.fullText.map(\.id)).count == $0.fullText.count
                    && $0.fullText.allSatisfy { !$0.spanish.isEmpty && !$0.english.isEmpty }
            })
        else { throw AppFailure.invalidBook }
        return books
    }
}
actor LocalProgressRepository: ProgressRepository {
    private let url: URL
    private let store: SwiftDataStore
    private var savedProgress: LearnerProgress?
    init(url: URL, store: SwiftDataStore? = nil) {
        self.url = url
        self.store = store ?? SwiftDataStore(url: url.appendingPathExtension("store"))
    }
    func load() async throws -> LearnerProgress {
        if let rows = try await store.read("progress") { return try remember(rows) }
        let legacy =
            FileManager.default.fileExists(atPath: url.path)
            ? try JSONDecoder().decode(LearnerProgress.self, from: Data(contentsOf: url)) : LearnerProgress()
        guard legacy.schemaVersion == 1 else {
            throw AppFailure.unavailable("This progress file was created by a newer version of Cuentiva.")
        }
        let rows = try await store.replace("progress", values: ProgressRecords.encode(legacy), onlyIfAbsent: true)
        return try remember(rows)
    }
    func save(_ progress: LearnerProgress) async throws {
        guard progress.schemaVersion == 1 else { throw AppFailure.unavailable("Unsupported progress version.") }
        if savedProgress == nil { _ = try await load() }
        let changes = try ProgressRecords.changes(progress, previous: savedProgress)
        try await store.apply("progress", changes: changes)
        savedProgress = progress
    }
    private func remember(_ rows: [String: Data]) throws -> LearnerProgress {
        let value = try ProgressRecords.decode(rows)
        LegacyJSONCleanup.remove([url])
        savedProgress = value
        return value
    }
}
actor LocalContributionRepository: ContributionRepository {
    private let url: URL
    private let store: SwiftDataStore
    init(url: URL, store: SwiftDataStore? = nil) {
        self.url = url
        self.store = store ?? SwiftDataStore(url: url.appendingPathExtension("store"))
    }
    func drafts() async throws -> [Contribution] {
        if let rows = try await store.read("drafts") {
            let drafts = try rows.values.map { try RecordCoding.decode(Contribution.self, $0) }.sorted {
                $0.id.uuidString < $1.id.uuidString
            }
            LegacyJSONCleanup.remove([url])
            return drafts
        }
        let legacy =
            FileManager.default.fileExists(atPath: url.path)
            ? try JSONDecoder().decode([Contribution].self, from: Data(contentsOf: url)) : []
        guard Set(legacy.map(\.id)).count == legacy.count else {
            throw AppFailure.unavailable("Duplicate saved draft identifiers.")
        }
        let rows = try Dictionary(uniqueKeysWithValues: legacy.map { ($0.id.uuidString, try RecordCoding.encode($0)) })
        _ = try await store.replace("drafts", values: rows, onlyIfAbsent: true)
        return try await drafts()
    }
    func remove(_ id: UUID) async throws {
        let values = try await drafts().filter { $0.id != id }
        try await replace(values)
    }
    func save(_ draft: Contribution) async throws {
        var values = try await drafts().filter { $0.id != draft.id }
        values.append(draft)
        try await replace(values)
    }
    private func replace(_ values: [Contribution]) async throws {
        try await store.replace(
            "drafts",
            values: Dictionary(uniqueKeysWithValues: values.map { ($0.id.uuidString, try RecordCoding.encode($0)) }))
    }
}
