import SwiftUI

struct HomeView: View {
    let onWrite: (() -> Void)?
    @State private var viewModel = HomeViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                StreakBar(days: viewModel.week)
                Divider()
                if !viewModel.dailyReads.isEmpty {
                    HStack {
                        if viewModel.dailyReadsCompleted {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.theme.accent)
                        }
                        Text("Today’s books")
                    }.font(.system(.title2, design: .serif, weight: .medium))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(viewModel.dailyReadsCompleted ? "Today’s books, completed" : "Today’s books")
                    ScrollView(.horizontal) {
                        HStack(spacing: 16) {
                            HStack(spacing: 16) {
                                ForEach(viewModel.dailyReads) { book in
                                    Button {
                                        viewModel.selectedBook = book
                                    } label: {
                                        BookCover(book: book, completed: viewModel.completed(book), compact: true)
                                            .frame(width: 190)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(
                                                        theme.theme.paper.opacity(
                                                            viewModel.focusedRead?.id == book.id ? 0 : 0.6)
                                                    )
                                                    .allowsHitTesting(false)
                                            }
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(theme.theme.accent, lineWidth: 3)
                                                    .opacity(viewModel.focusedRead?.id == book.id ? 1 : 0)
                                                    .allowsHitTesting(false)
                                            }
                                            .animation(
                                                reduceMotion ? nil : .easeInOut(duration: 0.2),
                                                value: viewModel.focusedRead?.id
                                            )
                                            .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)
                                    .id(book.id)
                                    .accessibilityAddTraits(viewModel.focusedRead?.id == book.id ? .isSelected : [])
                                    .accessibilityLabel(
                                        "\(book.englishTitle)\(viewModel.completed(book) ? ", completed" : ", unread")")
                                }
                            }.scrollTargetLayout()
                            // Outside the book targets: scrolling here never selects a fourth book.
                            if viewModel.showTomorrowFooter {
                                TomorrowFooter()
                            }
                        }
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
                            NavigationLink {
                                AuthorView(author: book.storyteller)
                            } label: {
                                AuthorPortrait(author: book.storyteller, size: 76)
                                    .overlay(alignment: .bottomTrailing) {
                                        if viewModel.completed(book) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(theme.theme.onAccent, theme.theme.accent)
                                                .font(.system(size: 28))
                                                .background(theme.theme.paper, in: Circle())
                                                .accessibilityHidden(true)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("About \(book.storytellerName)")
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    if viewModel.completed(book) {
                                        Image(systemName: "checkmark").foregroundStyle(theme.theme.accent)
                                            .accessibilityHidden(true)
                                    }
                                    Text(book.title).fixedSize(horizontal: false, vertical: true)
                                }.font(.title2.weight(.semibold))
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel(book.title + (viewModel.completed(book) ? ", completed" : ""))
                                Text(book.englishTitle).font(.subheadline)
                                    .foregroundStyle(theme.theme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("By \(book.storytellerName)")
                                    .font(.subheadline).foregroundStyle(theme.theme.muted)
                            }
                        }
                        Text("\(book.level) · \(book.fullText.count) \(book.unitName)")
                            .font(.caption).foregroundStyle(theme.theme.muted)
                        Text(book.summary).font(.subheadline).foregroundStyle(theme.theme.muted)
                        Button {
                            Task { await viewModel.performReadingAction() }
                        } label: {
                            HStack {
                                Text(viewModel.readButtonTitle)
                                Image(systemName: "arrow.right")
                            }
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                            .foregroundStyle(viewModel.dailyReadsCompleted ? theme.theme.accent : theme.theme.onAccent)
                            .background(viewModel.dailyReadsCompleted ? Color.clear : theme.theme.accent, in: RoundedRectangle(cornerRadius: 18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(theme.theme.accent, lineWidth: viewModel.dailyReadsCompleted ? 1.5 : 0)
                            }
                        }.buttonStyle(.plain).disabled(viewModel.preparingDailyReads)
                    }
                } else {
                    Text("New stories will appear here as the library grows.")
                        .foregroundStyle(theme.theme.muted)
                }
                if let notice = viewModel.dailyReadingNotice {
                    Text(notice).font(.caption).foregroundStyle(theme.theme.muted)
                }
                if let error = viewModel.dailyReadingError {
                    Text(error).font(.caption).foregroundStyle(theme.theme.muted)
                    Button("Retry") { Task { await viewModel.retryDailyReads() } }.disabled(viewModel.preparingDailyReads)
                }
                if viewModel.revisiting {
                    Text("A fresh look at your collection. Your reading progress is safely kept.")
                        .font(.subheadline).foregroundStyle(theme.theme.muted)
                }
                Divider()
                Text("Bring Spanish to life through stories").font(.system(.title2, design: .serif, weight: .medium))
                CommunityAuthors(authors: viewModel.authors, onWrite: onWrite, horizontalInset: 23)
                Picker("Difficulty", selection: $viewModel.level) {
                    ForEach(["All", "A1", "A2", "B1"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.segmented)
                LibraryControls(format: $viewModel.format, sort: $viewModel.sort)
                Toggle(
                    viewModel.revisiting && viewModel.query.isEmpty && viewModel.sort == .library
                        ? "Daily selection · revisiting favourites" : "Hide completed books",
                    isOn: $viewModel.hideCompleted
                )
                .font(.subheadline).tint(theme.theme.accent)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 20)], spacing: 26) {
                    ForEach(viewModel.books) { book in
                        Button {
                            viewModel.selectedBook = book
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                BookCover(book: book, completed: viewModel.completed(book), compact: true)
                                Text(book.englishTitle).font(.subheadline.weight(.semibold)).foregroundStyle(
                                    theme.theme.ink)
                                Text("\(book.level) · \(book.fullText.count) \(book.unitName)").font(.caption)
                                    .foregroundStyle(theme.theme.muted)
                                Text(viewModel.coverage(book)).font(.caption2).foregroundStyle(theme.theme.muted)
                            }
                        }.buttonStyle(.plain)
                    }
                }
                if viewModel.books.isEmpty {
                    ContentUnavailableView {
                        Label("No matching books", systemImage: "books.vertical")
                    } description: {
                        Text(
                            viewModel.hideCompleted
                                ? "Try changing your filters or show completed books to read a favourite again."
                                : "Try a different search or change your filters.")
                    } actions: {
                        if viewModel.hideCompleted {
                            Button("Show completed books") { viewModel.hideCompleted = false }
                                .tint(theme.theme.accent)
                        }
                    }
                }
                Text(
                    "DEMO EDITION • Original illustrative stories, not verified memoirs. Difficulty is approximate and considers more than vocabulary."
                ).font(.caption2).foregroundStyle(theme.theme.muted).padding(.top, 8)
            }.padding(.horizontal, 23).padding(.bottom, 30)
                .overlay(alignment: .top) {
                    HiddenProgressView()
                        .fixedSize(horizontal: false, vertical: true)
                        .alignmentGuide(.top) { dimensions in dimensions[.bottom] + 80 }
                }
        }.scrollBounceBehavior(.always, axes: .vertical)
            .background(theme.theme.paper).foregroundStyle(theme.theme.ink).navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.query, placement: .toolbar, prompt: "Find a story or a person")
            .searchToolbarBehavior(.minimize)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        StatsView()
                    } label: {
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
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }.accessibilityLabel("Settings")
                }
            }
            // Persist the daily selection after this screen is mounted, never from library loading.
            .task { await viewModel.prepareDailyReads() }
            .task(id: viewModel.refreshID) { await viewModel.refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await viewModel.prepareDailyReads() } }
            }
            .fullScreenCover(item: $viewModel.selectedBook, onDismiss: { Task { await viewModel.refresh(); viewModel.focusNextRead() } }) { book in
                NavigationStack { LessonView(book: book) }
            }
    }
}
