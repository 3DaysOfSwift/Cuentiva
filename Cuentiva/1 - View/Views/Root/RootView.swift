import SwiftUI

struct RootView: View {
    private enum LibraryTab { case discover, completed, write }
    @State private var selectedTab: LibraryTab = .discover
    @State private var viewModel = RootViewModel()
    @Environment(ThemeManager.self) private var theme
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Group {
            if viewModel.canShowContent {
                if viewModel.hasAccess {
                    TabView(selection: $selectedTab) {
                        Tab("Books", systemImage: "books.vertical", value: LibraryTab.discover) {
                            NavigationStack { HomeView(onWrite: viewModel.writingUnlocked ? { selectedTab = .write } : nil) }
                        }
                        Tab("Completed", systemImage: "checkmark.seal", value: LibraryTab.completed) {
                            NavigationStack { CompletedView() }
                        }
                        if viewModel.writingUnlocked {
                            Tab("Write", systemImage: "square.and.pencil", value: LibraryTab.write) {
                                NavigationStack { FantasyWritingView(feature: AppModel.shared.fantasy) }
                            }
                        }
                    }
                } else {
                    OnboardingView()
                }
            } else {
                LibrarySkeletonView()
                    .overlay(alignment: .center) {
                        if viewModel.error != nil {
                            VStack(spacing: 16) {
                                InlineError(message: viewModel.error)
                                Button("Retry") { Task { await viewModel.start() } }.buttonStyle(PrimaryButton())
                            }.padding(24).background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 18))
                                .padding(24)
                        }
                    }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { theme.theme.paper.ignoresSafeArea() }.foregroundStyle(theme.theme.ink)
            .fullScreenCover(isPresented: $viewModel.showingStoryteller) {
                StorytellerRevealView(feature: AppModel.shared.fantasy) { viewModel.showingStoryteller = false }
            }
            .task { await viewModel.start() }
            .task(id: viewModel.hasAccess && !viewModel.checkingAccess) {
                await viewModel.accessChanged()
            }
            .onChange(of: viewModel.writingUnlocked) { _, unlocked in
                if !unlocked && selectedTab == .write { selectedTab = .discover }
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
