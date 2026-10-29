//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Observation
@MainActor @Observable final class SettingsViewModel {
    #if DEBUG
    var verbTrainingPreview: Bool { progress.snapshot.verbTrainingPreview }
    private(set) var changingVerbPreview = false
    func toggleVerbTrainingPreview() async {
        guard !changingVerbPreview else { return }
        changingVerbPreview = true; error = nil
        defer { changingVerbPreview = false }
        do { try await progress.setVerbTrainingPreview(!verbTrainingPreview) }
        catch { self.error = error.localizedDescription }
    }
    #endif
    private let library: any LibraryFeature
    var syncing: Bool { library.syncing }
    var syncMessage: String? { library.syncMessage }
    func syncLibrary() async { await library.sync() }
    var chatUnlocked: Bool { progress.snapshot.canOfferChat(onSupportedDevice: AppleChatGenerator.supportsDevice) }
    private let progress: any ProgressFeature
    private let purchases: any PurchaseFeature
    var showingThemePack: ThemePack?
    var themePacks: [ThemePack] {
        ThemePack.allCases.filter { progress.snapshot.earnedThemePacks.contains($0) || progress.snapshot.hasInstalled($0) }
    }
    func hasInstalled(_ pack: ThemePack) -> Bool { progress.snapshot.hasInstalled(pack) }
    var reviewURL: URL? { ReadingMilestones.reviewURL }
    var error: String?
    var resetConfirmation = false
    @ObservationIgnored private var resetTask: Task<Void, Never>?
    @ObservationIgnored private var restoreTask: Task<Void, Never>?
    private(set) var restoring = false
    private(set) var restoreMessage: String?
    private(set) var restoreError: String?
    var isVIP: Bool { progress.snapshot.isVIP }
    var hasAccess: Bool { purchases.hasAccess }
    init(library: any LibraryFeature = AppModel.shared.library, progress: any ProgressFeature = AppModel.shared.progress, purchases: any PurchaseFeature = AppModel.shared.purchases) { self.library = library; self.progress = progress; self.purchases = purchases }
    // A confirmed reset belongs to this owner until persistence completes.
    @discardableResult
    func reset() -> Task<Void, Never> {
        if let resetTask { return resetTask }
        error = nil
        let task = Task {
            defer { resetTask = nil }
            do {
                try Task.checkCancellation()
                try await progress.reset()
            } catch is CancellationError {
                // A reset cancelled before persistence is not a storage failure.
            } catch {
                self.error = error.localizedDescription
            }
        }
        resetTask = task
        return task
    }
    // Repeated requests share completion. A dispatched restore finishes even
    // after this screen closes so the purchase feature can deliver verified access.
    @discardableResult
    func restore() -> Task<Void, Never> {
        if let restoreTask { return restoreTask }
        restoring = true
        restoreMessage = nil
        restoreError = nil
        let alreadyOwned = purchases.hasAccess
        let task = Task {
            defer { restoring = false; restoreTask = nil }
            do {
                try Task.checkCancellation()
                try await purchases.restore()
                if purchases.hasAccess {
                    restoreMessage = alreadyOwned
                        ? "Your library access is active. You already have full access to Cuentiva."
                        : "Purchase restored. Your access to Cuentiva is ready."
                } else {
                    restoreError = "No active purchase was found. Check the Apple Account used for your purchase and try again."
                }
            } catch is CancellationError {
                // Cancellation is neither a successful restore nor a store failure.
            } catch {
                restoreError = error.localizedDescription
            }
        }
        restoreTask = task
        return task
    }
}
