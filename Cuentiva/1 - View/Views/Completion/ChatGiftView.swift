import SwiftUI

struct ChatGiftView: View {
    let onFinish: () -> Void
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                Image(systemName: "gift.fill").font(.system(size: 110))
                    .foregroundStyle(theme.theme.accent).accessibilityHidden(true)
                Text("\(ReadingMilestones.chatOfferBookCount) books completed")
                    .font(.headline).foregroundStyle(theme.theme.accent)
                Text("Your words are ready\nfor a conversation.")
                    .font(.system(.largeTitle, design: .serif))
                Label("Meet WhosApp", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.title2.weight(.semibold))
                Text("Your new gift is Spanish messaging practice. Choose a storyteller and practise chatting with the Spanish-speaking friends you haven’t met yet.")
                Text("Tell them about a journey, a funny afternoon, or something that happened today. Learn to tell the tales of your own life, one message at a time.")
                Text("WhosApp now has its own tab. Each new topic costs 1 earned doubloon, covering up to \(ChatLimits.messagesPerCoin) sent messages. Return within 10 minutes to resume.")
                    .font(.subheadline).foregroundStyle(theme.theme.muted)
            }.multilineTextAlignment(.center).padding(28)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            NavigationLink {
                WhosAppView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done", action: onFinish)
                        }
                    }
            } label: {
                Text("Choose my storyteller →")
            }.buttonStyle(PrimaryButton())
                .padding(24).background(theme.theme.paper).dockedAreaBorder()
        }
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink)
        .navigationTitle("A gift for you").navigationBarTitleDisplayMode(.inline)
    }
}
