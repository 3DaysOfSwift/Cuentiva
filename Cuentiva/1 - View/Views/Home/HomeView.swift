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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your next read").font(.system(.largeTitle, design: .serif, weight: .medium))
                        Text("Bring Spanish to life through stories.").font(.subheadline).foregroundStyle(theme.theme.muted)
                    }
                    Spacer(minLength: 5)
                    VStack { Text("\(viewModel.total)").font(.system(.largeTitle, design: .serif)); Text("BOOKS\nLEARNED").font(.system(size: 9, weight: .bold, design: .monospaced)).multilineTextAlignment(.center) }
                }
                if let book = viewModel.nextRead {
                    VStack(alignment: .leading, spacing: 16) {
                        BookCover(book: book, compact: true)
                            .frame(maxWidth: 190).frame(maxWidth: .infinity)
                        Text(book.englishTitle).font(.title2.weight(.semibold))
                        Text("\(book.level) · \(book.fullText.count) \(book.unitName)")
                            .font(.caption).foregroundStyle(theme.theme.muted)
                        Text(book.summary).font(.subheadline).foregroundStyle(theme.theme.muted)
                        Button { viewModel.selectedBook = book } label: {
                            HStack {
                                Text(viewModel.hasStarted(book) ? "Continue reading" : "Read this book")
                                Image(systemName: "arrow.right")
                            }
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                            .foregroundStyle(theme.theme.onAccent)
                            .background(theme.theme.accent, in: RoundedRectangle(cornerRadius: 18))
                        }.buttonStyle(.plain)
                    }
                } else {
                    Text("You’ve read every available book. Revisit a favourite in Completed, or share a story of your own.")
                        .foregroundStyle(theme.theme.muted)
                }
                Divider()
                Text("Explore our community library").font(.system(.title2, design: .serif, weight: .medium))
                Picker("Difficulty", selection: $viewModel.level) { ForEach(["All", "A1", "A2", "B1"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented)
                LibraryControls(format: $viewModel.format, sort: $viewModel.sort)
                Toggle("Hide completed books", isOn: $viewModel.hideCompleted)
                    .font(.subheadline).tint(theme.theme.accent)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 20)], spacing: 26) {
                    ForEach(viewModel.books) { book in
                        Button { viewModel.selectedBook = book } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                BookCover(book: book, completed: viewModel.completed(book), compact: true)
                                Text(book.englishTitle).font(.subheadline.weight(.semibold)).foregroundStyle(theme.theme.ink)
                                Text("\(book.level) · \(book.fullText.count) \(book.unitName)").font(.caption).foregroundStyle(theme.theme.muted)
                                Text(viewModel.coverage(book)).font(.caption2).foregroundStyle(theme.theme.muted)
                            }
                        }.buttonStyle(.plain)
                    }
                }
                if viewModel.books.isEmpty {
                    ContentUnavailableView {
                        Label("No matching books", systemImage: "books.vertical")
                    } description: {
                        Text(viewModel.hideCompleted ? "Try changing your filters or show completed books to read a favourite again." : "Try a different search or change your filters.")
                    } actions: {
                        if viewModel.hideCompleted {
                            Button("Show completed books") { viewModel.hideCompleted = false }
                                .tint(theme.theme.accent)
                        }
                    }
                }
                Text("DEMO EDITION • Original illustrative stories, not verified memoirs. Difficulty is approximate and considers more than vocabulary.").font(.caption2).foregroundStyle(theme.theme.muted).padding(.top, 8)
            }.padding(.horizontal, 23).padding(.bottom, 30)
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink).navigationTitle("Cuentiva").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.query, placement: .toolbar, prompt: "Find a story or a person")
            .searchToolbarBehavior(.minimize)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings") } }
            .fullScreenCover(item: $viewModel.selectedBook) { book in NavigationStack { LessonView(book: book) } }
    }
}
