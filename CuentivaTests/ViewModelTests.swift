import Foundation
import AVFoundation
import Speech
import Testing
@testable import Cuentiva

@MainActor final class TestAudio: LessonAudio {
    var spokenRange: NSRange?
    var transcript = "El café está aquí"
    var recording = false
    var error: String?
    func speak(_ text: String, slow: Bool) {}
    func speakAndWait(_ text: String, slow: Bool) async -> Bool { true }
    func startRecording() async { recording = true }
    func stopRecording() { recording = false }
    func stop() { recording = false }
}
@Suite @MainActor struct ViewModelTests {
    private func graph() async throws -> (TestPurchases, ProgressManager, LibraryManager, LearningManager, ContributionManager) {
        let purchases = TestPurchases(), progress = ProgressManager(repository: MemoryProgress())
        try await progress.load()
        let library = LibraryManager(repository: MemoryBooks(values: [sample()]), purchases: purchases, progress: progress); try await library.load()
        return (purchases, progress, library, LearningManager(purchases: purchases, progress: progress), ContributionManager(repository: MemoryContributions(), purchases: purchases, progress: progress))
    }
    @Test func rootLoadsIsolatedGraph() async throws {
        let (p, s, l, _, _) = try await graph(); let vm = RootViewModel(purchases: p, library: l, progress: s)
        await vm.load(); #expect(vm.ready); #expect(!vm.hasAccess)
    }
    @Test func onboardingKeepsItsBook() async throws {
        let (p,s,l,_,_) = try await graph(); let vm = OnboardingViewModel(library: l, progress: s, purchases: p)
        #expect(vm.book?.id == "cafe"); #expect(!vm.completed)
    }
    @Test func paywallDeclineDoesNotGrantAccess() async throws {
        let (p,_,_,_,_) = try await graph(); let vm = PaywallViewModel(purchases: p)
        vm.declined = true; #expect(!p.hasAccess); await vm.purchase(); #expect(p.hasAccess)
    }
    @Test func homeAndCollectionReflectCommittedCompletion() async throws {
        let (p,s,l,_,_) = try await graph(); p.hasAccess = true
        let home = HomeViewModel(library: l, progress: s), collection = CompletedViewModel(library: l)
        #expect(home.books.count == 1); #expect(collection.books.isEmpty)
        let book = sample(); try await s.recordEncounter(book: book, sentence: book.sentences[0]); _ = try await s.complete(book: book)
        #expect(home.total == 1); #expect(collection.books.count == 1)
    }
    @Test func lessonWritesAndCompletesThroughFeature() async throws {
        let (_,_,_,learning,_) = try await graph(); let vm = LessonViewModel(learning: learning, audio: TestAudio())
        vm.load(sample()); vm.mode = "Write"; vm.answer = "El cafe esta aqui"; await vm.check(); await vm.next()
        #expect(vm.feedback?.matched == 1); #expect(vm.showingReader)
    }
    @Test func writingSurvivesTabSwitchesAndSentenceNavigation() async throws {
        let (_,_,_,learning,_) = try await graph()
        let vm = LessonViewModel(learning: learning, audio: TestAudio())
        vm.load(sample(sentences: 2)); vm.mode = "Write"; vm.answer = "El cafe"
        vm.mode = "Speak"; vm.changeMode()
        #expect(vm.answer == "El cafe")
        vm.mode = "Write"; vm.changeMode()
        #expect(vm.answer == "El cafe"); #expect(!vm.showSpanish)
        await vm.next()
        #expect(vm.index == 1); #expect(vm.answer.isEmpty); #expect(vm.error == nil)
        await vm.back()
        #expect(vm.answer == "El cafe")
    }
    @Test func lessonCanFinishWithoutWritingOrSpeaking() async throws {
        let (_,_,_,learning,_) = try await graph()
        let vm = LessonViewModel(learning: learning, audio: TestAudio())
        let book = sample()
        vm.load(book); #expect(vm.nextTitle == "Read the full story"); await vm.next()
        #expect(vm.showingReader); #expect(vm.error == nil)
        let resumed = LessonViewModel(learning: learning, audio: TestAudio()); resumed.load(book)
        #expect(resumed.showingReader)
    }
    @Test func scriptRoleKeepsDraftAndManualCompletion() async throws {
        let (p,_,_,learning,_) = try await graph(); p.hasAccess = true
        let source = sample()
        let book = Book(id: "script", title: source.title, englishTitle: source.englishTitle, author: source.author, level: source.level, symbol: source.symbol, palette: 0, summary: source.summary,
            sentences: [Sentence(id: "a", spanish: "Hola.", english: "Hello.", speaker: "Ana"), Sentence(id: "b", spanish: "Buenos días.", english: "Good morning.", speaker: "Leo")], vocabulary: [], license: "Test", format: .movieScript, scene: "A café")
        let vm = LessonViewModel(learning: learning, audio: TestAudio())
        vm.load(book); vm.role = "Ana"; vm.mode = "Write"; vm.answer = "Hola"
        vm.changeMode()
        #expect(vm.answer == "Hola"); #expect(!vm.isPartnerLine)
        #expect(vm.nextTitle == "Next line")
        await vm.next()
        #expect(vm.isPartnerLine); #expect(vm.nextTitle == "Read the full script")
        await vm.next()
        #expect(vm.showingReader); #expect(vm.error == nil)
        let resumed = LessonViewModel(learning: learning, audio: TestAudio()); resumed.load(book)
        #expect(resumed.showingReader)
    }
    @Test func celebrationCountsOnce() {
        let receipt = CompletionReceipt(book: sample(), isNew: true, total: 2), vm = CompletionViewModel()
        vm.prepare(receipt); #expect(vm.displayedTotal == 1); vm.celebrate(receipt); vm.prepare(receipt); #expect(vm.displayedTotal == 2)
    }
    @Test func firstCompletionHasPreviousCountBeforeAppearance() {
        let first = CompletionReceipt(book: sample(), isNew: true, total: 1)
        let vm = CompletionViewModel(receipt: first)
        #expect(vm.displayedTotal == 0); #expect(!vm.hasCelebrated)
        vm.prepare(first)
        #expect(vm.displayedTotal == 0)
        vm.celebrate(first); vm.prepare(first); vm.celebrate(first)
        #expect(vm.displayedTotal == 1); #expect(vm.hasCelebrated)
        let second = CompletionReceipt(book: sample("second"), isNew: true, total: 2)
        vm.prepare(second)
        #expect(vm.displayedTotal == 1); #expect(!vm.hasCelebrated)
        vm.celebrate(second)
        #expect(vm.displayedTotal == 2)
    }
    @Test func rereadCelebrationNeverInventsAnIncrement() {
        let receipt = CompletionReceipt(book: sample(), isNew: false, total: 4)
        let vm = CompletionViewModel(receipt: receipt)
        #expect(vm.displayedTotal == 4)
        vm.celebrate(receipt)
        #expect(vm.displayedTotal == 4); #expect(vm.hasCelebrated)
    }
    @Test func contributionRetainsInvalidDraft() async throws {
        let (_,_,_,_,f) = try await graph(); let vm = ContributionViewModel(feature: f)
        vm.draft.title = "My memory"; await vm.save(submit: true)
        #expect(vm.draft.title == "My memory"); #expect(vm.error != nil)
    }
    @Test func settingsUpdatesVocabularyThroughFeature() async throws {
        let (p,s,_,_,_) = try await graph(); let vm = SettingsViewModel(progress: s, purchases: p)
        await vm.set("café", state: .known); #expect(vm.state("café") == .known)
    }
}

@Suite @MainActor struct ThemeManagerTests {
    @Test func themeSelectionSurvivesRelaunch() {
        let suite = "CuentivaThemeTests.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        let manager = ThemeManager(preferences: preferences)
        #expect(manager.selectedTheme == .library)
        manager.selectedTheme = .midnight
        let restored = ThemeManager(preferences: preferences)
        #expect(restored.selectedTheme == .midnight)
        #expect(restored.theme.colorScheme == .dark)
        restored.selectedTheme = .library
        #expect(ThemeManager(preferences: preferences).theme.colorScheme == .light)
    }
    @Test func obsoleteThemeFallsBackToLibrary() {
        let suite = "CuentivaThemeTests.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        preferences.set("removed-palette", forKey: "appearance.colourTheme")
        #expect(ThemeManager(preferences: preferences).selectedTheme == .library)
    }
}


@Suite struct SpeechCallbackTests {
    @Test @MainActor func recognitionCallbackCanArriveOffMainActor() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let handler = AppleLessonAudio.makeRecognitionHandler { text, finished, error in
                MainActor.assertIsolated()
                #expect(text == nil)
                #expect(!finished)
                #expect(error == "Recognition interrupted")
                continuation.resume()
            }
            Task.detached {
                handler(nil, NSError(domain: "SpeechCallbackTest", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Recognition interrupted"]))
            }
        }
    }

    @Test func audioTapAcceptsBackgroundBuffersAndIgnoresEmptyFrames() async {
        await Task.detached {
            let request = SFSpeechAudioBufferRecognitionRequest()
            let callback = AppleLessonAudio.makeAudioTap(request: request)
            let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 128)!
            let time = AVAudioTime(sampleTime: 0, atRate: 16_000)
            buffer.frameLength = 0
            callback(buffer, time)
            buffer.frameLength = 128
            buffer.floatChannelData![0].initialize(repeating: 0, count: 128)
            callback(buffer, time)
            request.endAudio()
        }.value
    }
}

@MainActor final class ReaderTestAudio: LessonAudio {
    var spokenRange: NSRange?
    var transcript = ""
    var recording = false
    var error: String?
    var spoken: [String] = []
    var rates: [Bool] = []
    var pending: CheckedContinuation<Bool, Never>?
    func speak(_ text: String, slow: Bool) {}
    func speakAndWait(_ text: String, slow: Bool) async -> Bool {
        spoken.append(text); rates.append(slow)
        return await withCheckedContinuation { pending = $0 }
    }
    func finishLine() { let value = pending; pending = nil; value?.resume(returning: true) }
    func startRecording() async {}
    func stopRecording() {}
    func stop() { let value = pending; pending = nil; value?.resume(returning: false) }
}
actor ReaderPauseProbe {
    var count = 0
    func pause() { count += 1 }
}
@Suite @MainActor struct BookReaderTests {
    @Test(arguments: [BookFormat.story, .movieScript, .verbs])
    func playbackSequencesSlowlyAndStopsWithoutCompleting(format: BookFormat) async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        let learning = LearningManager(purchases: purchases, progress: progress)
        let source = sample()
        let book = Book(id: "script", title: source.title, englishTitle: source.englishTitle, author: source.author, level: source.level, symbol: source.symbol, palette: 0, summary: source.summary,
            sentences: [Sentence(id: "a", spanish: "Hola.", english: "Hello.", speaker: "Ana")], vocabulary: [], license: "Test", format: format,
            continuation: [Sentence(id: "b", spanish: "Buenas tardes.", english: "Good afternoon.", speaker: "Leo")])
        _ = try await learning.advance(book: book, from: 0)
        let audio = ReaderTestAudio(), probe = ReaderPauseProbe()
        let vm = BookReaderViewModel(learning: learning, audio: audio, pause: { await probe.pause() })
        #expect(vm.audioEnabled)
        vm.start(book)
        for _ in 0..<100 where audio.spoken.isEmpty { await Task.yield() }
        #expect(audio.spoken == ["Hola."])
        #expect(audio.rates == [true]); #expect(vm.activeIndex == 0)
        audio.finishLine()
        for _ in 0..<100 where audio.spoken.count < 2 { await Task.yield() }
        #expect(audio.spoken == ["Hola.", "Buenas tardes."])
        #expect(await probe.count == 1)
        vm.stop()
        #expect(!vm.audioEnabled); #expect(vm.activeIndex == nil)
        #expect(progress.snapshot.completed.isEmpty)
        vm.toggleAudio(book)
        for _ in 0..<100 where audio.spoken.count < 3 { await Task.yield() }
        #expect(audio.spoken.last == "Buenas tardes.")
        #expect(vm.audioEnabled)
        audio.finishLine()
        for _ in 0..<100 where vm.audioEnabled { await Task.yield() }
        #expect(!vm.audioEnabled)
        #expect(progress.snapshot.completed.isEmpty)
        await vm.finish(book)
        #expect(vm.receipt?.total == 1)
    }
}

@Suite @MainActor struct ContributionTopicViewModelTests {
    @Test func changingPathsPreservesWorkAndResumesTicket() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        let book = sample(); try await progress.recordEncounter(book: book, sentence: book.sentences[0]); _ = try await progress.complete(book: book)
        let manager = ContributionManager(repository: MemoryContributions(), purchases: purchases, progress: progress)
        let vm = ContributionViewModel(feature: manager); await vm.load()
        vm.draft.spanish = "Mi historia sin título."
        let topic = try #require(vm.topics.first)
        await vm.choose(topic)
        #expect(vm.selectedTopic?.id == topic.id)
        #expect(manager.drafts.contains { $0.spanish == "Mi historia sin título." })
        let identifier = vm.draft.id
        vm.teachingNote = "My own explanation."
        await vm.freestyle()
        #expect(vm.draft.topicID == nil); #expect(vm.draft.spanish.isEmpty)
        await vm.choose(topic)
        #expect(vm.draft.id == identifier); #expect(vm.teachingNote == "My own explanation.")
        #expect(manager.drafts.filter { $0.topicID == topic.id }.count == 1)
    }
}

@Suite @MainActor struct PracticeRoundTests {
    @Test func wholeDeckAwardsOnceAndInterruptionsDoNotAward() async throws {
        let book = sample()
        var playable = book; playable.matchGlossary = ["está": "is here"]
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        try await progress.recordEncounter(book: playable, sentence: playable.sentences[0]); _ = try await progress.complete(book: playable)
        let feature = PracticeManager(progress: progress, purchases: purchases)
        let model = PracticeViewModel(book: playable, feature: feature)
        model.timed = false; model.startGame()
        model.suspend()
        #expect(model.stage == .ready); #expect(feature.coins == 0)
        model.startGame(); model.stage = .playing
        await model.chooseSpanish("está"); await model.chooseEnglish("está")
        #expect(model.stage == .result); #expect(model.matches == 1); #expect(model.awarded)
        model.startGame(); model.stage = .playing
        await model.chooseEnglish("está"); await model.chooseSpanish("está")
        #expect(!model.awarded); #expect(feature.coins == 1)
    }
}

@Suite @MainActor struct PracticeTimerTests {
    @Test func countdownDoesNotSpendRoundTimeAndLateTapsDoNotScore() async throws {
        var book = sample(); book.matchGlossary = ["está": "is here"]
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        try await progress.recordEncounter(book: book, sentence: book.sentences[0]); _ = try await progress.complete(book: book)
        var instant = ContinuousClock().now
        let feature = PracticeManager(progress: progress, purchases: purchases)
        let model = PracticeViewModel(book: book, feature: feature, now: { instant })
        model.startGame()
        await model.chooseSpanish("está")
        #expect(model.selectedSpanish == nil)
        instant = instant.advanced(by: .seconds(3)); await model.tick()
        #expect(model.stage == .playing); #expect(model.seconds == 30)
        instant = instant.advanced(by: .seconds(31))
        await model.chooseSpanish("está"); await model.chooseEnglish("está")
        #expect(model.stage == .result); #expect(model.matches == 0); #expect(feature.coins == 0)
    }
}

#if targetEnvironment(simulator)
import StoreKitTest

@Suite(.serialized) @MainActor struct StorePurchaseTests {
    @Test func lifetimePurchaseSurvivesNewManagerAndRestoresWithoutRepurchase() async throws {
        let configuration = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Cuentiva/3 - App Resources/Cuentiva.storekit")
        let session = try SKTestSession(contentsOf: configuration)
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let purchases = PurchaseManager()
        await purchases.refresh()
        #expect(!purchases.hasAccess)
        #expect(purchases.offer != nil)
        let progress = ProgressManager(repository: MemoryProgress())
        let library = LibraryManager(repository: MemoryBooks(values: [sample()]), purchases: purchases, progress: progress)
        let root = RootViewModel(purchases: purchases, library: library, progress: progress)
        await root.load()
        #expect(!root.hasAccess)
        try await purchases.purchase()
        #expect(purchases.hasAccess)
        #expect(root.hasAccess)

        // A fresh manager has no app-local record, as after reinstalling.
        let relaunched = PurchaseManager()
        await relaunched.refresh()
        #expect(relaunched.hasAccess)
        try await relaunched.restore()
        try await relaunched.purchase()
        #expect(relaunched.hasAccess)
        #expect(session.allTransactions().count == 1)

        let transaction = try #require(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        // StoreKit delivers refunds asynchronously through Transaction.updates.
        for _ in 0..<50 {
            if !relaunched.hasAccess { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(!relaunched.hasAccess)
        await relaunched.refresh()
        #expect(!relaunched.hasAccess)
    }
}
#endif
