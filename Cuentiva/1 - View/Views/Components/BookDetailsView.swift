import SwiftUI

/// The same story and storyteller information accompanies each reading entry point.
struct BookDetailsView: View {
    let book: Book
    var completed = false
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                NavigationLink { AuthorView(author: book.storyteller) } label: {
                    AuthorPortrait(author: book.storyteller, size: 76)
                        .overlay(alignment: .bottomTrailing) {
                            if completed {
                                Image(systemName: "checkmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(theme.theme.onAccent, theme.theme.accent)
                                    .font(.system(size: 28))
                                    .background(theme.theme.paper, in: Circle())
                                    .accessibilityHidden(true)
                            }
                        }
                }.buttonStyle(.plain).accessibilityLabel("About \(book.storytellerName)")
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if completed {
                            Image(systemName: "checkmark").foregroundStyle(theme.theme.accent)
                                .accessibilityHidden(true)
                        }
                        Text(book.title).fixedSize(horizontal: false, vertical: true)
                    }.font(.title2.weight(.semibold))
                        .accessibilityLabel(book.title + (completed ? ", completed" : ""))
                    Text(book.englishTitle).font(.subheadline).foregroundStyle(theme.theme.muted)
                    Text("By \(book.storytellerName)").font(.subheadline).foregroundStyle(theme.theme.muted)
                }
            }
            Text("\(book.level) · \(book.fullText.count) \(book.unitName)")
                .font(.caption).foregroundStyle(theme.theme.muted)
            Text(book.summary).font(.subheadline).foregroundStyle(theme.theme.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
