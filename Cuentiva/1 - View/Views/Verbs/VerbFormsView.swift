//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct VerbFormsView: View {
    let verb: TrainingVerb
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    private let labels = ["yo", "tú", "él / ella / usted", "nosotros / nosotras", "vosotros / vosotras", "ellos / ellas / ustedes"]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("\(verb.id) · \(verb.english)").font(.largeTitle.bold())
                Text("One verb, different people and moments.").font(.title3)
                Text("Tú is informal ‘you’. Usted is polite ‘you’ and uses the él/ella form. Ustedes is plural ‘you’ throughout Latin America; vosotros is informal plural ‘you’ in Spain. Vos forms are not included.")
                    .foregroundStyle(theme.theme.muted)
                Text("Infinitive: \(verb.id)\nParticiple: \(verb.participle)\nGerund: \(verb.reflexive ? "portándose" : verb.gerund)")
                Text("A participle helps say ‘have done’; a gerund helps say ‘is doing’. These tables cover common modern forms, not rare historical tenses.")
                    .font(.footnote).foregroundStyle(theme.theme.muted)
                ForEach(VerbTime.allCases) { time in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(time.title).font(.title2.bold())
                        Text(time.help).foregroundStyle(theme.theme.muted)
                        ForEach(0..<6, id: \.self) { slot in
                            HStack(alignment: .firstTextBaseline) {
                                Text(labels[slot]).font(.subheadline).foregroundStyle(theme.theme.muted)
                                Spacer(minLength: 12)
                                Text(verb.form(time, slot: slot) ?? "—").font(.title3.weight(.semibold))
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }.padding(20).background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 20))
                }
            }.padding(24)
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink)
            .navigationTitle("Verb forms").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
    }
}
