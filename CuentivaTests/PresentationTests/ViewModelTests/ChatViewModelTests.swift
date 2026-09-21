//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct ChatViewModelTests {
    @Test func restoredPaidChatBypassesAdmissionAndKeepsTranscript() async {
        let feature = ChatViewModelFeature()
        feature.coins = 0
        feature.sessionPaid = true
        feature.sessionAuthorized = true
        feature.savedConversation.messages = [ChatMessage(role: .learner, text: "Hola")]
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: TestAudio())
        await model.prepare()
        #expect(model.admissionPhase == .finished)
        #expect(!model.admissionVisible)
        #expect(model.displayedCoins == 0)
        #expect(model.messages.count == 1)
        model.draft = "Otra pregunta"
        #expect(model.canSend)
    }

    @Test func exhaustedAllowancePresentsRenewalWithoutClearingMessages() async throws {
        let feature = ChatViewModelFeature()
        feature.sessionPaid = true
        feature.sessionAuthorized = true
        feature.savedConversation.messages = [ChatMessage(role: .learner, text: "Hola")]
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: TestAudio())
        await model.prepare()
        model.draft = "Última pregunta"
        model.send()
        try await waitUntil { feature.reply != nil }
        feature.sessionPaid = false
        feature.sessionAuthorized = false
        feature.finishReply()
        try await waitUntil { !model.sending }
        #expect(model.admissionPhase == .ready)
        #expect(model.admissionVisible)
        #expect(model.messages.count == 1)
        #expect(model.celebrateAdmission())
        #expect(feature.sessionAuthorized)
        model.endSession()
    }

    @Test func speechHighlightTracksOnlyThePlayingMessageAndClearsWhenStopped() async {
        let feature = ChatViewModelFeature(), audio = TestAudio()
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: audio)
        let first = ChatMessage(role: .storyteller, text: "¡Hola! ¿Cómo estás?")
        let second = ChatMessage(role: .storyteller, text: "Estoy bien.")
        model.listen(first)
        audio.spokenRange = NSRange(location: 1, length: 4)
        #expect(model.spokenRange(for: first) == audio.spokenRange)
        #expect(model.spokenRange(for: second) == nil)
        audio.spokenRange = nil
        #expect(model.spokenRange(for: first) == nil)
        model.listen(second)
        audio.spokenRange = NSRange(location: 0, length: 5)
        #expect(model.spokenRange(for: first) == nil)
        #expect(model.spokenRange(for: second) == audio.spokenRange)
        model.cancel()
        #expect(model.spokenRange(for: second) == nil)
        model.listen(second)
        await model.clear()
        #expect(model.spokenRange(for: second) == nil)
        #expect(audio.spokenRates == [true, true, true])
    }

    @Test func admissionCelebratesThenReservesTheLastCoinWithoutChargingItTwice() async throws {
        let feature = ChatViewModelFeature(), gate = AdmissionPauseGate()
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: TestAudio(),
            admissionPause: { _ in try await gate.pause() })
        defer { model.endSession(); gate.release() }
        await model.prepare()
        #expect(model.celebrateAdmission())
        #expect(!model.celebrateAdmission())
        #expect(model.admissionSuccess == 1)
        #expect(model.admissionVisible)
        #expect(model.displayedCoins == 1)
        try await waitUntil { gate.waiting }
        gate.release()
        try await waitUntil { model.admissionPhase == .celebrating && gate.waiting }
        #expect(model.displayedCoins == 1)
        gate.release()
        try await waitUntil { model.admissionPhase == .balanceUpdated && gate.waiting }
        #expect(model.displayedCoins == 0)
        #expect(feature.coins == 1)
        #expect(!feature.sessionPaid)
        #expect(model.unlocked)
        gate.release()
        try await waitUntil { model.admissionPhase == .dismissing && gate.waiting }
        #expect(!model.admissionVisible)
        model.draft = "Hola"
        #expect(model.canSend)
        gate.release()
        try await waitUntil { model.admissionPhase == .finished }
        feature.coins = 0
        feature.sessionPaid = true
        #expect(model.displayedCoins == 0)
    }

    @Test func endingDuringCelebrationReleasesReservationAndRejectsLateFocus() async throws {
        let feature = ChatViewModelFeature(), gate = AdmissionPauseGate()
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: TestAudio(),
            admissionPause: { _ in try await gate.pause() })
        defer { model.endSession(); gate.release() }
        await model.prepare()
        #expect(model.celebrateAdmission())
        try await waitUntil { gate.waiting }
        gate.release()
        try await waitUntil { model.admissionPhase == .celebrating && gate.waiting }
        model.endSession()
        gate.release()
        await model.prepare()
        #expect(model.admissionPhase == .ready)
        #expect(model.admissionVisible)
        #expect(model.displayedCoins == 1)
        #expect(!feature.sessionAuthorized)
        #expect(!feature.sessionPaid)
    }

    @Test func rejectedAdmissionDoesNotCelebrateOrReserve() async {
        let feature = ChatViewModelFeature()
        feature.authorizationFailure = .unavailable("Please try again")
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: TestAudio())
        await model.prepare()
        #expect(!model.celebrateAdmission())
        #expect(model.error != nil)
        #expect(model.admissionPhase == .ready)
        #expect(model.admissionSuccess == 0)
        #expect(model.displayedCoins == 1)
        model.endSession()
    }

    @Test func suggestedEnglishIsIndependentAndResetsForANewTopic() async throws {
        let feature = ChatViewModelFeature()
        let turn = ChatTurn(question: "Hola", spanish: "Hola", english: "Hello", correction: "",
            suggestion: "Estoy en casa.", suggestionEnglish: "I am at home.")
        feature.savedConversation = ChatConversation(turns: [turn])
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: TestAudio())
        #expect(model.suggestedTurn?.suggestionEnglish == "I am at home.")
        #expect(model.suggestionTranslations.isEmpty)
        model.toggleSuggestionTranslation(turn)
        #expect(model.suggestionTranslations.contains(turn.id))
        #expect(model.translations.isEmpty)
        model.toggleSuggestionTranslation(turn)
        #expect(model.suggestionTranslations.isEmpty)
        model.toggleSuggestionTranslation(turn)
        await model.clear()
        #expect(model.suggestionTranslations.isEmpty)
    }

    @Test func ownMessageEnglishTogglesIndependently() {
        let feature = ChatViewModelFeature()
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: TestAudio())
        let first = ChatMessage(role: .learner, text: "Estoy en casa.", english: "I am at home.")
        let second = ChatMessage(role: .learner, text: "Tengo un libro.", english: "I have a book.")
        model.toggleTranslation(for: first)
        #expect(model.translations == [first.id])
        model.toggleTranslation(for: second)
        model.toggleTranslation(for: first)
        #expect(model.translations == [second.id])
        model.endSession()
        #expect(model.translations.isEmpty)
    }

    @Test func chatPlaybackUsesSlowSpeech() {
        let feature = ChatViewModelFeature(), audio = TestAudio()
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: audio)
        model.listen(ChatMessage(role: .storyteller, text: "Hola."))
        #expect(audio.spokenRates == [true])
        feature.hasAccess = false
        model.listen(ChatMessage(role: .storyteller, text: "Adiós."))
        #expect(audio.spokenRates == [true])
    }

    @Test func composerRequiresCostConfirmationForEachNewTopic() async throws {
        let feature = ChatViewModelFeature()
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: TestAudio())
        await model.prepare()
        model.draft = "Hola"
        #expect(model.canStart)
        #expect(!model.canSend)
        model.send()
        #expect(feature.messages.isEmpty)
        model.authorizeSession()
        #expect(model.canSend)
        #expect(feature.coins == 1)
        await model.clear()
        #expect(!model.canSend)
        model.endSession()
        #expect(!model.canStart)
    }

    @Test func sendingGuardsDuplicateTapsAndPreservesANewerDraft() async throws {
        let feature = ChatViewModelFeature()
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: TestAudio())
        await model.prepare()
        model.authorizeSession()
        model.draft = "Hola"
        #expect(model.canSend)
        model.send()
        model.send()
        try await waitUntil { feature.reply != nil }
        #expect(model.sending)
        #expect(!model.canSend)
        #expect(feature.messages == ["Hola"])
        model.draft = "Mi siguiente pregunta"
        feature.finishReply()
        try await waitUntil { !model.sending }
        #expect(model.draft == "Mi siguiente pregunta")
        #expect(model.error == nil)
        model.send()
        try await waitUntil { feature.reply != nil }
        feature.finishReply()
        try await waitUntil { !model.sending }
        #expect(model.draft.isEmpty)
    }

    @Test func consecutiveMessagesClearComposerImmediatelyAndKeepNewDraft() async throws {
        let feature = ChatViewModelFeature()
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: TestAudio())
        await model.prepare()
        model.authorizeSession()
        model.draft = "Hola"
        model.send()
        #expect(model.draft.isEmpty)
        model.draft = "Soy de Londres"
        #expect(model.canSend)
        model.send()
        try await waitUntil { feature.messages.count == 2 }
        #expect(feature.messages == ["Hola", "Soy de Londres"])
        model.draft = "Otra idea"
        feature.finishReply()
        feature.finishReply()
        try await waitUntil { !model.sending }
        #expect(model.draft == "Otra idea")
    }

    @Test func failedReplyKeepsDraftAndCanBeRetried() async throws {
        let feature = ChatViewModelFeature()
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: TestAudio())
        await model.prepare()
        model.authorizeSession()
        model.draft = "Hola"
        model.send()
        try await waitUntil { feature.reply != nil }
        feature.finishReply(error: AppFailure.unavailable("Try again"))
        try await waitUntil { !model.sending }
        #expect(model.error != nil)
        #expect(model.draft == "Hola")
        #expect(model.canSend)
    }

    @Test func endingSessionCancelsReplyAndStopsAudio() async throws {
        let feature = ChatViewModelFeature()
        let audio = TestAudio()
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: audio)
        await model.prepare()
        model.authorizeSession()
        let session = try #require(feature.session)
        model.translations.insert(UUID())
        await audio.startRecording()
        model.draft = "Hola"
        model.send()
        try await waitUntil { feature.reply != nil }
        model.endSession()
        feature.finishReply()
        try await waitUntil { !model.sending }
        #expect(feature.ended == [session])
        #expect(model.translations.isEmpty)
        #expect(!audio.recording)
        #expect(model.error == nil)
        #expect(model.draft.isEmpty)
    }

    @Test func preparationFailureAndInputAvailabilityAreVisible() async {
        let feature = ChatViewModelFeature()
        feature.preparationFailure = .unavailable("Unavailable")
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: TestAudio())
        await model.prepare()
        model.authorizeSession()
        #expect(model.preparationError != nil)
        #expect(feature.session == nil)
        feature.preparationFailure = nil
        await model.prepare()
        model.authorizeSession()
        #expect(model.preparationError == nil)
        model.draft = "   "
        #expect(!model.canSend)
        model.draft = "Hola"
        feature.hasAccess = false
        #expect(!model.canSend)
        feature.hasAccess = true
        feature.unavailable = "Model unavailable"
        #expect(!model.canSend)
        feature.unavailable = nil
        #expect(model.canSend)
    }
}

@MainActor private final class ChatViewModelFeature: ChatFeature {
    var hasAccess = true
    var coins = 1
    var sessionPaid = false
    var sessionAuthorized = false
    var sessionCost = 1
    var authorizationFailure: AppFailure?
    func authorizeSession() throws {
        if let authorizationFailure { throw authorizationFailure }
        sessionAuthorized = true
    }
    var preparing = false
    var unavailable: String?
    var ready = false
    var busy = false
    var session: UUID?
    var ended: [UUID] = []
    var messages: [String] = []
    var preparationFailure: AppFailure?
    private var replies: [CheckedContinuation<Void, Error>] = []
    var reply: CheckedContinuation<Void, Error>? { replies.first }
    func prepare() async throws {
        if let preparationFailure { throw preparationFailure }
        ready = true
    }
    func beginSession(id: UUID, author: Author) { session = id }
    func endSession(id: UUID) { ended.append(id); session = nil; sessionAuthorized = false }
    var savedConversation = ChatConversation()
    func conversation(for author: Author) -> ChatConversation { savedConversation }
    func send(_ message: String, to author: Author, level: String) async throws {
        messages.append(message)
        try await withCheckedThrowingContinuation { replies.append($0) }
        try Task.checkCancellation()
    }
    func finishReply(error: (any Error)? = nil) {
        guard !replies.isEmpty else { return }
        let pending = replies.removeFirst()
        if let error { pending.resume(throwing: error) }
        else { pending.resume() }
    }
    func clear(author: Author) async throws { sessionAuthorized = false }
}

@MainActor private final class AdmissionPauseGate {
    private var continuation: CheckedContinuation<Void, Error>?
    var waiting: Bool { continuation != nil }
    func pause() async throws {
        try await withCheckedThrowingContinuation { continuation = $0 }
        try Task.checkCancellation()
    }
    func release() {
        let pending = continuation
        continuation = nil
        pending?.resume()
    }
}
