import SwiftUI

struct CommunityAuthors: View {
    let authors: [Author]
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Little stories. Real connections.").font(.system(.title3, design: .serif))
            Text("Discover someone’s world—and share a little of yours.")
                .font(.subheadline).foregroundStyle(theme.theme.muted)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 26) {
                    ForEach(authors) { author in
                        NavigationLink { AuthorView(author: author) } label: {
                            VStack(spacing: 8) {
                                AuthorPortrait(author: author)
                                Text(author.name).font(.subheadline.weight(.semibold))
                            }
                        }.buttonStyle(.plain).accessibilityLabel("Meet \(author.name), demo author")
                    }
                }.padding(.vertical, 4)
            }.scrollIndicators(.hidden)
            Text("Meet our fictional demo authors. Your voice could be part of the next chapter.")
                .font(.caption).foregroundStyle(theme.theme.muted)
            NavigationLink { ContributionView() } label: {
                Label("Share your story", systemImage: "square.and.pencil").font(.subheadline.weight(.semibold))
            }.tint(theme.theme.accent)
        }
    }
}
