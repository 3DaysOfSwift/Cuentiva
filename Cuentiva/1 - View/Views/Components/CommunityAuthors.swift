import SwiftUI

struct CommunityAuthors: View {
    let authors: [Author]
    let onWrite: (() -> Void)?
    var horizontalInset: CGFloat = 0
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                Text("Meet the storytellers").font(.system(.title2, design: .serif, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                NavigationLink { AuthorView(author: .pipa, onWrite: onWrite) } label: {
                    AuthorPortrait(author: .pipa, size: 48)
                }.buttonStyle(.plain).accessibilityLabel("Meet Pipa, your travelling companion")
            }
            Text("Helping bring Spanish to life through our storytelling")
                .font(.subheadline).foregroundStyle(theme.theme.muted)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 26) {
                    ForEach(Array(authors.prefix(3))) { author in
                        NavigationLink { AuthorView(author: author, onWrite: onWrite) } label: {
                            VStack(spacing: 8) {
                                AuthorPortrait(author: author)
                                Text(author.storyteller.name).font(.subheadline.weight(.semibold))
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .frame(minWidth: 90)
                        }.buttonStyle(.plain).accessibilityLabel("Explore stories credited to \(author.name)")
                    }
                }.padding(.vertical, 4)
            }
            .contentMargins(.horizontal, horizontalInset, for: .scrollContent)
            .scrollIndicators(.hidden)
            // Extend the viewport to the screen edges while aligning its first item with the text.
            .padding(.horizontal, -horizontalInset)
            Text("Our storytellers guide you through the shared collection, one little adventure at a time.")
                .font(.caption).foregroundStyle(theme.theme.muted)
            if let onWrite {
                Button(action: onWrite) {
                    Label("Create your own tale", systemImage: "square.and.pencil").font(.subheadline.weight(.semibold))
                }.tint(theme.theme.accent)
            }
        }
    }
}
