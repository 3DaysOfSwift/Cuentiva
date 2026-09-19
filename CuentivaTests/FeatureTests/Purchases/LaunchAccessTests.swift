import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct LaunchAccessTests {
    @Test func catalogueCanDisplayWhilePaidLessonsRemainLocked() async throws {
        let purchases = TestPurchases(); purchases.checking = true
        let progress = ProgressManager(repository: MemoryProgress())
        let library = LibraryManager(repository: MemoryBooks(values: [sample(), sample("paid")]), purchases: purchases, progress: progress)
        try await library.load()
        #expect(await !library.dailyReads.isEmpty)
        #expect(await library.search("", level: nil, completedOnly: false).count == 2)
        let learning = LearningManager(purchases: purchases, progress: progress)
        #expect(!learning.canRead(sample("paid")))
        try await library.prepareDailyReads()
        #expect(progress.snapshot.dailyReadingIDs == nil)
        purchases.checking = false
        #expect(await library.dailyReads.isEmpty)
        purchases.hasAccess = true
        try await library.prepareDailyReads()
        #expect(progress.snapshot.dailyReadingIDs?.count == 2)
    }
}
