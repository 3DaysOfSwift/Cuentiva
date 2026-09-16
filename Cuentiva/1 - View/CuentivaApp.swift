import SwiftUI

@main struct CuentivaApp: App {
    @State private var theme = ThemeManager()
    var body: some Scene {
        WindowGroup { RootView().environment(theme).tint(theme.theme.accent).preferredColorScheme(theme.theme.colorScheme) }
    }
}
