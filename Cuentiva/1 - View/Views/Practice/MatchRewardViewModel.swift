import Observation

@MainActor @Observable final class MatchRewardViewModel {
    let receipt: MatchRewardReceipt
    private(set) var revealed = false
    var displayedBalance: Int { revealed ? receipt.balance : receipt.previousBalance }
    init(receipt: MatchRewardReceipt) { self.receipt = receipt }
    func reveal() { revealed = true }
}
