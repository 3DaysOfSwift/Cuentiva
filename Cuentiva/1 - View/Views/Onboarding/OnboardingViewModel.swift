//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Observation
@MainActor @Observable final class OnboardingViewModel {
    private let library: any LibraryFeature
    private let progress: any ProgressFeature
    private let purchases: any PurchaseFeature
    private(set) var preparing = false
    private(set) var preparationError: String?
    var progressReady: Bool { progress.loaded }
    var canStartReading: Bool { progressReady && book != nil && !completed }
    var lesson: Book?
    var error: String?
    var book: Book? { library.introduction }
    var completed: Bool { progressReady && progress.snapshot.completed.contains("cafe") }
    init(library: any LibraryFeature = AppModel.shared.library, progress: any ProgressFeature = AppModel.shared.progress, purchases: any PurchaseFeature = AppModel.shared.purchases) { self.library = library; self.progress = progress; self.purchases = purchases }
    func prepareProgress() async {
        guard !preparing else { return }
        preparing = true
        preparationError = nil
        defer { preparing = false }
        do {
            try await progress.load()
            try Task.checkCancellation()
        } catch is CancellationError {
            // The shared progress load may still finish for another caller.
        } catch { preparationError = error.localizedDescription }
    }
    func startReading() {
        guard canStartReading else { return }
        lesson = book
    }
    func restore() async { do { try await purchases.restore() } catch { self.error = error.localizedDescription } }
}
