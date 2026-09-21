//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct VerbSolutionView: View {
    let phrase: VerbPhrase
    var showsCharts = true
    @Environment(ThemeManager.self) private var theme
    private let labels = ["yo", "tú", "él / ella / usted", "nosotros / nosotras", "vosotros / vosotras", "ellos / ellas / ustedes"]
    private var highlighted: AttributedString {
        var text = AttributedString()
        for (index, word) in phrase.words.enumerated() {
            var token = AttributedString(word + (index == phrase.words.count - 1 ? "" : " "))
            if let use = phrase.verbUses.first(where: { $0.indices.contains(index) }) {
                token.foregroundColor = use.baseForm ? theme.theme.rewardGold : theme.theme.accent
                token.font = .system(.title3, design: .serif, weight: .bold)
                token.underlineStyle = .single
            }
            text.append(token)
        }
        return text
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(highlighted).font(.system(.title3, design: .serif))
            Text(phrase.english).foregroundStyle(theme.theme.muted)
            if showsCharts {
            Text(phrase.note).font(.footnote).foregroundStyle(theme.theme.muted)
            ForEach(phrase.usedVerbs, id: \.self) { lemma in
                let uses = phrase.verbUses.filter { $0.lemma == lemma }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Base verb · \(lemma)").font(.title3.bold()).foregroundStyle(theme.theme.rewardGold)
                    Text("Used here · " + uses.map { $0.text(in: phrase) }.joined(separator: " / "))
                        .font(.headline).foregroundStyle(theme.theme.accent)
                    ForEach(uses.filter { $0.explanation != nil }) { use in
                        if let explanation = use.explanation { Text(explanation).font(.footnote).foregroundStyle(theme.theme.muted) }
                    }
                    ForEach(Array(Set(uses.map(\.time))).sorted { $0.rawValue < $1.rawValue }) { time in
                        if let use = uses.first(where: { $0.time == time }) {
                            Text(time.title).font(.subheadline.bold())
                            ForEach(Array(use.forms().enumerated()), id: \.offset) { slot, form in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(labels[slot]).foregroundStyle(theme.theme.muted)
                                    Spacer(minLength: 12)
                                    Text(form).fontWeight(.semibold).multilineTextAlignment(.trailing)
                                }.font(.subheadline)
                            }
                        }
                    }
                }.padding(18).background(theme.theme.paper, in: RoundedRectangle(cornerRadius: 18))
            }
            }
        }.padding(18).background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 22))
    }
}
