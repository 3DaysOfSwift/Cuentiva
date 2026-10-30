//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Observation

@MainActor @Observable final class VocabularyViewModel {
    private let progress: any ProgressFeature
    var query = ""
    private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var saveRequest = UUID()
    var saving: Bool { saveTask != nil }
    private(set) var error: String?
    var selectedLevel: LearningLevel? { progress.snapshot.selectedLearningLevel }
    var total: Int { progress.snapshot.vocabulary.count }
    var words: [String] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return progress.snapshot.vocabulary.keys.sorted().filter {
            search.isEmpty || $0.localizedStandardContains(search)
        }
    }
    init(progress: any ProgressFeature = AppModel.shared.progress) { self.progress = progress }
    func state(_ word: String) -> VocabularyState { progress.snapshot.vocabulary[word] ?? .unknown }
    @discardableResult
    func set(_ word: String, state: VocabularyState) -> Task<Void, Never> {
        enqueue { try await self.progress.setVocabulary(word, state: state) }
    }

    @discardableResult
    func select(_ level: LearningLevel?) -> Task<Void, Never> {
        enqueue { try await self.progress.setLearningLevel(level) }
    }

    /// Accepted edits finish in order, even if the screen disappears.
    /// Progress remains responsible for committing and publishing saved state.
    private func enqueue(_ edit: @escaping @MainActor () async throws -> Void) -> Task<Void, Never> {
        let previous = saveTask
        let request = UUID()
        saveRequest = request
        if previous == nil { error = nil }
        let task = Task {
            defer {
                if saveRequest == request { saveTask = nil }
            }
            await previous?.value
            do {
                try Task.checkCancellation()
                try await edit()
            } catch is CancellationError {
                // An explicitly cancelled edit has not been reported as saved.
            } catch {
                self.error = error.localizedDescription
            }
        }
        saveTask = task
        return task
    }
}
