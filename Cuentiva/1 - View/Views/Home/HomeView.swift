import SwiftUI
struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                StreakBar(count: viewModel.streak, days: viewModel.week)
                Divider()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) { Text("A little Spanish.\nA new perspective.").font(.system(.largeTitle, design: .serif, weight: .medium)); Text("Small stories. Ideas for everyday life.").font(.subheadline).foregroundStyle(theme.theme.muted) }
                    Spacer(minLength: 5)
                    VStack { Text("\(viewModel.total)").font(.system(.largeTitle, design: .serif)); Text("BOOKS\nLEARNED").font(.system(size: 9, weight: .bold, design: .monospaced)).multilineTextAlignment(.center) }
                }
                Picker("Difficulty", selection: $viewModel.level) { ForEach(["All", "A1", "A2", "B1"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 20)], spacing: 26) {
                    ForEach(viewModel.books) { book in
                        Button { viewModel.selectedBook = book } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                BookCover(book: book, completed: viewModel.completed(book), compact: true)
                                Text(book.englishTitle).font(.subheadline.weight(.semibold)).foregroundStyle(theme.theme.ink)
                                Text("\(book.level) · \(book.sentences.count) sentences").font(.caption).foregroundStyle(theme.theme.muted)
                                Text(viewModel.coverage(book)).font(.caption2).foregroundStyle(theme.theme.muted)
                            }
                        }.buttonStyle(.plain)
                    }
                }
                if viewModel.books.isEmpty { ContentUnavailableView.search(text: viewModel.query) }
                Text("DEMO EDITION • Original illustrative stories, not verified memoirs. Difficulty is approximate and considers more than vocabulary.").font(.caption2).foregroundStyle(theme.theme.muted).padding(.top, 8)
            }.padding(.horizontal, 23).padding(.bottom, 30)
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink).navigationTitle("Cuentiva").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.query, prompt: "Find a story or a person")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings") } }
            .fullScreenCover(item: $viewModel.selectedBook) { book in NavigationStack { LessonView(book: book) } }
    }
}
