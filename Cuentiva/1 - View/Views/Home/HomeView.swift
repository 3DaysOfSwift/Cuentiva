import SwiftUI
struct HomeView: View {
    let onContribute: () -> Void
    @State private var viewModel = HomeViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                StreakBar(days: viewModel.week)
                Divider()
                if !viewModel.dailyReads.isEmpty {
                    Text("Today’s books")
                        .font(.headline)
                        .foregroundStyle(theme.theme.muted)
                    ScrollView(.horizontal) {
                        HStack(spacing: 16) {
                            ForEach(viewModel.dailyReads) { book in
                                Button { viewModel.selectedBook = book } label: {
                                    BookCover(book: book, completed: viewModel.completed(book), compact: true)
                                        .frame(width: 190)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                .id(book.id)
                                .accessibilityLabel("\(book.englishTitle)\(viewModel.completed(book) ? ", completed" : ", unread")")
                            }
                        }.scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, 23, for: .scrollContent)
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $viewModel.focusedBookID, anchor: .center)
                    .padding(.horizontal, -23)

                }
                if let book = viewModel.focusedRead {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center, spacing: 16) {
                            NavigationLink { AuthorView(author: book.storyteller) } label: {
                                AuthorPortrait(author: book.storyteller, size: 76)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("About \(book.storytellerName)")
                            VStack(alignment: .leading, spacing: 6) {
                                Text(book.englishTitle).font(.title2.weight(.semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("By \(book.storytellerName)")
                                    .font(.subheadline).foregroundStyle(theme.theme.muted)
                            }
                        }
                        Text("\(book.level) · \(book.fullText.count) \(book.unitName)")
                            .font(.caption).foregroundStyle(theme.theme.muted)
                        Text(book.summary).font(.subheadline).foregroundStyle(theme.theme.muted)
                        Button { viewModel.selectedBook = book } label: {
                            HStack {
                                Text(viewModel.readButtonTitle)
                                Image(systemName: "arrow.right")
                            }
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                            .foregroundStyle(theme.theme.onAccent)
                            .background(theme.theme.accent, in: RoundedRectangle(cornerRadius: 18))
                        }.buttonStyle(.plain)
                    }
                } else {
                    Text("New stories will appear here as the library grows.")
                        .foregroundStyle(theme.theme.muted)
                }
                if let error = viewModel.dailyReadingError {
                    Text(error).font(.caption).foregroundStyle(theme.theme.muted)
                    Button("Retry") { Task { await viewModel.prepareDailyReads() } }
                }
                if viewModel.revisiting {
                    Text("A fresh look at your collection. Your reading progress is safely kept.")
                        .font(.subheadline).foregroundStyle(theme.theme.muted)
                }
                Divider()
                Text("Bring Spanish to life through stories").font(.system(.title2, design: .serif, weight: .medium))
                CommunityAuthors(authors: viewModel.authors, onContribute: onContribute, horizontalInset: 23)
                Picker("Difficulty", selection: $viewModel.level) { ForEach(["All", "A1", "A2", "B1"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented)
                LibraryControls(format: $viewModel.format, sort: $viewModel.sort)
                Toggle(viewModel.revisiting && viewModel.query.isEmpty && viewModel.sort == .library ? "Daily selection · revisiting favourites" : "Hide completed books", isOn: $viewModel.hideCompleted)
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
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink).navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.query, placement: .toolbar, prompt: "Find a story or a person")
            .searchToolbarBehavior(.minimize)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { StatsView() } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "flame.fill")
                        Text("\(viewModel.streak)").monospacedDigit()
                    }
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.theme.accent)
                        .fixedSize()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(viewModel.streak) day streak")
                    }
                    .accessibilityHint("View your reading statistics")
                }
                ToolbarItem(placement: .topBarTrailing) { NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings") }
            }
            .task(id: viewModel.dailyReads.map(\.id)) { await viewModel.prepareDailyReads() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await viewModel.prepareDailyReads() } }
            }
            .fullScreenCover(item: $viewModel.selectedBook, onDismiss: { viewModel.focusNextRead() }) { book in NavigationStack { LessonView(book: book) } }
    }
}
