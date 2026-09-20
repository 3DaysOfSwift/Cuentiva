import Foundation
import Observation

@MainActor @Observable final class CompletionViewModel {
    let supportsChat: Bool
    func offersChatGift(_ receipt: CompletionReceipt) -> Bool {
        receipt.offersChatGift(onSupportedDevice: supportsChat)
    }
    private let purchases: (any PurchaseFeature)?
    var annualOfferDismissed = false
    func showsAnnualOffer(_ receipt: CompletionReceipt) -> Bool {
        !annualOfferDismissed && purchases?.shouldPromoteAnnual(receipt) == true
    }
    var annualPrice: String { purchases?.offer(for: .annual)?.displayPrice ?? "" }
    var monthlyPrice: String { purchases?.offer(for: .monthly)?.displayPrice ?? "" }
    private(set) var displayedTotal = 0
    private(set) var hasCelebrated = false
    var showingChat = false
    var showingChatGift = false
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
        else if offersChatGift(receipt) { showingChatGift = true }
        else if let pack = receipt.themePackGift { showingThemePack = pack }
        else { return true }
        return false
    }

    func takeReviewRequest(_ receipt: CompletionReceipt) -> Bool {
        guard receipt.requestsReview, !reviewRequested else { return false }
        reviewRequested = true
        return true
    }
    private var preparedReceiptID: UUID?

    init(receipt: CompletionReceipt? = nil, purchases: (any PurchaseFeature)? = nil, supportsChat: Bool = AppleChatGenerator.supportsDevice) {
        self.supportsChat = supportsChat
        self.purchases = purchases
        if let receipt { prepare(receipt) }
    }
    func prepare(_ receipt: CompletionReceipt) {
        guard preparedReceiptID != receipt.id else { return }
        preparedReceiptID = receipt.id
        annualOfferDismissed = false
        hasCelebrated = false
        reviewRequested = false
        writingMilestonePresented = false
        showingWritingMilestone = false
        showingChat = false
        showingChatGift = false
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
