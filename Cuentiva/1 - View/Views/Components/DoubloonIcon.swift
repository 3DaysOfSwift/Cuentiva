//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct DoubloonIcon: View {
    @Environment(ThemeManager.self) private var theme
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [theme.theme.coinHighlight, theme.theme.coinGold,
                theme.theme.coinShadow], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().strokeBorder(theme.theme.coinShadow, lineWidth: size * 0.035)
            Circle().inset(by: size * 0.09)
                .strokeBorder(theme.theme.coinHighlight.opacity(0.9), lineWidth: size * 0.025)
            Circle().inset(by: size * 0.14)
                .strokeBorder(theme.theme.coinShadow.opacity(0.5), lineWidth: size * 0.018)
            Image(systemName: "book.closed.fill")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(theme.theme.coinShadow)
                .shadow(color: theme.theme.coinHighlight, radius: 0, x: 0, y: size * 0.015)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
