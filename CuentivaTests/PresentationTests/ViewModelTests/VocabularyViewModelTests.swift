//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct VocabularyViewModelTests {
    @Test(.timeLimit(.minutes(1))) func distinctEditDuringSaveIsNotLost() async throws {
        let repository = HeldVocabularySave()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let model = VocabularyViewModel(progress: progress)
        let first = model.set("café", state: .known)
        await repository.waitForSave()
        let second = model.select(.b1)
        #expect(model.saving)
        await repository.release()
        await first.value
        await second.value
        #expect(!model.saving)
        #expect(model.state("café") == .known)
        #expect(model.selectedLevel == .b1)
        #expect(await repository.value.selectedLearningLevel == .b1)
    }

    @Test(.timeLimit(.minutes(1))) func failedEditDoesNotHideBehindLaterSuccessAndCanRetry() async throws {
        let repository = HeldVocabularySave(failFirst: true)
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let model = VocabularyViewModel(progress: progress)
        let first = model.set("café", state: .known)
        await repository.waitForSave()
        let second = model.select(.b1)
        await repository.release()
        await first.value
        await second.value
        #expect(model.state("café") == .unknown)
        #expect(model.selectedLevel == .b1)
        #expect(model.error != nil)
        #expect(!model.saving)
        await model.set("café", state: .known).value
        #expect(model.state("café") == .known)
        #expect(model.error == nil)
        #expect(await repository.value.vocabulary["café"] == .known)
    }

    @Test(.timeLimit(.minutes(1))) func cancelledQueuedEditDoesNotCancelEarlierSave() async throws {
        let repository = HeldVocabularySave()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let model = VocabularyViewModel(progress: progress)
        let first = model.set("café", state: .known)
        await repository.waitForSave()
        let second = model.select(.b1)
        second.cancel()
        await repository.release()
        await first.value
        await second.value
        #expect(model.state("café") == .known)
        #expect(model.selectedLevel == nil)
        #expect(await repository.saveCalls == 1)
        #expect(!model.saving)
        await model.select(.b1).value
        #expect(model.selectedLevel == .b1)
    }

    @Test func vocabularySearchAndEditingUseProgressFeature() async throws {
        let (_,s,_,_,_) = try await makeViewModelTestGraph(); let vm = VocabularyViewModel(progress: s)
        await vm.set("café", state: .known).value; #expect(vm.state("café") == .known)
        await vm.set("casa", state: .learning).value
        vm.query = " CAFE "
        #expect(vm.words == ["café"])
        vm.query = "missing"; #expect(vm.words.isEmpty)
        await vm.select(.b1).value; #expect(vm.selectedLevel == .b1)
        #expect(vm.state("casa") == .learning)
        await vm.select(nil).value; #expect(vm.selectedLevel == nil)
    }
}

private actor HeldVocabularySave: ProgressRepository {
    private(set) var value = LearnerProgress()
    private var pending: CheckedContinuation<Void, Never>?
    private var arrival: CheckedContinuation<Void, Never>?
    private var released = false
    private let failFirst: Bool
    private(set) var saveCalls = 0
    init(failFirst: Bool = false) { self.failFirst = failFirst }
    func load() -> LearnerProgress { value }
    func save(_ next: LearnerProgress) async throws {
        saveCalls += 1
        if !released {
            await withCheckedContinuation {
                pending = $0
                arrival?.resume()
                arrival = nil
            }
        }
        if failFirst && saveCalls == 1 { throw AppFailure.unavailable("Controlled vocabulary save failure") }
        value = next
    }
    func waitForSave() async {
        if pending != nil { return }
        await withCheckedContinuation { arrival = $0 }
    }
    func release() {
        released = true
        pending?.resume()
        pending = nil
    }
}
