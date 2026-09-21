//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation

struct MatchRewardReceipt: Identifiable, Equatable, Sendable {
    let id = UUID()
    let previousBalance: Int
    let balance: Int
}
