import SwiftUI
struct RootView: View {
    private enum LibraryTab { case discover, nearby, completed, contribute }
    @State private var selectedTab: LibraryTab = .discover
    @State private var viewModel = RootViewModel()
    @Environment(ThemeManager.self) private var theme
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Group {
            if viewModel.ready {
                if viewModel.hasAccess || viewModel.checkingAccess {
                    TabView(selection: $selectedTab) {
                        Tab("Discover", systemImage: "books.vertical", value: LibraryTab.discover) { NavigationStack { HomeView(onWrite: { selectedTab = .contribute }) } }
                        Tab("Nearby", systemImage: "location", value: LibraryTab.nearby) { NavigationStack { NearbyView() } }
                        Tab("Completed", systemImage: "checkmark.seal", value: LibraryTab.completed) { NavigationStack { CompletedView() } }
                        Tab("Write", systemImage: "square.and.pencil", value: LibraryTab.contribute) { NavigationStack { FantasyWritingView(feature: AppModel.shared.fantasy) } }
                    }
                    .disabled(!viewModel.hasAccess)
                    .overlay(alignment: .bottom) {
                        if viewModel.checkingAccess && !viewModel.hasAccess {
                            Text("Checking purchase access…")
                                .font(.caption).padding(10)
                                .background(theme.theme.surface, in: Capsule())
                                .padding(.bottom, 80).allowsHitTesting(false)
                        }
                    }
                } else { OnboardingView() }
            } else {
                LibrarySkeletonView()
                    .overlay(alignment: .center) {
                        if viewModel.error != nil {
                            VStack(spacing: 16) {
                                InlineError(message: viewModel.error)
                                Button("Retry") { Task { await viewModel.load() } }.buttonStyle(PrimaryButton())
                            }.padding(24).background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 18)).padding(24)
                        }
                    }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { theme.theme.paper.ignoresSafeArea() }.foregroundStyle(theme.theme.ink)
            .fullScreenCover(isPresented: $viewModel.showingStoryteller) {
                StorytellerRevealView(feature: AppModel.shared.fantasy) { viewModel.showingStoryteller = false }
            }
            .task { await viewModel.load() }
            .task { await viewModel.refreshPurchases() }
            .task(id: viewModel.ready) { if viewModel.ready { await viewModel.syncLibrary() } }
            .onChange(of: viewModel.hasAccess) { _, allowed in
                if allowed { Task { await viewModel.prepareReading() } }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await viewModel.refreshPurchases() }
                    Task { await viewModel.syncLibrary() }
                }
            }
    }
}
