//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Observation

@MainActor @Observable final class RolePlayViewModel {
    private let library: any LibraryFeature
    private let progress: any ProgressFeature
    private(set) var authors: [Author] = []
    var unlocked: Bool { progress.snapshot.chatUnlocked }
    var coins: Int { progress.snapshot.availableChatCoins }
    var totalRolePlays: Int { progress.snapshot.totalRolePlayCompletions }
    var progressRevision: UUID { progress.revision }
    var revision: LibraryRevision { library.revision }

    func completions(for scenario: ConversationScenario) -> Int {
        progress.snapshot.rolePlayCompletions?[scenario.id] ?? 0
    }
    func isUnlocked(_ scenario: ConversationScenario) -> Bool { progress.snapshot.canStartRolePlay(scenario) }
    func lockReason(for scenario: ConversationScenario) -> String {
        guard let previous = progress.snapshot.rolePlayPrerequisite(for: scenario) else { return "Keep reading to unlock chat." }
        return "Complete \(previous.title) once"
    }
    func author(at index: Int) -> Author? {
        guard index >= 0, !authors.isEmpty else { return nil }
        return authors[index % authors.count]
    }

    init(library: any LibraryFeature = AppModel.shared.library,
         progress: any ProgressFeature = AppModel.shared.progress) {
        self.library = library
        self.progress = progress
    }

    func refresh() async {
        guard unlocked else { authors = []; return }
        let requested = revision
        let result = await library.presentation(.init())
        guard !Task.isCancelled, requested == revision, unlocked else { return }
        authors = result.authors
    }
}
