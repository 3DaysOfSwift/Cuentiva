import Foundation
import Testing
import StoreKit
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite struct ProgressPatchTests {
    @Test func deltaContainsOnlyChangedAndRemovedKeys() throws {
        var before = LearnerProgress()
        before.positions = ["one": 1, "two": 8]
        before.vocabulary = ["old": .learning, "kept": .known]
        var after = before
        after.positions["one"] = 2
        after.vocabulary.removeValue(forKey: "old")
        after.vocabulary["new"] = .known
        let delta = try ProgressRecords.changes(after, previous: before)
        #expect(Set(delta.upserts.keys) == ["positions/one", "vocabulary/new"])
        #expect(delta.removals == ["vocabulary/old"])
        let restored = try ProgressRecords.decode(delta.applying(to: ProgressRecords.encode(before)))
        #expect(restored == after)
        #expect(try ProgressRecords.changes(after, previous: after).isEmpty)
        let reset = try ProgressRecords.changes(.init(), previous: after)
        #expect(try ProgressRecords.decode(reset.applying(to: ProgressRecords.encode(after))) == LearnerProgress())
    }

    @Test func multiRecordPatchRollsBackAndRetryUsesLastSuccessfulState() async throws {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = SwiftDataStore(url: folder.appending(path: "test.store"))
        let url = folder.appending(path: "progress.json")
        let repository = LocalProgressRepository(url: url, store: store)
        var before = try await repository.load()
        before.positions = ["first": 1, "other": 9]
        before.vocabulary = ["old": .learning, "untouched": .known]
        try await repository.save(before)
        var after = before
        after.positions["first"] = 2
        after.vocabulary.removeValue(forKey: "old")
        after.vocabulary["new"] = .known
        #if DEBUG
        try await store.failNextCommitForTesting()
        await #expect(throws: (any Error).self) { try await repository.save(after) }
        let independentReader = LocalProgressRepository(url: url, store: store)
        #expect(try await independentReader.load() == before)
        #endif
        // Retry without refreshing this repository's cached progress.
        try await repository.save(after)
        #expect(try await LocalProgressRepository(url: url, store: store).load() == after)
        try await repository.save(.init())
        #expect(try await LocalProgressRepository(url: url, store: store).load() == LearnerProgress())
    }
}
