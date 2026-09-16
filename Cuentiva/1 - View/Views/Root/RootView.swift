import SwiftUI
struct RootView: View {
    @State private var viewModel = RootViewModel()
    @Environment(ThemeManager.self) private var theme
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Group {
            if viewModel.ready {
                if viewModel.hasAccess {
                    TabView {
                        Tab("Discover", systemImage: "books.vertical") { NavigationStack { HomeView() } }
                        Tab("Completed", systemImage: "checkmark.seal") { NavigationStack { CompletedView() } }
                        Tab("Contribute", systemImage: "square.and.pencil") { NavigationStack { ContributionView() } }
                    }
                } else { OnboardingView() }
            } else {
                VStack(spacing: 20) { Text("Cuentiva").font(.largeTitle.bold()); if viewModel.error == nil { ProgressView() }; InlineError(message: viewModel.error); if viewModel.error != nil { Button("Retry") { Task { await viewModel.load() } } } }
            }
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink)
            .task { await viewModel.load() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await viewModel.load() } } }
    }
}
