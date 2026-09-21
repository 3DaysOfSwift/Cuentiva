//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation

struct DailyMatchChallenge: Codable, Equatable, Sendable {
    let day: String
    let bookIDs: [String]
    var completedBookIDs: Set<String> = []
    var rewarded = false
    // Older saves with the group reward already paid must not pay again.
    var rewardedBookIDs: Set<String>?
    var paidBookIDs: Set<String> { rewardedBookIDs ?? (rewarded ? Set(bookIDs) : []) }
    static let pairCount = 30
}
