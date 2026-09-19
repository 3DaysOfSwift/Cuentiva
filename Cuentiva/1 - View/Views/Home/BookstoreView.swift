import SwiftUI

struct BookstoreView: View {
    @State private var viewModel = BookstoreViewModel()
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Find your next adventure.").font(.system(.largeTitle, design: .serif))
                Text("A1 – B1 Book Library").font(.system(.title2, design: .serif, weight: .medium))
                Picker("Difficulty", selection: $viewModel.level) {
                    ForEach(["All", "A1", "A2", "B1"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.segmented)
                LibraryControls(format: $viewModel.format, sort: $viewModel.sort, counts: viewModel.presentation.formatCounts, horizontalInset: 23)
                Toggle(
                    "Hide completed books",
                    isOn: $viewModel.hideCompleted
                )
                .font(.subheadline).tint(theme.theme.accent)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 20, alignment: .top)], spacing: 26) {
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
                                Text(book.summary).font(.caption).foregroundStyle(theme.theme.muted)
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
            }.padding(23)
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink)
            .navigationTitle("Bookstore").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.query, prompt: "Search the library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            .task(id: viewModel.refreshID) { await viewModel.refresh() }
            .fullScreenCover(item: $viewModel.selectedBook, onDismiss: { Task { await viewModel.refresh() } }) { book in
                NavigationStack { LessonView(book: book) }
            }
    }
}
