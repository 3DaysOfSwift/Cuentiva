import SwiftUI

struct AuthorView: View {
    @State private var model: AuthorViewModel
    @Environment(ThemeManager.self) private var theme
    init(author: Author) { _model = State(initialValue: AuthorViewModel(author: author)) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AuthorPortrait(author: model.author, size: 132).frame(maxWidth: .infinity)
                Text(model.author.name).font(.system(.largeTitle, design: .serif))
                Text("FICTIONAL DEMO AUTHOR").font(.caption.weight(.semibold)).foregroundStyle(theme.theme.accent)
                Text(model.author.introduction).font(.title3)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Behind the story").font(.headline)
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
                Text("This profile, its personal note and illustrated portrait are fictional demonstrations. These stories are not verified memoirs.")
                    .font(.footnote).foregroundStyle(theme.theme.muted)
                NavigationLink { ContributionView() } label: { Label("Share a story of your own", systemImage: "square.and.pencil") }
            }.padding(23)
        }
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink).tint(theme.theme.accent)
        .navigationTitle(model.author.name).navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $model.selectedBook) { book in NavigationStack { LessonView(book: book) } }
    }
}
