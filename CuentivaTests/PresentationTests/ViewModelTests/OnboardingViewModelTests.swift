import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct OnboardingViewModelTests {
    @Test func onboardingKeepsItsBook() async throws {
        let (p,s,l,_,_) = try await makeViewModelTestGraph(); let vm = OnboardingViewModel(library: l, progress: s, purchases: p)
        #expect(vm.book?.id == "cafe"); #expect(!vm.completed)
    }
    @Test func progressFailureBlocksReadingAndRetryRestoresSavedCompletion() async throws {
        let (p, _, library, _, _) = try await makeViewModelTestGraph()
        let repository = OnboardingProgressRepository()
        let progress = ProgressManager(repository: repository)
        let model = OnboardingViewModel(library: library, progress: progress, purchases: p)
        #expect(model.book != nil)
        #expect(!model.canStartReading)
        model.startReading()
        #expect(model.lesson == nil)
        await model.prepareProgress()
        #expect(model.preparationError != nil)
        #expect(!model.progressReady)
        await repository.allowLoad(completed: true)
        await model.prepareProgress()
        #expect(model.preparationError == nil)
        #expect(model.completed)
        model.startReading()
        #expect(model.lesson == nil)
    }

    @Test func readyProgressAllowsStartingTheFreeStory() async throws {
        let (p, _, library, _, _) = try await makeViewModelTestGraph()
        let progress = ProgressManager(repository: MemoryProgress())
        let model = OnboardingViewModel(library: library, progress: progress, purchases: p)
        model.startReading()
        #expect(model.lesson == nil)
        await model.prepareProgress()
        #expect(model.canStartReading)
        model.startReading()
        #expect(model.lesson?.id == "cafe")
    }

}


private actor OnboardingProgressRepository: ProgressRepository {
    private var fails = true
    private var value = LearnerProgress()
    func load() throws -> LearnerProgress {
        if fails { throw AppFailure.unavailable("Storage temporarily unavailable") }
        return value
    }
    func save(_ value: LearnerProgress) { self.value = value }
    func allowLoad(completed: Bool) {
        fails = false
        if completed { value.completed.insert("cafe") }
    }
}
