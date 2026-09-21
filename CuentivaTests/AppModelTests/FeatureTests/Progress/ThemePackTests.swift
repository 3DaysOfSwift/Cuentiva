//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct ThemePackTests {
    @Test(arguments: [0, 9, 10, 24, 25, 49, 50, 100])
    func rewardsAreEarnedButNotAutomaticallyInstalled(count: Int) {
        var progress = LearnerProgress()
        progress.completed = Set((0..<count).map { "book-\($0)" })
        #expect(progress.availableThemes == [.library, .midnight])
        #expect(progress.earnedThemePacks == ThemePack.allCases.filter { $0.requiredBooks.map { count >= $0 } ?? false })
        let receipt = CompletionReceipt(book: sample(), isNew: true, total: count)
        #expect(receipt.themePackGift == ThemePack.allCases.first { $0.requiredBooks == count })
        #expect(!receipt.requestsReview)
        #expect(CompletionReceipt(book: sample(), isNew: false, total: count).themePackGift == nil)
    }
    @Test func installsAtomicallyAndPersistsWithoutDuplicateGrants() async throws {
        let repository = MemoryProgress()
        var saved = LearnerProgress()
        saved.completed = Set((0..<50).map { "book-\($0)" })
        try await repository.save(saved)
        let manager = ProgressManager(repository: repository)
        try await manager.load()
        await repository.setFailure(true)
        await #expect(throws: AppFailure.self) { try await manager.installThemePack(.storybook) }
        #expect(manager.snapshot.availableThemes.count == 2)
        await repository.setFailure(false)
        for pack in ThemePack.allCases where pack.requiredBooks != nil { try await manager.installThemePack(pack) }
        #expect(manager.snapshot.availableThemes.count == 17)
        #expect(Set(manager.snapshot.availableThemes).count == 17)
        let writes = await repository.saveAttempts
        try await manager.installThemePack(.storybook)
        #expect(await repository.saveAttempts == writes)
        let restored = ProgressManager(repository: repository)
        try await restored.load()
        #expect(restored.snapshot.availableThemes == manager.snapshot.availableThemes)
        let rows = try ProgressRecords.encode(restored.snapshot)
        #expect(try ProgressRecords.decode(rows).availableThemes.count == 17)
        try await restored.reset()
        #expect(restored.snapshot.completed.isEmpty)
        #expect(restored.snapshot.availableThemes.count == 17)
    }
    @Test func cannotInstallUnearnedPackAndLegacyProgressStartsWithTwoThemes() async throws {
        let repository = MemoryProgress()
        let manager = ProgressManager(repository: repository)
        try await manager.load()
        await #expect(throws: AppFailure.self) { try await manager.installThemePack(.storybook) }
        #expect(manager.snapshot.installedThemePacks == nil)
        #expect(await repository.saveAttempts == 0)
        let legacy = try ProgressRecords.decode(ProgressRecords.encode(LearnerProgress()))
        #expect(legacy.availableThemes == [.library, .midnight])
        #expect(ThemePack.allCases.filter { $0.requiredBooks != nil }.allSatisfy { $0.themes.count == 5 })
    }
}
