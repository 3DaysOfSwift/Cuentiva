import Foundation

enum LessonAdvance: Sendable {
    case position(Int)
    case scriptReading
    case completed(CompletionReceipt)
}
@MainActor protocol LearningFeature: AnyObject, Sendable {
    func canRead(_ book: Book) -> Bool
    func position(_ book: Book) -> Int
    func check(book: Book, sentence: Sentence, answer: String) async throws -> AnswerFeedback
    func move(book: Book, position: Int) async throws
    func finish(_ book: Book) async throws -> CompletionReceipt
    func finishScript(_ book: Book) async throws -> CompletionReceipt
    func advance(book: Book, from index: Int) async throws -> LessonAdvance
}
@MainActor final class LearningManager: LearningFeature {
    private let purchases: any PurchaseFeature
    private let progress: any ProgressFeature
    init(purchases: any PurchaseFeature, progress: any ProgressFeature) { self.purchases = purchases; self.progress = progress }
    func canRead(_ book: Book) -> Bool { purchases.hasAccess || (book.id == "cafe" && !progress.snapshot.completed.contains(book.id)) }
    func position(_ book: Book) -> Int { min(progress.snapshot.positions[book.id] ?? 0, book.kind == .movieScript ? book.sentences.count : book.sentences.count - 1) }
    func check(book: Book, sentence: Sentence, answer: String) async throws -> AnswerFeedback {
        guard canRead(book) else { throw AppFailure.locked }
        guard book.sentences.contains(sentence) else { throw AppFailure.invalidBook }
        guard !WordComparison.words(answer).isEmpty else { throw AppFailure.emptyAnswer }
        let feedback = WordComparison.compare(expected: sentence.spanish, received: answer)
        try await progress.recordEncounter(book: book, sentence: sentence)
        return feedback
    }
    func move(book: Book, position: Int) async throws {
        guard canRead(book) else { throw AppFailure.locked }
        try await progress.savePosition(book: book, position: position)
    }
    func finish(_ book: Book) async throws -> CompletionReceipt {
        guard canRead(book) else { throw AppFailure.locked }
        return try await progress.complete(book: book)
    }
    func finishScript(_ book: Book) async throws -> CompletionReceipt {
        guard canRead(book) else { throw AppFailure.locked }
        return try await progress.completeScript(book: book)
    }
    func advance(book: Book, from index: Int) async throws -> LessonAdvance {
        guard canRead(book) else { throw AppFailure.locked }
        return try await progress.advanceReading(book: book, from: index)
    }
}
