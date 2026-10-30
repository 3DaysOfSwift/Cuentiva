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
    @ObservationIgnored private var preparationTask: Task<Void, Never>?
    @ObservationIgnored private var restoreTask: Task<Void, Never>?
    var book: Book? { library.introduction }
    var completed: Bool { progressReady && progress.snapshot.completed.contains("cafe") }
    init(library: any LibraryFeature = AppModel.shared.library, progress: any ProgressFeature = AppModel.shared.progress, purchases: any PurchaseFeature = AppModel.shared.purchases) { self.library = library; self.progress = progress; self.purchases = purchases }
    func prepareProgress() async {
        guard !preparing, !Task.isCancelled else { return }
        preparing = true
        preparationError = nil
        defer { preparing = false }
        do {
            try await progress.load()
            try Task.checkCancellation()
        } catch is CancellationError {
            // The shared progress load may still finish for another caller.
        } catch {
            if !Task.isCancelled { preparationError = error.localizedDescription }
        }
    }
    @discardableResult
    func retryPreparation() -> Task<Void, Never> {
        if let preparationTask { return preparationTask }
        let task = Task {
            defer { preparationTask = nil }
            await prepareProgress()
        }
        preparationTask = task
        return task
    }
    func cancelPreparation() { preparationTask?.cancel() }

    func startReading() {
        guard canStartReading else { return }
        lesson = book
    }
    /// A restore already admitted by this screen can finish after departure.
    @discardableResult
    func restore() -> Task<Void, Never> {
        if let restoreTask { return restoreTask }
        error = nil
        let task = Task {
            defer { restoreTask = nil }
            do {
                try Task.checkCancellation()
                try await purchases.restore()
            } catch is CancellationError {
                // Cancellation before dispatch is not a restore failure.
            } catch {
                self.error = error.localizedDescription
            }
        }
        restoreTask = task
        return task
    }
}
