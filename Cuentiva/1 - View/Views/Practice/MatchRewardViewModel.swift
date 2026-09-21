//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Observation

@MainActor @Observable final class MatchRewardViewModel {
    let receipt: MatchRewardReceipt
    private(set) var revealed = false
    var displayedBalance: Int { revealed ? receipt.balance : receipt.previousBalance }
    init(receipt: MatchRewardReceipt) { self.receipt = receipt }
    func reveal() { revealed = true }
}
