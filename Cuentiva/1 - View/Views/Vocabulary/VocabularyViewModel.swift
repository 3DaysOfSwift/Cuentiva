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
    private(set) var saving = false
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
    func set(_ word: String, state: VocabularyState) async {
        guard !saving else { return }
        saving = true; error = nil; defer { saving = false }
        do { try await progress.setVocabulary(word, state: state) }
        catch { self.error = error.localizedDescription }
    }
    func select(_ level: LearningLevel?) async {
        guard !saving else { return }
        saving = true; error = nil; defer { saving = false }
        do { try await progress.setLearningLevel(level) }
        catch { self.error = error.localizedDescription }
    }
}
