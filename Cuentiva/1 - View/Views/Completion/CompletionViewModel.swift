import Foundation
import Observation
@MainActor @Observable final class CompletionViewModel {
    var displayedTotal = 0
    var appeared = false
    func prepare(_ receipt: CompletionReceipt) { guard !appeared else { return }; appeared = true; displayedTotal = receipt.isNew ? receipt.total - 1 : receipt.total }
    func celebrate(_ receipt: CompletionReceipt) { displayedTotal = receipt.total }
}
