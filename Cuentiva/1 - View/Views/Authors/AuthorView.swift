import SwiftUI

struct AuthorView: View {
    let onContribute: () -> Void
    @State private var model: AuthorViewModel
    @Environment(ThemeManager.self) private var theme
    init(author: Author, onContribute: @escaping () -> Void) {
        self.onContribute = onContribute
        _model = State(initialValue: AuthorViewModel(author: author))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AuthorPortrait(author: model.author, size: 132).frame(maxWidth: .infinity)
                Text(model.author.name).font(.system(.largeTitle, design: .serif))
                Text("STORYTELLER").font(.caption.weight(.semibold)).foregroundStyle(theme.theme.accent)
                Text(model.author.introduction).font(.title3)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Behind the stories").font(.headline)
                    Text(model.author.note).font(.system(.body, design: .serif))
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 20))
                Text("Stories by \(model.author.name)").font(.system(.title2, design: .serif))
                ForEach(model.books) { book in
                    Button { model.selectedBook = book } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            BookCover(book: book, completed: model.completed(book), compact: true)
                            Text(book.englishTitle).font(.headline)
                            Text("\(book.level) · \(book.fullText.count) \(book.unitName)").font(.caption).foregroundStyle(theme.theme.muted)
                        }
                    }.buttonStyle(.plain)
                }
                Button(action: onContribute) { Label("Share a story of your own", systemImage: "square.and.pencil") }
            }.padding(23)
        }
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink).tint(theme.theme.accent)
        .navigationTitle(model.author.name).navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $model.selectedBook) { book in NavigationStack { LessonView(book: book) } }
    }
}
