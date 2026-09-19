import Foundation
import Observation

@MainActor @Observable final class CompletionViewModel {
    private(set) var displayedTotal = 0
    private(set) var hasCelebrated = false
    var showingChat = false
    var showingPractice = false
    var showingWritingMilestone = false
    var showingThemePack: ThemePack?
    private var reviewRequested = false
    private var writingMilestonePresented = false
    func presentWritingMilestone(_ receipt: CompletionReceipt) {
        guard receipt.unlocksWriting, !writingMilestonePresented else { return }
        writingMilestonePresented = true
        showingWritingMilestone = true
    }
    /// Returns true when the completion screen should close.
    func continueJourney(_ receipt: CompletionReceipt, practiceAllowed: Bool) -> Bool {
        if receipt.unlocksWriting { presentWritingMilestone(receipt) }
        else if let pack = receipt.themePackGift { showingThemePack = pack }
        else if receipt.streakCelebration != nil && practiceAllowed { showingPractice = true }
        else { return true }
        return false
    }

    func takeReviewRequest(_ receipt: CompletionReceipt) -> Bool {
        guard receipt.requestsReview, !reviewRequested else { return false }
        reviewRequested = true
        return true
    }
    private var preparedReceiptID: UUID?

    init(receipt: CompletionReceipt? = nil) {
        if let receipt { prepare(receipt) }
    }
    func prepare(_ receipt: CompletionReceipt) {
        guard preparedReceiptID != receipt.id else { return }
        preparedReceiptID = receipt.id
        hasCelebrated = false
        reviewRequested = false
        writingMilestonePresented = false
        showingWritingMilestone = false
        showingChat = false
        showingPractice = false
        showingThemePack = nil
        displayedTotal = receipt.isNew ? max(0, receipt.total - 1) : receipt.total
    }
    func celebrate(_ receipt: CompletionReceipt) {
        prepare(receipt)
        guard !hasCelebrated else { return }
        displayedTotal = receipt.total
        hasCelebrated = true
    }
}
