//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct WhosAppView: View {
    @State private var model = WhosAppViewModel()
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if model.unlocked {
                    Text("WhosApp · Chat")
                        .font(.system(.largeTitle, design: .serif))
                    Text("Practise messaging your future Spanish-speaking friends. Start with a real moment from your life.")
                        .foregroundStyle(theme.theme.muted)
                    DoubloonBalance(count: model.coins, size: 38).font(.title3.weight(.semibold))
                    HStack(spacing: 10) {
                        DoubloonIcon(size: 26)
                        Text("1 doubloon · one conversation").font(.headline)
                    }
                    Text("Choose a storyteller, then slide to confirm the cost. You’re charged only after the first successful reply. Each coin covers up to \(ChatLimits.messagesPerCoin) sent messages. Return within 10 minutes to resume your saved conversation.")
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
        .navigationTitle("WhosApp · Chat").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundStyle(theme.theme.accent).accessibilityHidden(true)
                    Text("WhosApp · Chat")
                }.font(.headline).accessibilityAddTraits(.isHeader)
            }
        }
        .task(id: model.revision) { await model.refresh() }
    }
}
