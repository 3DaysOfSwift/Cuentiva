import Foundation

actor BundledBookRepository: BookRepository {
    let url: URL?
    init(url: URL? = Bundle.main.url(forResource: "Books", withExtension: "json")) { self.url = url }
    func books() throws -> [Book] {
        guard let url else { throw AppFailure.invalidBook }
        let books = try JSONDecoder().decode([Book].self, from: Data(contentsOf: url))
        guard Set(books.map(\.id)).count == books.count,
              books.allSatisfy({ !$0.sentences.isEmpty && Set($0.fullText.map(\.id)).count == $0.fullText.count && $0.fullText.allSatisfy { !$0.spanish.isEmpty && !$0.english.isEmpty } }) else { throw AppFailure.invalidBook }
        return books
    }
}
actor LocalProgressRepository: ProgressRepository {
    let url: URL
    init(url: URL) { self.url = url }
    func load() throws -> LearnerProgress {
        guard FileManager.default.fileExists(atPath: url.path) else { return .init() }
        let progress = try JSONDecoder().decode(LearnerProgress.self, from: Data(contentsOf: url))
        guard progress.schemaVersion == 1 else { throw AppFailure.unavailable("This progress file was created by a newer version of Cuentiva.") }
        return progress
    }
    func save(_ progress: LearnerProgress) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(progress).write(to: url, options: .atomic)
    }
}
actor LocalContributionRepository: ContributionRepository {
    let url: URL
    init(url: URL) { self.url = url }
    func drafts() throws -> [Contribution] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([Contribution].self, from: Data(contentsOf: url))
    }
    func save(_ draft: Contribution) throws {
        var all = try drafts()
        all.removeAll { $0.id == draft.id }; all.append(draft)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(all).write(to: url, options: .atomic)
    }
}
