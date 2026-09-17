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
actor LaunchBooks: SyncingBookRepository {
    var syncCalls = 0
    func books() -> [Book] { [sample()] }
    func sync() -> [Book] { syncCalls += 1; return [sample()] }
}
@Suite @MainActor struct ViewModelTests {
    @Test func launchRendersLocalContentBeforePurchaseRefreshOrSync() async throws {
        let purchases = TestPurchases(); purchases.checking = true
        let progress = ProgressManager(repository: MemoryProgress())
        let repository = LaunchBooks()
        let library = LibraryManager(repository: repository, purchases: purchases, progress: progress)
        let root = RootViewModel(purchases: purchases, library: library, progress: progress,
            fantasy: FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator()))
        await root.load()
        #expect(root.ready)
        #expect(root.checkingAccess)
        #expect(!root.hasAccess)
        #expect(purchases.refreshCalls == 0)
        #expect(await repository.syncCalls == 0)
        await root.refreshPurchases()
        await root.syncLibrary()
        #expect(purchases.refreshCalls == 1)
        #expect(await repository.syncCalls == 1)
    }

    @Test func savedBioReturnsToEditableForm() async throws {
        let feature = FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator())
        try await feature.load(); _ = try await feature.drawCreature()
        let model = StorytellerRevealViewModel(feature: feature)
        await model.prepare()
        model.name = "James"; model.biography = "A traveller who helps others."
        await model.saveDetails()
        #expect(model.savedMessage != nil)
        let reopened = StorytellerRevealViewModel(feature: feature)
        await reopened.prepare()
        #expect(reopened.stage == .details)
        #expect(reopened.name == "James")
        #expect(reopened.biography == "A traveller who helps others.")
    }

    @Test func fantasyIdentityRevealUsesSavedCreatureAndPersistsCompletion() async throws {
        let feature = FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator(), draw: { .turtle })
        try await feature.load(); _ = try await feature.drawCreature()
        let model = StorytellerRevealViewModel(feature: feature)
        await model.prepare()
        #expect(model.stage == .creature)
        model.name = "Matt"; model.biography = "I travel and write apps."
        await model.generateIdentity()
        #expect(model.stage == .identity)
        #expect(model.identity?.name == "Lirio")
        #expect(model.name.isEmpty)
        #expect(await model.finish())
        #expect(feature.introductionSeen)
    }
    @Test func fantasyWriterLoadsItsSavedTales() async throws {
        let feature = FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator())
        try await feature.load(); _ = try await feature.drawCreature()
        try await feature.createIdentity(name: "Matt", biography: "A traveller")
        let model = FantasyWritingViewModel(feature: feature)
        await model.load(); model.memory = "I danced in Mexico."
        await model.generate()
        #expect(model.story != nil)
        #expect(model.stories.count == 1)
        #expect(model.error == nil)
        #expect(!model.busy)
    }

    @Test func statisticsReflectSavedPracticeAndAvoidDuplicateRewards() async throws {
        let progress = ProgressManager(repository: MemoryProgress())
        try await progress.load()
        let stats = StatsViewModel(progress: progress)
        #expect(stats.firstPractice == nil)
        #expect(stats.booksRead == 0)
        #expect(stats.doubloons == 0)
        let book = sample()
        try await progress.recordEncounter(book: book, sentence: book.sentences[0])
        _ = try await progress.complete(book: book)
        _ = try await progress.rewardPractice(book: book, matches: 2)
        _ = try await progress.rewardPractice(book: book, matches: 2)
        #expect(stats.booksRead == 1)
        #expect(stats.doubloons == 1)
        #expect(stats.streak == 1)
        #expect(stats.practiceDays == 1)
        #expect(stats.firstPractice != nil)
    }

    @Test func dailyCarouselFocusesNextUnreadAndAllowsBrowsingCompletedBooks() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress())
        let library = LibraryManager(repository: MemoryBooks(values: (0..<3).map { sample("carousel-\($0)") }), purchases: purchases, progress: progress)
        try await library.load()
        let home = HomeViewModel(library: library, progress: progress)
        await home.prepareDailyReads()
        let first = try #require(home.focusedRead)
        #expect(home.readButtonTitle == "Read book 1")
        try await progress.recordEncounter(book: first, sentence: first.sentences[0])
        _ = try await progress.complete(book: first)
        home.focusNextRead()
        #expect(home.readButtonTitle == "Read book 2")
        #expect(home.focusedRead?.id != first.id)
        #expect(home.dailyReads.contains { $0.id == first.id })
        home.focusedBookID = first.id
        #expect(home.readButtonTitle == "Read book 1")
        #expect(home.focusedRead?.id == first.id)
        #expect(home.completed(first))
    }
    private func graph() async throws -> (TestPurchases, ProgressManager, LibraryManager, LearningManager, ContributionManager) {
        let purchases = TestPurchases(), progress = ProgressManager(repository: MemoryProgress())
        try await progress.load()
        let library = LibraryManager(repository: MemoryBooks(values: [sample()]), purchases: purchases, progress: progress); try await library.load()
        return (purchases, progress, library, LearningManager(purchases: purchases, progress: progress), ContributionManager(repository: MemoryContributions(), purchases: purchases, progress: progress))
    }
    @Test func rootLoadsIsolatedGraph() async throws {
        let (p, s, l, _, _) = try await graph(); let vm = RootViewModel(purchases: p, library: l, progress: s, fantasy: FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator()))
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
        #expect(home.hideCompleted)
        #expect(home.nextRead?.id == "cafe")
        home.query = "cafe"; home.level = "A1"; home.format = .story; home.sort = .title
        #expect(home.books.count == 1)
        let book = sample(); try await s.recordEncounter(book: book, sentence: book.sentences[0]); _ = try await s.complete(book: book)
        #expect(home.total == 1); #expect(collection.books.count == 1)
        #expect(home.books.isEmpty)
        #expect(home.nextRead?.id == "cafe")
        #expect(home.revisiting)
        home.hideCompleted = false
        #expect(home.books.count == 1)
        home.level = "B1"
        #expect(home.books.isEmpty)
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
    @Test func settingsRestoreExplainsExistingAndRecoveredAccess() async throws {
        let (p,s,l,_,_) = try await graph()
        let vm = SettingsViewModel(library: l, progress: s, purchases: p)
        p.hasAccess = true
        await vm.restore()
        #expect(vm.restoreMessage?.contains("already have full access") == true)
        #expect(vm.restoreError == nil)
        #expect(!vm.restoring)
        p.hasAccess = false; p.restoresAccess = true
        await vm.restore()
        #expect(vm.restoreMessage?.contains("Purchase restored") == true)
        #expect(vm.hasAccess)
    }
    @Test func settingsRestoreReplacesStaleFeedbackAndNeverInventsSuccess() async throws {
        let (p,s,l,_,_) = try await graph()
        let vm = SettingsViewModel(library: l, progress: s, purchases: p)
        await vm.restore()
        #expect(vm.restoreError != nil)
        #expect(vm.restoreMessage == nil)
        p.restoreFailure = .unavailable("Store unavailable")
        await vm.restore()
        #expect(vm.restoreError == "Store unavailable")
        #expect(!vm.restoring)
        p.restoreFailure = nil; p.hasAccess = true
        await vm.restore()
        #expect(vm.restoreError == nil)
        #expect(vm.restoreMessage != nil)
    }
    @Test func vocabularySearchAndEditingUseProgressFeature() async throws {
        let (_,s,_,_,_) = try await graph(); let vm = VocabularyViewModel(progress: s)
        await vm.set("café", state: .known); #expect(vm.state("café") == .known)
        await vm.set("casa", state: .learning)
        vm.query = " CAFE "
        #expect(vm.words == ["café"])
        vm.query = "missing"; #expect(vm.words.isEmpty)
        await vm.select(.b1); #expect(vm.selectedLevel == .b1)
        #expect(vm.state("casa") == .learning)
        await vm.select(nil); #expect(vm.selectedLevel == nil)
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
    @Test func chatPurchaseIsSeparateAndRestores() async throws {
        let configuration = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Cuentiva/3 - App Resources/StorytellerChat.storekit")
        let session = try SKTestSession(contentsOf: configuration)
        session.disableDialogs = true; session.clearTransactions()
        defer { session.clearTransactions() }
        let chat = PurchaseManager(productID: PurchaseManager.storytellerChatProductID)
        let library = PurchaseManager()
        await chat.refresh(); await library.refresh()
        #expect(!chat.hasAccess); #expect(!library.hasAccess)
        #expect(chat.offer?.price == Decimal(string: "24.99"))
        #expect(chat.offer?.type == .nonConsumable)
        try await chat.purchase()
        await library.refresh()
        #expect(chat.hasAccess); #expect(!library.hasAccess)
        let restored = PurchaseManager(productID: PurchaseManager.storytellerChatProductID)
        try await restored.restore()
        #expect(restored.hasAccess)
        #expect(session.allTransactions().count == 1)
    }

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
        let root = RootViewModel(purchases: purchases, library: library, progress: progress, fantasy: FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator()))
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

        // Reproduce the device failure: the entitlement index returns nothing,
        // but StoreKit still has a verified lifetime transaction.
        let emptyIndex = PurchaseManager(readEntitlements: { [] })
        await emptyIndex.refresh()
        #expect(emptyIndex.hasAccess)
        try await emptyIndex.restore()
        #expect(emptyIndex.hasAccess)

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
        await emptyIndex.refresh()
        #expect(!emptyIndex.hasAccess)
    }
}
#endif

@MainActor private final class ChatPresentationFeature: ChatFeature {
    var hasAccess = false
    var displayPrice: String? = "£24.99"
    var preparing = false
    var unavailable: String?
    var ready = true
    var busy = false
    var purchaseFailure: AppFailure?
    func prepare() async throws { ready = true }
    func purchase() async throws {
        if let purchaseFailure { throw purchaseFailure }
        // A cancelled store sheet completes without granting an entitlement.
    }
    func restore() async throws { }
    func conversation(for author: Author) -> ChatConversation { .init() }
    func send(_ message: String, to author: Author, level: String) async throws { }
    func clear(author: Author) async throws { }
}
@Suite @MainActor struct ChatPresentationTests {
    @Test func cancelledPurchaseNeverShowsUnlockedNotice() async {
        let feature = ChatPresentationFeature()
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: TestAudio())
        await model.purchase()
        #expect(!model.unlocked)
        #expect(model.notice == nil)
        #expect(!model.purchasing)
    }
    @Test func foregroundRefreshPreservesPurchaseFailure() async {
        let feature = ChatPresentationFeature()
        feature.purchaseFailure = .unavailable("Purchase awaiting approval")
        let model = ChatViewModel(author: Author.demoProfiles[0], feature: feature, audio: TestAudio())
        await model.purchase()
        let failure = model.error
        #expect(failure != nil)
        await model.prepare()
        #expect(model.error == failure)
        #expect(model.preparationError == nil)
    }
}
