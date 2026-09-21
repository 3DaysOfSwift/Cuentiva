import SwiftUI

struct LanguageTipView: View {
    let term: LanguageTerm
    let busy: Bool
    let error: String?
    let continueToToday: () -> Void
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label("A little language tip", systemImage: "lightbulb.fill")
                    .font(.headline).foregroundStyle(theme.theme.rewardGold)
                Text(term.english).font(.system(.largeTitle, design: .serif))
                Text(term.spanish).font(.title3).foregroundStyle(theme.theme.accent)
                Text(term.meaning).font(.title3.weight(.semibold))
                Text(term.explanation)
                example("IN ENGLISH", term.englishExample)
                example("IN SPANISH", term.spanishExample)
                Text(term.takeaway).font(.headline)
                Text("You can revisit every term in Settings → Decipher language terms.")
                    .font(.footnote).foregroundStyle(theme.theme.muted)
                Button("Continue to Today", action: continueToToday)
                    .buttonStyle(PrimaryButton()).disabled(busy)
                InlineError(message: error)
            }.padding(24).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink)
    }
    private func example(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.caption.bold()).foregroundStyle(theme.theme.muted)
            Text((try? AttributedString(markdown: text)) ?? AttributedString(text)).font(.title3)
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}
