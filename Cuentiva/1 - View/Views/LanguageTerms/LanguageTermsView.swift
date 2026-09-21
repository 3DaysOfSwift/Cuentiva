//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct LanguageTermsView: View {
    @State private var model = LanguageTermsViewModel()
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        List {
            Section {
                Text("Small explanations. Clearer Spanish.").font(.system(.title2, design: .serif))
                Text("You don’t need to know the grammar vocabulary before you begin. Choose a term and see it in action.").foregroundStyle(theme.theme.muted)
            }.listRowBackground(theme.theme.surface)
            Section("English · Español") {
                ForEach(model.terms) { term in
                    NavigationLink { LanguageTermDetailView(id: term.id) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(term.english).font(.headline)
                            Text(term.spanish).foregroundStyle(theme.theme.muted)
                        }.padding(.vertical, 4)
                    }
                }
                if model.terms.isEmpty { ContentUnavailableView.search(text: model.query) }
            }.listRowBackground(theme.theme.surface)
        }
        .searchable(text: $model.query, prompt: "Find an English or Spanish term")
        .navigationTitle("Decipher language terms").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(theme.theme.paper).foregroundStyle(theme.theme.ink)
    }
}
