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
                    NavigationLink { RolePlayView(model: model) } label: {
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

private struct RolePlayView: View {
    let model: WhosAppViewModel
    @Environment(ThemeManager.self) private var theme
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Role Play Real Life").font(.system(.largeTitle, design: .serif))
                Text("Don’t just learn the sentence. Practise what the other person says next.")
                    .foregroundStyle(theme.theme.muted)
                UserDoubloonBalance(count: model.coins)
                HStack {
                    Spacer(minLength: 0)
                    Text("\(model.totalRolePlays) completed")
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                }
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Array(ConversationScenario.catalogue.enumerated()), id: \.element.id) { index, scenario in
                        scenarioCell(scenario, index: index)
                    }
                }
            }.padding(24)
        }
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink).tint(theme.theme.accent)
        .navigationTitle("Role Play").navigationBarTitleDisplayMode(.inline)
        .id(model.progressRevision)
    }

    @ViewBuilder private func scenarioCell(_ scenario: ConversationScenario, index: Int) -> some View {
        let unlocked = model.isUnlocked(index)
        let count = model.completions(for: scenario)
        if unlocked, !model.authors.isEmpty {
            let author = model.authors[index % model.authors.count]
            NavigationLink { ChatView(author: author, scenario: scenario) } label: {
                cellLabel(scenario, unlocked: true, completions: count, index: index)
            }.buttonStyle(.plain)
        } else {
            cellLabel(scenario, unlocked: false, completions: count, index: index)
                .accessibilityElement(children: .combine)
        }
    }

    private func cellLabel(_ scenario: ConversationScenario, unlocked: Bool, completions: Int, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: scenario.symbol).font(.system(size: 32, weight: .semibold))
                Spacer()
                Image(systemName: unlocked ? "chevron.right" : "lock.fill")
                    .font(.caption.bold())
            }.foregroundStyle(unlocked ? theme.theme.accent : theme.theme.muted)
            Text(scenario.title).font(.headline).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if !unlocked {
                Text("Complete \(ConversationScenario.catalogue[index - 1].title) once")
                    .font(.caption2).foregroundStyle(theme.theme.muted)
            } else if completions > 0 {
                Label("\(completions) completed", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(theme.theme.rewardGold)
            } else {
                HStack(spacing: 5) { DoubloonIcon(size: 19); Text("2 doubloons") }
                    .font(.caption.weight(.semibold)).foregroundStyle(theme.theme.rewardGold)
            }
        }.padding(16).frame(maxWidth: .infinity, minHeight: 166, alignment: .leading)
            .background(theme.theme.surface.opacity(unlocked ? 1 : 0.6), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(
                unlocked ? theme.theme.accent.opacity(0.65) : theme.theme.muted.opacity(0.25), lineWidth: unlocked ? 1.5 : 1))
    }
}

private struct UserDoubloonBalance: View {
    let count: Int
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        HStack(spacing: 14) {
            PersonalStorytellerButton(feature: AppModel.shared.fantasy, size: 64)
            Divider().frame(height: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text("Your balance")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.theme.muted)
                DoubloonBalance(count: count, size: 38)
                    .font(.title2.weight(.semibold))
            }
            Spacer(minLength: 0)
        }
    }
}
