import SwiftUI

struct StoryParagraphRow: View {
    let sentence: Sentence
    let spokenRange: NSRange?
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(sentence.english)
                .font(.subheadline).foregroundStyle(theme.theme.muted)
                .environment(\.locale, Locale(identifier: "en-GB"))
            spanish.font(.system(.title3, design: .serif)).lineSpacing(5)
                .environment(\.locale, Locale(identifier: "es-ES"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
    private var spanish: Text {
        var value = AttributedString(sentence.spanish)
        if let spokenRange, let range = Range(spokenRange, in: value) {
            value[range].foregroundColor = theme.theme.accent
            value[range].font = .system(.title3, design: .serif, weight: .bold)
        }
        return Text(value)
    }
}
