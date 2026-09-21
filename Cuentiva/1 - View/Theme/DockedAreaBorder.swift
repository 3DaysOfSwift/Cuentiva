//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

/// Shared edge for controls anchored above the bottom safe area.
struct DockedAreaBorder: ViewModifier {
    @Environment(ThemeManager.self) private var theme

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            Rectangle().fill(theme.theme.ink.opacity(0.3)).frame(height: 1)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}

extension View {
    func dockedAreaBorder() -> some View { modifier(DockedAreaBorder()) }
}
