import Foundation

@MainActor protocol VerbTrainingFeature: AnyObject {
    var eligible: Bool { get }
    var claimed: Bool { get }
    var practiceDays: Int { get }
    var state: VerbTrainingState { get }
    @discardableResult func perform(_ action: VerbTrainingAction) async throws -> Bool
}
@MainActor final class VerbTrainingManager: VerbTrainingFeature {
    private let progress: any ProgressFeature
    private let purchases: any PurchaseFeature
    init(progress: any ProgressFeature, purchases: any PurchaseFeature) {
        self.progress = progress; self.purchases = purchases
    }
    var eligible: Bool { progress.snapshot.verbTrainingUnlocked }
    var claimed: Bool { progress.snapshot.verbTrainingGiftOpened }
    var practiceDays: Int { progress.snapshot.practiceDays.count }
    var state: VerbTrainingState { progress.snapshot.verbTraining ?? VerbTrainingState() }
    @discardableResult func perform(_ action: VerbTrainingAction) async throws -> Bool {
        guard purchases.hasAccess else { throw AppFailure.unavailable("Unlock the library to use Verb Training.") }
        return try await progress.performVerbTraining(action)
    }
}
