//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation

/// Reviews are independent of rewards. Never infer a review from a prompt or link tap.
enum ReadingMilestones {
    static let honouredReaderBookCount = 100
    // The opening books continue onboarding by unveiling one useful gift at a time.
    static let writingBookCount = 1
    static let chatOfferBookCount = 2
    static let verbTrainingBookCount = 3
    static let reviewBookCount = 15
    static let reviewURL = URL(string: "https://apps.apple.com/app/id6813381807?action=write-review")
}

/// Earned from saved reading progress, with no claim about global rankings.
enum ReaderBadge: String, CaseIterable, Identifiable, Sendable {
    case vip, persistence, onePercent
    var id: Self { self }
    var title: String {
        switch self {
        case .vip: "VIP"
        case .persistence: "Persistence"
        case .onePercent: "1%"
        }
    }
    var detail: String {
        switch self {
        case .vip: "A celebrated member of the 100-book club."
        case .persistence: "One hundred stories. A commitment to learning."
        case .onePercent: "A reminder that small steps add up. A motivational badge, not a world ranking."
        }
    }
}
