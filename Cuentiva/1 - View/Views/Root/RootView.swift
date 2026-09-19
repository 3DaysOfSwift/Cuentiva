import SwiftUI

struct RootView: View {
    private enum LibraryTab { case today, bookstore, completed, whosApp }
    @State private var selectedTab: LibraryTab = .today
    @State private var viewModel = RootViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ThemeManager.self) private var theme
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Group {
            if let welcome = viewModel.dailyWelcome, viewModel.hasAccess, !viewModel.checkingAccess, viewModel.error == nil {
                DailyWelcomeView(viewModel: welcome, ready: viewModel.ready) {
                    Task { await viewModel.beginDay() }
                }.transition(.opacity)
            } else if viewModel.canShowContent {
                if viewModel.hasAccess {
                    TabView(selection: $selectedTab) {
                        Tab("Today", systemImage: "sun.max", value: LibraryTab.today) {
                            NavigationStack { HomeView(viewModel: viewModel.today) }
                        }
                        Tab("Bookstore", systemImage: "books.vertical", value: LibraryTab.bookstore) {
                            NavigationStack { BookstoreView() }
                        }
                        if viewModel.chatUnlocked {
                            Tab("WhosApp", systemImage: "bubble.left.and.bubble.right", value: LibraryTab.whosApp) {
                                NavigationStack { WhosAppView() }
                            }
                        }
                        Tab("Completed", systemImage: "checkmark.seal", value: LibraryTab.completed) {
                            NavigationStack { CompletedView() }
                        }
                    }
                } else {
                    OnboardingView()
                }
            } else {
                VStack(spacing: 16) {
                    if let error = viewModel.error {
                        InlineError(message: error)
                        Button("Retry") { Task { await viewModel.start() } }
                            .buttonStyle(PrimaryButton())
                    } else {
                        Color.clear.accessibilityHidden(true)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: viewModel.dailyWelcome != nil)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { theme.theme.paper.ignoresSafeArea() }.foregroundStyle(theme.theme.ink)
            .fullScreenCover(isPresented: $viewModel.showingStoryteller) {
                StorytellerRevealView(feature: AppModel.shared.fantasy) { viewModel.showingStoryteller = false }
            }
            .task { await viewModel.start() }
            .task(id: viewModel.hasAccess && !viewModel.checkingAccess) {
                await viewModel.accessChanged()
            }
            .onChange(of: viewModel.chatUnlocked) { _, unlocked in
                if !unlocked && selectedTab == .whosApp { selectedTab = .today }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background: viewModel.enteredBackground()
                case .active: Task { await viewModel.becameActive() }
                default: break
                }
            }
    }
}
