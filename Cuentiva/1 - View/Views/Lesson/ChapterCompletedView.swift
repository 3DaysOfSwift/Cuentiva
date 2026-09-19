import SwiftUI

struct ChapterCompletedView: View {
    let hasNextChapter: Bool
    let onContinue: () -> Void
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 110)).foregroundStyle(theme.theme.accent)
                    .accessibilityHidden(true)
                Text("Completed")
                    .font(.system(.largeTitle, design: .serif, weight: .medium))
                Text("Well done! You’ve welcomed new Spanish words into your vocabulary. Now let them flow together as you read the story.")
                    .font(.title3).foregroundStyle(theme.theme.muted)
                Text(hasNextChapter ? "Revisit Chapter 1, then discover what happens next in Chapter 2." : "Read Chapter 1 again at your own pace, bringing each sentence together into a whole story.")
                    .font(.subheadline).foregroundStyle(theme.theme.muted)
            }.multilineTextAlignment(.center).padding(28).padding(.top, 50)
                .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Practice fluency  →", action: onContinue).buttonStyle(PrimaryButton())
                .padding(25).background(theme.theme.paper).dockedAreaBorder()
        }
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink)
    }
}
