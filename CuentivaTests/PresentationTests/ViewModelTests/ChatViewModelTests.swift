import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct ChatViewModelTests {
    @Test func sendingGuardsDuplicateTapsAndPreservesANewerDraft() async throws {
        let feature = ChatViewModelFeature()
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: TestAudio())
        await model.prepare()
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

    @Test func failedReplyKeepsDraftAndCanBeRetried() async throws {
        let feature = ChatViewModelFeature()
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: TestAudio())
        await model.prepare()
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
        #expect(model.draft == "Hola")
    }

    @Test func preparationFailureAndInputAvailabilityAreVisible() async {
        let feature = ChatViewModelFeature()
        feature.preparationFailure = .unavailable("Unavailable")
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: TestAudio())
        await model.prepare()
        #expect(model.preparationError != nil)
        #expect(feature.session == nil)
        feature.preparationFailure = nil
        await model.prepare()
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
    var preparing = false
    var unavailable: String?
    var ready = false
    var busy = false
    var session: UUID?
    var ended: [UUID] = []
    var messages: [String] = []
    var preparationFailure: AppFailure?
    var reply: CheckedContinuation<Void, Error>?
    func prepare() async throws {
        if let preparationFailure { throw preparationFailure }
        ready = true
    }
    func beginSession(id: UUID, author: Author) { session = id }
    func endSession(id: UUID) { ended.append(id); session = nil }
    func conversation(for author: Author) -> ChatConversation { .init() }
    func send(_ message: String, to author: Author, level: String) async throws {
        messages.append(message)
        try await withCheckedThrowingContinuation { reply = $0 }
        try Task.checkCancellation()
    }
    func finishReply(error: (any Error)? = nil) {
        let pending = reply
        reply = nil
        if let error { pending?.resume(throwing: error) }
        else { pending?.resume() }
    }
    func clear(author: Author) async throws {}
}
