import Foundation

enum LessonAdvance: Sendable {
    case position(Int, revisitingSkipped: Bool)
    case completed(CompletionReceipt)
}
@MainActor protocol LearningFeature: AnyObject, Sendable {
    func canRead(_ book: Book) -> Bool
    func position(_ book: Book) -> Int
    func practiced(_ book: Book, sentence: Sentence) -> Bool
    func check(book: Book, sentence: Sentence, answer: String) async throws -> AnswerFeedback
    func move(book: Book, position: Int) async throws
    func finish(_ book: Book) async throws -> CompletionReceipt
    func advance(book: Book, from index: Int, skip: Bool) async throws -> LessonAdvance
    func nextUnpracticed(_ book: Book) -> Int?
}
@MainActor final class LearningManager: LearningFeature {
    private let purchases: any PurchaseFeature
    private let progress: any ProgressFeature
    init(purchases: any PurchaseFeature, progress: any ProgressFeature) { self.purchases = purchases; self.progress = progress }
    func canRead(_ book: Book) -> Bool { purchases.hasAccess || (book.id == "cafe" && !progress.snapshot.completed.contains(book.id)) }
    func position(_ book: Book) -> Int { min(progress.snapshot.positions[book.id] ?? 0, book.sentences.count - 1) }
    func practiced(_ book: Book, sentence: Sentence) -> Bool { progress.snapshot.attempts[book.id, default: []].contains(sentence.id) }
    func check(book: Book, sentence: Sentence, answer: String) async throws -> AnswerFeedback {
        guard canRead(book) else { throw AppFailure.locked }
        guard book.sentences.contains(sentence) else { throw AppFailure.invalidBook }
        guard !WordComparison.words(answer).isEmpty else { throw AppFailure.emptyAnswer }
        let feedback = WordComparison.compare(expected: sentence.spanish, received: answer)
        try await progress.recordAttempt(book: book, sentence: sentence)
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
    func advance(book: Book, from index: Int, skip: Bool) async throws -> LessonAdvance {
        guard canRead(book) else { throw AppFailure.locked }
        guard book.sentences.indices.contains(index) else { throw AppFailure.invalidBook }
        guard skip || practiced(book, sentence: book.sentences[index]) else {
            throw AppFailure.unavailable("Try Speak or Write, then check your answer. You can also skip and return later.")
        }
        if index < book.sentences.count - 1 {
            try await move(book: book, position: index + 1)
            return .position(index + 1, revisitingSkipped: false)
        }
        if let missing = nextUnpracticed(book) {
            try await move(book: book, position: missing)
            return .position(missing, revisitingSkipped: true)
        }
        return .completed(try await finish(book))
    }
    func nextUnpracticed(_ book: Book) -> Int? { book.sentences.firstIndex { !practiced(book, sentence: $0) } }
}
