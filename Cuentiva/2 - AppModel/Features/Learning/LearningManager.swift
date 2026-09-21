//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation

enum LessonAdvance: Sendable {
    case position(Int)
    case fullReading
    case bookFinished
}
@MainActor protocol LearningFeature: AnyObject, Sendable {
    func canRead(_ book: Book) -> Bool
    func position(_ book: Book) -> Int
    func check(book: Book, sentence: Sentence, answer: String) async throws -> AnswerFeedback
    func move(book: Book, position: Int) async throws
    func finish(_ book: Book) async throws -> CompletionReceipt
    func finishChapterTwo(_ book: Book) async throws -> Int
    func finishReading(_ book: Book) async throws -> CompletionReceipt
    func advance(book: Book, from index: Int) async throws -> LessonAdvance
}
@MainActor final class LearningManager: LearningFeature {
    private let purchases: any PurchaseFeature
    private let progress: any ProgressFeature
    init(purchases: any PurchaseFeature, progress: any ProgressFeature) { self.purchases = purchases; self.progress = progress }
    func canRead(_ book: Book) -> Bool { purchases.hasAccess || (book.id == "cafe" && !progress.snapshot.completed.contains(book.id)) }
    func position(_ book: Book) -> Int {
        let attempts = progress.snapshot.attempts[book.id, default: []]
        // A rewritten edition has new sentence IDs. Resume it at the beginning
        // instead of carrying an old edition's position into unrelated text.
        if book.editorialRevision != nil, !attempts.isEmpty,
           attempts.isDisjoint(with: Set(book.fullText.map(\.id))) { return 0 }
        return min(progress.snapshot.positions[book.id] ?? 0, max(0, book.fullText.count - 1))
    }
    func check(book: Book, sentence: Sentence, answer: String) async throws -> AnswerFeedback {
        guard canRead(book) else { throw AppFailure.locked }
        guard book.fullText.contains(sentence) else { throw AppFailure.invalidBook }
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
    func finishChapterTwo(_ book: Book) async throws -> Int {
        guard canRead(book) else { throw AppFailure.locked }
        return try await progress.finishChapterTwo(book: book)
    }
    func finishReading(_ book: Book) async throws -> CompletionReceipt {
        guard canRead(book) else { throw AppFailure.locked }
        return try await progress.completeReading(book: book)
    }
    func advance(book: Book, from index: Int) async throws -> LessonAdvance {
        guard canRead(book) else { throw AppFailure.locked }
        return try await progress.advanceReading(book: book, from: index)
    }
}
