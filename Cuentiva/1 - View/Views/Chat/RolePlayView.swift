import SwiftUI

struct RolePlayView: View {
    @State private var model = RolePlayViewModel()
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
                if model.authors.isEmpty {
                    Button("Reload storytellers") { Task { await model.refresh() } }
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
        .task(id: model.revision) { await model.refresh() }
    }

    @ViewBuilder private func scenarioCell(_ scenario: ConversationScenario, index: Int) -> some View {
        let unlocked = model.isUnlocked(scenario)
        let count = model.completions(for: scenario)
        if unlocked, let author = model.author(at: index) {
            NavigationLink { ChatView(author: author, scenario: scenario) } label: {
                cellLabel(scenario, unlocked: true, completions: count, index: index)
            }.buttonStyle(.plain)
        } else {
            cellLabel(scenario, unlocked: unlocked, completions: count, index: index)
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
                Text(model.lockReason(for: scenario))
                    .font(.caption2).foregroundStyle(theme.theme.muted)
            } else if model.author(at: index) == nil {
                Text("Storytellers unavailable").font(.caption2)
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

