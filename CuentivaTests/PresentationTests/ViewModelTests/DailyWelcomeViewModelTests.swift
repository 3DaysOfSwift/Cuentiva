import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct DailyWelcomeViewModelTests {
    @Test func buttonWaitsForRevealAndSaveFailureAllowsRetry() async throws {
        let repository = MemoryProgress()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let welcome = try #require(progress.dailyWelcome)
        let model = DailyWelcomeViewModel(welcome: welcome, progress: progress, pause: { duration in
            #expect(duration == .seconds(1))
        })
        #expect(!model.buttonVisible)
        #expect(await model.beginDay() == false)
        await model.revealButton()
        #expect(model.buttonVisible)
        #expect(model.buttonTitle == "Begin day 1")
        await repository.setFailure(true)
        #expect(await model.beginDay() == false)
        #expect(model.error != nil)
        await repository.setFailure(false)
        #expect(await model.beginDay())
        #expect(model.error == nil)
        #expect(progress.streak == 0)
    }

    @Test func cancelledRevealKeepsButtonHidden() async throws {
        let progress = ProgressManager(repository: MemoryProgress())
        let model = DailyWelcomeViewModel(
            welcome: .init(day: "today", streak: 7, practicedToday: true, returningReader: true),
            progress: progress, pause: { _ in throw CancellationError() })
        await model.revealButton()
        #expect(!model.buttonVisible)
        #expect(model.buttonTitle == "Continue day 7")
        let restart = DailyWelcomeViewModel(
            welcome: .init(day: "today", streak: 0, practicedToday: false, returningReader: true), progress: progress)
        #expect(restart.buttonTitle == "Start a new streak")
    }
}
