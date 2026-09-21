//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI
struct CompletedView: View {
    @State private var practiceBook: Book?
    @State private var matchMode = false
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CompletedViewModel()
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                VStack(alignment: .leading, spacing: 6) {
                    PersonalStorytellerButton(feature: AppModel.shared.fantasy, size: 100)
                        .padding(.bottom, 10)
                    Text("\(viewModel.total)").font(.system(size: 72, weight: .medium, design: .serif)).monospacedDigit()
                    Text(viewModel.total == 1 ? "BOOK READ" : "BOOKS READ").font(.headline).tracking(2)
                    DoubloonBalance(count: viewModel.doubloons)
                }
                Text("Look how far you’ve read.").font(.system(.title2, design: .serif))
                Text("Every finished story belongs here. Your collection stays with you, even when a streak ends.").foregroundStyle(theme.theme.muted)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your reading rhythm")
                        .font(.system(.title2, design: .serif, weight: .medium))
                    StreakBar(days: viewModel.week)
                    VStack(alignment: .leading, spacing: 6) {
                        Label("\(viewModel.streak)-day streak", systemImage: "flame.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(theme.theme.accent)
                        Text("\(viewModel.practiceDays) \(viewModel.practiceDays == 1 ? "day" : "days") practised in total")
                            .font(.subheadline).foregroundStyle(theme.theme.muted)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 24))
                LibraryControls(format: $viewModel.format, sort: $viewModel.sort, counts: viewModel.presentation.formatCounts, horizontalInset: 24)
                if viewModel.books.isEmpty { ContentUnavailableView("No completed books here", systemImage: "books.vertical", description: Text("Try another filter or finish a book to add it to your shelf.")) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 20)], spacing: 25) {
                    ForEach(viewModel.books) { book in
                        VStack {
                            Button { viewModel.selectedBook = book } label: { BookCover(book: book, completed: true, compact: true) }.buttonStyle(.plain)
                                .contextMenu { options(book) }
                            Menu { options(book) } label: { Label("Book activities", systemImage: "ellipsis.circle") }.font(.caption)
                        }
                    }
                }
            }.padding(24)
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink).navigationTitle("Completed books").searchable(text: $viewModel.query, prompt: "Search your collection")
            .task(id: viewModel.refreshID) { await viewModel.refresh() }
            .fullScreenCover(item: $viewModel.selectedBook) { book in NavigationStack { BookReaderView(book: book).toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { viewModel.selectedBook = nil } } } } }
            .fullScreenCover(item: $practiceBook) { book in NavigationStack { PracticeView(book: book, match: matchMode) } }
    }
    @ViewBuilder private func options(_ book: Book) -> some View {
        Button("Read full book") { viewModel.selectedBook = book }
        Button("Your turn") { matchMode = false; practiceBook = book }
        Button("Match pairs") { matchMode = true; practiceBook = book }
    }
}
