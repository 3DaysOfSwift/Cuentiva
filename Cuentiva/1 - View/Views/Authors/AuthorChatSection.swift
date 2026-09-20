import SwiftUI

struct AuthorChatSection: View {
    let author: Author
    let coins: Int
    let fantasy: any FantasyFeature
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your turn to tell a story")
                .font(.system(.title, design: .serif, weight: .medium))
            Text("Talk with \(author.name) about your day, your travels, or a memory worth sharing. Practise turning your own life into Spanish conversation.")
                .foregroundStyle(theme.theme.muted)
            HStack(alignment: .top, spacing: 24) {
                if fantasy.profile != nil {
                    VStack(spacing: 8) {
                        PersonalStorytellerButton(feature: fantasy, size: 72)
                        Text("You").font(.subheadline.weight(.semibold))
                    }
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.title2).foregroundStyle(theme.theme.accent)
                        .frame(height: 72).accessibilityHidden(true)
                }
                VStack(spacing: 8) {
                    AuthorPortrait(author: author, size: 72)
                    Text(author.name).font(.subheadline.weight(.semibold))
                }
            }.frame(maxWidth: .infinity).padding(.vertical, 4)
            Divider()
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) {
                    balance
                    Spacer(minLength: 12)
                    cost
                }
                VStack(alignment: .leading, spacing: 16) {
                    balance
                    cost
                }
            }
            Text("One doubloon covers a topic until you leave the chat. Charged after your first successful reply, with no charge per message.")
                .font(.footnote).foregroundStyle(theme.theme.muted)
            if coins > 0 {
                NavigationLink { ChatView(author: author) } label: {
                    Label("Talk with \(author.name)", systemImage: "bubble.left.and.bubble.right")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .padding(.horizontal, 12)
                        .foregroundStyle(theme.theme.onAccent)
                        .background(theme.theme.accent, in: Capsule())
                }.buttonStyle(.plain)
                Text("Choose your topic and slide to confirm in chat.")
                    .font(.caption).foregroundStyle(theme.theme.muted)
            } else {
                Text("Complete a new book to earn a doubloon and start chatting.")
                    .font(.subheadline.weight(.semibold))
            }
            Text("A private, on-device conversation with an AI storyteller.")
                .font(.caption).foregroundStyle(theme.theme.muted)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24).strokeBorder(theme.theme.accent.opacity(0.18), lineWidth: 1)
        }
    }

    private var balance: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your balance").font(.caption).foregroundStyle(theme.theme.muted)
            DoubloonBalance(count: coins, size: 30).font(.headline).fixedSize()
        }
    }
    private var cost: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("One chat costs").font(.caption).foregroundStyle(theme.theme.muted)
            HStack(spacing: 8) {
                DoubloonIcon(size: 30)
                Text("1 doubloon").font(.headline)
            }.foregroundStyle(theme.theme.rewardGold).fixedSize()
        }
    }
}
