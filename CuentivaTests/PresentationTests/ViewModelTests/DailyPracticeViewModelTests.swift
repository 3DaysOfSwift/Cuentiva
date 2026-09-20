import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct DailyPracticeViewModelTests {
    @Test func unavailableAccessAndFailedSavesRemainRetryable() async throws {
        let repo = MemoryProgress()
        let progress = ProgressManager(repository: repo)
        try await progress.load()
        let books = (0..<3).map { sample("b\($0)", sentences: 4) }
        try await progress.saveDailyReading(books.map(\.id), date: .now)
        let purchases = TestPurchases()
        purchases.hasAccess = false
        let feature = DailyPracticeManager(progress: progress, purchases: purchases)
        let model = DailyPracticeViewModel(books: books, feature: feature)
        await model.prepare()
        #expect(model.error != nil)
        #expect(model.session == nil)
        purchases.hasAccess = true
        await model.prepare()
        model.select(.missingWord)
        let answer = try #require(model.session?.missingAnswer)
        await repo.setFailure(true)
        await model.choose(answer)
        #expect(model.error != nil)
        #expect(model.session?.missingIndex == 0)
        #expect(!model.busy)
        await repo.setFailure(false)
        await model.choose(answer)
        #expect(model.error == nil)
        #expect(model.session?.missingIndex == 1)
        #expect(model.feedback == "That fits!")
    }
}
