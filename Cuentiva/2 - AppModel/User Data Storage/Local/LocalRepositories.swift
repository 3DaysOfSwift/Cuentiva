import Foundation
import OSLog

actor BundledBookRepository: BookRepository {
    private let logger = Logger(subsystem: "com.3DaysOfSwiftConcurrency.Cuentiva", category: "LibraryLoading")
    private let url: URL?
    private let introductionURL: URL?
    init(url: URL? = Bundle.main.url(forResource: "Library", withExtension: "dat"),
         introductionURL: URL? = Bundle.main.url(forResource: "Introduction", withExtension: "dat")) {
        self.url = url
        self.introductionURL = introductionURL
    }
    func introduction() async throws -> Book {
        guard let introductionURL else { throw AppFailure.invalidBook }
        let started = ContinuousClock.now
        let library = try BinaryLibrary(url: introductionURL)
        let readFinished = ContinuousClock.now
        let book = try library.book(at: 0)
        logger.info("Introduction DAT: read/header \(String(describing: started.duration(to: readFinished)), privacy: .public); book construction \(String(describing: readFinished.duration(to: .now)), privacy: .public)")
        guard library.count == 1, book.id == "cafe" else { throw AppFailure.invalidBook }
        return book
    }
    func books() throws -> [Book] {
        guard let url else { throw AppFailure.invalidBook }
        let started = ContinuousClock.now
        let library = try BinaryLibrary(url: url)
        let readFinished = ContinuousClock.now
        let books = try library.books()
        let constructionFinished = ContinuousClock.now
        guard Set(books.map(\.id)).count == books.count,
            books.allSatisfy({
                !$0.sentences.isEmpty && Set($0.fullText.map(\.id)).count == $0.fullText.count
                    && $0.fullText.allSatisfy { !$0.spanish.isEmpty && !$0.english.isEmpty }
            }) else { throw AppFailure.invalidBook }
        logger.info("Library DAT: read/header \(String(describing: started.duration(to: readFinished)), privacy: .public); book construction \(String(describing: readFinished.duration(to: constructionFinished)), privacy: .public); validation \(String(describing: constructionFinished.duration(to: .now)), privacy: .public)")
        return books
    }
}
actor LocalProgressRepository: ProgressRepository {
    private let url: URL
    private let store: SwiftDataStore
    private var savedProgress: LearnerProgress?
    private var hasStoredProgress = false
    init(url: URL, store: SwiftDataStore) {
        self.url = url
        self.store = store
    }
    func load() async throws -> LearnerProgress {
        let started = ContinuousClock.now
        defer {
            Logger(subsystem: "com.3DaysOfSwiftConcurrency.Cuentiva", category: "LibraryLoading")
                .info("Progress load including storage wait: \(String(describing: started.duration(to: .now)), privacy: .public)")
        }
        if let rows = try await store.readIfPresent("progress") { return try remember(rows) }
        guard FileManager.default.fileExists(atPath: url.path) else {
            let empty = LearnerProgress()
            savedProgress = empty
            return empty
        }
        let legacy = try JSONDecoder().decode(LearnerProgress.self, from: Data(contentsOf: url))
        guard legacy.schemaVersion == 1 else {
            throw AppFailure.unavailable("This progress file was created by a newer version of Cuentiva.")
        }
        let seedStarted = ContinuousClock.now
        let rows = try await store.replace("progress", values: ProgressRecords.encode(legacy), onlyIfAbsent: true)
        Logger(subsystem: "com.3DaysOfSwiftConcurrency.Cuentiva", category: "LibraryLoading")
            .info("Initial progress preparation/save: \(String(describing: seedStarted.duration(to: .now)), privacy: .public)")
        return try remember(rows)
    }
    func save(_ progress: LearnerProgress) async throws {
        guard progress.schemaVersion == 1 else { throw AppFailure.unavailable("Unsupported progress version.") }
        if savedProgress == nil { _ = try await load() }
        if hasStoredProgress {
            let changes = try ProgressRecords.changes(progress, previous: savedProgress)
            try await store.apply("progress", changes: changes)
        } else {
            try await store.replace("progress", values: ProgressRecords.encode(progress))
            hasStoredProgress = true
        }
        savedProgress = progress
    }
    private func remember(_ rows: [String: Data]) throws -> LearnerProgress {
        let value = try ProgressRecords.decode(rows)
        LegacyJSONCleanup.remove([url])
        savedProgress = value
        hasStoredProgress = true
        return value
    }
}
actor LocalContributionRepository: ContributionRepository {
    private let url: URL
    private let store: SwiftDataStore
    init(url: URL, store: SwiftDataStore) {
        self.url = url
        self.store = store
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
