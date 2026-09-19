import SwiftUI

struct WhosAppView: View {
    @State private var model = WhosAppViewModel()
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if model.unlocked {
                    Text("Who will you tell your story to?")
                        .font(.system(.largeTitle, design: .serif))
                    Text("Practise messaging your future Spanish-speaking friends. Start with a real moment from your life.")
                        .foregroundStyle(theme.theme.muted)
                    Label("\(model.coins) doubloons", systemImage: "circle.circle.fill")
                        .foregroundStyle(theme.theme.accent)
                    Text("Your first message starts a topic for 1 doubloon. Keep chatting until you leave the conversation. Choosing a storyteller costs nothing.")
                        .font(.footnote).foregroundStyle(theme.theme.muted)
                    ForEach(model.authors) { author in
                        NavigationLink { ChatView(author: author) } label: {
                            HStack(spacing: 16) {
                                AuthorPortrait(author: author, size: 64)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(author.storyteller.name).font(.headline)
                                    Text("Spanish conversation partner").font(.subheadline)
                                        .foregroundStyle(theme.theme.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").accessibilityHidden(true)
                            }.padding(16)
                                .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 18))
                        }.buttonStyle(.plain)
                    }
                    Text("Your partners are AI storytellers, not real people. Chat uses Apple Intelligence on a supported device.")
                        .font(.caption).foregroundStyle(theme.theme.muted)
                } else {
                    ContentUnavailableView("Keep reading", systemImage: "books.vertical",
                        description: Text("WhosApp unlocks after \(ReadingMilestones.chatOfferBookCount) completed books."))
                }
            }.padding(24)
        }
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink).tint(theme.theme.accent)
        .navigationTitle("WhosApp").navigationBarTitleDisplayMode(.inline)
        .task(id: model.revision) { await model.refresh() }
    }
}
