import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct LessonViewModelTests {
    @Test func lessonWritesAndCompletesThroughFeature() async throws {
        let (_,_,_,learning,_) = try await makeViewModelTestGraph(); let vm = LessonViewModel(learning: learning, audio: TestAudio())
        vm.load(sample()); vm.mode = "Write"; vm.answer = "El cafe esta aqui"; await vm.check(); await vm.next()
        #expect(vm.feedback?.matched == 1); #expect(vm.showingChapterCelebration); #expect(!vm.showingReader)
    }

    @Test func chapterCelebrationDoesNotCompleteBookOrGrantReward() async throws {
        let (_, progress, _, learning, _) = try await makeViewModelTestGraph()
        let vm = LessonViewModel(learning: learning, audio: TestAudio())
        vm.load(sample())
        vm.readMoreFluently()
        #expect(!vm.showingReader)
        await vm.next()
        #expect(vm.showingChapterCelebration)
        #expect(progress.snapshot.completed.isEmpty)
        vm.readMoreFluently()
        #expect(vm.showingReader)
        #expect(progress.snapshot.completed.isEmpty)
    }

    @Test func failedChapterSaveStaysInLessonAndCanRetry() async throws {
        let repository = MemoryProgress()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let purchases = TestPurchases()
        let learning = LearningManager(purchases: purchases, progress: progress)
        let vm = LessonViewModel(learning: learning, audio: TestAudio())
        vm.load(sample())
        await repository.setFailure(true)
        await vm.next()
        #expect(vm.error != nil)
        #expect(!vm.showingChapterCelebration)
        #expect(!vm.showingReader)
        await repository.setFailure(false)
        await vm.next()
        #expect(vm.error == nil)
        #expect(vm.showingChapterCelebration)
    }

    @Test func writingSurvivesTabSwitchesAndSentenceNavigation() async throws {
        let (_,_,_,learning,_) = try await makeViewModelTestGraph()
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
        let (_,_,_,learning,_) = try await makeViewModelTestGraph()
        let vm = LessonViewModel(learning: learning, audio: TestAudio())
        let book = sample()
        vm.load(book); #expect(vm.nextTitle == "First chapter completed"); await vm.next()
        #expect(vm.showingChapterCelebration); #expect(!vm.showingReader); #expect(vm.error == nil)
        vm.readMoreFluently()
        #expect(vm.showingReader); #expect(!vm.showingChapterCelebration)
        let resumed = LessonViewModel(learning: learning, audio: TestAudio()); resumed.load(book)
        #expect(resumed.showingReader)
    }

    @Test func scriptRoleKeepsDraftAndManualCompletion() async throws {
        let (p,_,_,learning,_) = try await makeViewModelTestGraph(); p.hasAccess = true
        let source = sample()
        let book = Book(id: "script", title: source.title, englishTitle: source.englishTitle, author: source.author, level: source.level, symbol: source.symbol, palette: 0, summary: source.summary,
            sentences: [Sentence(id: "a", spanish: "Hola.", english: "Hello.", speaker: "Ana"), Sentence(id: "b", spanish: "Buenos días.", english: "Good morning.", speaker: "Leo")], vocabulary: [], license: "Test", format: .movieScript, scene: "A café")
        let vm = LessonViewModel(learning: learning, audio: TestAudio())
        vm.load(book); vm.role = "Ana"; vm.mode = "Write"; vm.answer = "Hola"
        vm.changeMode()
        #expect(vm.answer == "Hola"); #expect(!vm.isPartnerLine)
        #expect(vm.nextTitle == "Next line")
        await vm.next()
        #expect(vm.isPartnerLine); #expect(vm.nextTitle == "First chapter completed")
        await vm.next()
        #expect(vm.showingChapterCelebration); #expect(!vm.showingReader); #expect(vm.error == nil)
        vm.readMoreFluently()
        #expect(vm.showingReader); #expect(!vm.showingChapterCelebration)
        let resumed = LessonViewModel(learning: learning, audio: TestAudio()); resumed.load(book)
        #expect(resumed.showingReader)
    }
}
