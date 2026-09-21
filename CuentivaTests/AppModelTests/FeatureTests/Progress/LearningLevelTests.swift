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

@Suite @MainActor struct LearningLevelTests {
    @Test func selectedLevelPersistsAndFailedSaveLeavesItUnchanged() async throws {
        let repository = MemoryProgress()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        #expect(progress.snapshot.selectedLearningLevel == nil)
        try await progress.setLearningLevel(.b2)
        let reloaded = ProgressManager(repository: repository)
        try await reloaded.load()
        #expect(reloaded.snapshot.selectedLearningLevel == .b2)
        #expect(reloaded.snapshot.vocabulary.isEmpty)
        await repository.setFailure(true)
        do { try await progress.setLearningLevel(.c2); Issue.record("Expected save failure") } catch {}
        #expect(progress.snapshot.selectedLearningLevel == .b2)
        await repository.setFailure(false)
        try await progress.reset()
        #expect(progress.snapshot.selectedLearningLevel == nil)
    }
    @Test func oldProgressWithoutLevelStillDecodes() throws {
        let encoded = try JSONEncoder().encode(LearnerProgress())
        var fields = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        fields.removeValue(forKey: "selectedLearningLevel")
        let oldData = try JSONSerialization.data(withJSONObject: fields)
        let decoded = try JSONDecoder().decode(LearnerProgress.self, from: oldData)
        #expect(decoded.selectedLearningLevel == nil)
    }
}
