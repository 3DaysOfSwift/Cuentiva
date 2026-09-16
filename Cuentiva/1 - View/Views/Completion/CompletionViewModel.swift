import Foundation
import Observation

@MainActor @Observable final class CompletionViewModel {
    private(set) var displayedTotal = 0
    private(set) var hasCelebrated = false
    private var preparedReceiptID: UUID?

    init(receipt: CompletionReceipt? = nil) {
        if let receipt { prepare(receipt) }
    }
    func prepare(_ receipt: CompletionReceipt) {
        guard preparedReceiptID != receipt.id else { return }
        preparedReceiptID = receipt.id
        hasCelebrated = false
        displayedTotal = receipt.isNew ? max(0, receipt.total - 1) : receipt.total
    }
    func celebrate(_ receipt: CompletionReceipt) {
        prepare(receipt)
        guard !hasCelebrated else { return }
        displayedTotal = receipt.total
        hasCelebrated = true
    }
}
