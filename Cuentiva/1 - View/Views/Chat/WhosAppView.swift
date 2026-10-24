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
                    Text("Chat with a Storyteller").font(.system(.largeTitle, design: .serif))
                    UserDoubloonBalance(count: model.coins)
                    ForEach(model.authors) { author in
                        NavigationLink { ChatView(author: author) } label: {
                            HStack(spacing: 16) {
                                AuthorPortrait(author: author, size: 64)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(author.storyteller.name).font(.headline)
                                    Text("Spanish conversation partner").font(.subheadline)
                                        .foregroundStyle(theme.theme.muted)
                                    HStack(spacing: 6) {
                                        DoubloonIcon(size: 18)
                                        Text("1 doubloon per chat")
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(theme.theme.rewardGold)
                                    Text("No payment yet · Confirm on next screen")
                                        .font(.caption2)
                                        .foregroundStyle(theme.theme.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").accessibilityHidden(true)
                            }.padding(16)
                                .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 18))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(theme.theme.accent.opacity(0.5), lineWidth: 1.5)
                                }
                        }.buttonStyle(.plain)
                    }
                    Divider().padding(.vertical, 4)
                    Text("Role Play").font(.system(.title, design: .serif))
                    NavigationLink { RolePlayView() } label: {
                        HStack(spacing: 18) {
                            ZStack {
                                Circle().fill(theme.theme.rewardGold.opacity(0.18))
                                Image(systemName: "person.2.wave.2.fill")
                                    .font(.system(size: 32, weight: .semibold)).foregroundStyle(theme.theme.rewardGold)
                            }.frame(width: 68, height: 68)
                            VStack(alignment: .leading, spacing: 7) {
                                Text("Role Play Real Life").font(.title2.bold())
                                Text("Practise what people say next").font(.subheadline)
                                    .foregroundStyle(theme.theme.muted)
                                HStack(spacing: 7) {
                                    DoubloonIcon(size: 24)
                                    Text("2 doubloons per Role Play").font(.caption.bold())
                                }.foregroundStyle(theme.theme.rewardGold)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.title3.bold()).accessibilityHidden(true)
                        }.padding(18)
                            .background(theme.theme.rewardGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(theme.theme.rewardGold, lineWidth: 2))
                    }.buttonStyle(.plain)
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
