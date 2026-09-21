//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation

enum ColourThemeID: String, CaseIterable, Identifiable, Sendable {
    case library, midnight, parchment, rose, lavender, ocean, forest
    case terracotta, honey, sage, lagoon, twilight
    case cherry, glacier, pearl, cocoa, starlight, vip
    var id: Self { self }
    var title: String { self == .vip ? "VIP" : rawValue.capitalized }
}

/// Add a pack here to extend the reward catalogue; eligibility is shared by every target.
enum ThemePack: String, CaseIterable, Identifiable, Sendable {
    case storybook, wanderlust, enchanted, vip
    var id: Self { self }
    var title: String { self == .vip ? "VIP" : rawValue.capitalized }
    var requiredBooks: Int? {
        switch self { case .storybook: 4; case .wanderlust: 5; case .enchanted: 6; case .vip: nil }
    }
    var giftReason: String {
        if let requiredBooks { return "A free gift for completing \(requiredBooks) books." }
        return "A free VIP colour theme for your first 10-day streak. Ten days of showing up for yourself."
    }
    var themes: [ColourThemeID] {
        switch self {
        case .storybook: [.parchment, .rose, .lavender, .ocean, .forest]
        case .wanderlust: [.terracotta, .honey, .sage, .lagoon, .twilight]
        case .enchanted: [.cherry, .glacier, .pearl, .cocoa, .starlight]
        case .vip: [.vip]
        }
    }
}
