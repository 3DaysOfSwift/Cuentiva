//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

@main struct CuentivaApp: App {
    @State private var theme = ThemeManager()
    var body: some Scene {
        WindowGroup { RootView().environment(theme).tint(theme.theme.accent).preferredColorScheme(theme.theme.colorScheme) }
    }
}
