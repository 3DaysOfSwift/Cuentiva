//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Observation

@MainActor @Observable final class WhosAppViewModel {
    private let library: any LibraryFeature
    private let progress: any ProgressFeature
    private(set) var authors: [Author] = []
    var unlocked: Bool { progress.snapshot.chatUnlocked }
    var coins: Int { progress.snapshot.availableChatCoins }
    var revision: LibraryRevision { library.revision }

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
