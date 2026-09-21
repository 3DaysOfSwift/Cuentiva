//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct LanguageTermDetailView: View {
    @State private var model: LanguageTermDetailViewModel
    @Environment(ThemeManager.self) private var theme
    init(id: String) { _model = State(initialValue: LanguageTermDetailViewModel(id: id)) }
    var body: some View {
        ScrollView {
            if let term = model.term {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(term.english).font(.system(.largeTitle, design: .serif))
                        Text(term.spanish).font(.title3).foregroundStyle(theme.theme.accent)
                    }
                    Text(term.meaning).font(.title3.weight(.medium))
                    Text((try? AttributedString(markdown: term.explanation, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(term.explanation))
                    example("IN ENGLISH", text: term.englishExample)
                    example("IN SPANISH", text: term.spanishExample)
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Something to notice", systemImage: "lightbulb") .font(.headline)
                        Text(term.takeaway)
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    if !model.related.isEmpty {
                        Text("EXPLORE RELATED TERMS").font(.caption.bold()).foregroundStyle(theme.theme.muted)
                        ForEach(model.related) { related in
                            NavigationLink { LanguageTermDetailView(id: related.id) } label: {
                                HStack { Text("\(related.english) · \(related.spanish)"); Spacer(); Image(systemName: "chevron.right") }
                            }.padding(.vertical, 8)
                        }
                    }
                }.padding(24).frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            } else { ContentUnavailableView("Term unavailable", systemImage: "text.book.closed") }
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink)
            .navigationTitle(model.term?.english ?? "Language term").navigationBarTitleDisplayMode(.inline)
    }
    private func example(_ heading: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(heading).font(.caption.bold()).foregroundStyle(theme.theme.muted)
            Text((try? AttributedString(markdown: text)) ?? AttributedString(text)).font(.title3)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}
