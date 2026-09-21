//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Testing
@testable import Cuentiva

@Suite @MainActor struct AppModelTests {
    @Test func compositionKeepsInjectedFeaturesAndSharesAccessAndProgress() async throws {
        let (purchases, progress, library, learning, contributions) = try await makeViewModelTestGraph()
        let fantasy = FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator())
        let chat = ChatManager(generator: CompositionChatGenerator(), progress: progress)
        let audio = TestAudio()
        let app = AppModel(library: library, progress: progress, purchases: purchases,
                           learning: learning, contributions: contributions, fantasy: fantasy,
                           chat: chat, makeAudio: { audio })
        #expect(app.library === library)
        #expect(app.progress === progress)
        #expect(app.purchases === purchases)
        #expect(app.learning === learning)
        #expect(app.contributions === contributions)
        #expect(app.fantasy === fantasy)
        #expect(app.chat === chat)
        #expect(app.makeAudio() === audio)
        #expect(app.languageTerms.term("noun") != nil)
        let book = sample()
        #expect(!app.practice.allowed(book))
        #expect(!app.verbs.eligible)
        #expect(app.verbs.practiceDays == 0)
        await #expect(throws: AppFailure.self) { try await app.verbs.perform(.claimGift) }
        purchases.hasAccess = true
        try await app.progress.recordEncounter(book: book, sentence: book.sentences[0])
        _ = try await app.learning.finishReading(book)
        #expect(app.practice.allowed(book))
        #expect(app.verbs.practiceDays == 1)
        #expect(app.practice.coins == app.chat.coins)
        #expect(app.chat.coins == 1)
        purchases.hasAccess = false
        #expect(!app.practice.allowed(book))
    }
}

private struct CompositionChatGenerator: ChatGenerator {
    func availabilityMessage() async -> String? { nil }
    func reply(to request: ChatRequest) async throws -> ChatReply {
        throw AppFailure.unavailable("Composition tests must not generate replies.")
    }
}
