import SwiftUI
struct CompletedView: View {
    @State private var viewModel = CompletedViewModel()
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Text("Look how far\nyou’ve read.").font(.system(.largeTitle, design: .serif))
                Text("Every finished story belongs here. Your collection stays with you, even when a streak ends.").foregroundStyle(theme.theme.muted)
                LibraryControls(format: $viewModel.format, sort: $viewModel.sort)
                if viewModel.books.isEmpty { ContentUnavailableView("No completed books here", systemImage: "books.vertical", description: Text("Try another filter or finish a book to add it to your shelf.")) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 20)], spacing: 25) {
                    ForEach(viewModel.books) { book in Button { viewModel.selectedBook = book } label: { BookCover(book: book, completed: true, compact: true) }.buttonStyle(.plain) }
                }
            }.padding(24)
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink).navigationTitle("Completed books").searchable(text: $viewModel.query, prompt: "Search your collection")
            .fullScreenCover(item: $viewModel.selectedBook) { book in NavigationStack { LessonView(book: book) } }
    }
}
