import SwiftUI

struct ScriptDialogueRow: View {
    let sentence: Sentence
    let onRight: Bool
    let spokenRange: NSRange?
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack {
            if onRight { Spacer(minLength: typeSize.isAccessibilitySize ? 12 : 40) }
            VStack(alignment: onRight ? .trailing : .leading, spacing: 9) {
                Text(sentence.speaker ?? "").font(.caption.weight(.semibold)).foregroundStyle(theme.theme.accent)
                Text(sentence.english).font(.subheadline).foregroundStyle(theme.theme.muted)
                    .environment(\.locale, Locale(identifier: "en-GB"))
                spanish.font(.system(.title3, design: .serif)).lineSpacing(5)
                    .environment(\.locale, Locale(identifier: "es-ES"))
            }
            .multilineTextAlignment(onRight ? .trailing : .leading)
            .frame(maxWidth: .infinity, alignment: onRight ? .trailing : .leading)
            .accessibilityElement(children: .combine)
            if !onRight { Spacer(minLength: typeSize.isAccessibilitySize ? 12 : 40) }
        }
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
