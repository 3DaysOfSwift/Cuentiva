import Foundation
import Testing
@testable import Cuentiva

@MainActor final class TestAudio: LessonAudio {
    var spokenRange: NSRange?
    var transcript = "El café está aquí"
    var recording = false
    var error: String?
    func speak(_ text: String, slow: Bool) {}
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
        let book = sample(); try await s.recordAttempt(book: book, sentence: book.sentences[0]); _ = try await s.complete(book: book)
        #expect(home.total == 1); #expect(collection.books.count == 1)
    }
    @Test func lessonWritesAndCompletesThroughFeature() async throws {
        let (_,_,_,learning,_) = try await graph(); let vm = LessonViewModel(learning: learning, audio: TestAudio())
        vm.load(sample()); vm.mode = "Write"; vm.answer = "El cafe esta aqui"; await vm.check(); await vm.next()
        #expect(vm.feedback?.matched == 1); #expect(vm.receipt?.total == 1)
    }
    @Test func celebrationCountsOnce() {
        let receipt = CompletionReceipt(book: sample(), isNew: true, total: 2), vm = CompletionViewModel()
        vm.prepare(receipt); #expect(vm.displayedTotal == 1); vm.celebrate(receipt); vm.prepare(receipt); #expect(vm.displayedTotal == 2)
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
