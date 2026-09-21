//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct VocabularyView: View {
    @State private var model = VocabularyViewModel()
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        List {
            Section("Your learning level") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                    ForEach(LearningLevel.allCases, id: \.self) { level in
                        Button { Task { await model.select(level) } } label: {
                            HStack(spacing: 4) {
                                Text(level.rawValue).font(.headline)
                                if model.selectedLevel == level { Image(systemName: "checkmark").font(.caption.bold()) }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(model.selectedLevel == level ? theme.theme.onAccent : theme.theme.accent)
                            .background(model.selectedLevel == level ? theme.theme.accent : theme.theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain).disabled(model.saving)
                        .accessibilityLabel("\(level.rawValue) learning level")
                        .accessibilityAddTraits(model.selectedLevel == level ? .isSelected : [])
                    }
                }.padding(.vertical, 6)
                Text("A1–A2: beginner · B1–B2: intermediate · C1–C2: advanced")
                    .font(.footnote).foregroundStyle(theme.theme.muted)
                Text("Choose the level you feel comfortable studying. This is your own estimate, not a test result. Changing it won’t mark words as known or change your completed books.")
                    .font(.footnote).foregroundStyle(theme.theme.muted)
                if model.selectedLevel != nil {
                    Button("Clear my level") { Task { await model.select(nil) } }.disabled(model.saving)
                }
            }.listRowBackground(theme.theme.surface)
            if let error = model.error {
                Section { InlineError(message: error) }.listRowBackground(theme.theme.surface)
            }
            Section("Your words · \(model.total)") {
                if model.total == 0 {
                    Text("Words you meet while reading will appear here. You can mark each one as unknown, learning or known.")
                        .foregroundStyle(theme.theme.muted)
                } else if model.words.isEmpty {
                    ContentUnavailableView.search(text: model.query)
                }
                ForEach(model.words, id: \.self) { word in
                    Picker(word, selection: Binding(get: { model.state(word) }, set: { state in Task { await model.set(word, state: state) } })) {
                        ForEach(VocabularyState.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    .tint(theme.theme.accent).id(theme.selectedTheme).disabled(model.saving)
                }
            }.listRowBackground(theme.theme.surface)
        }
        .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Find a Spanish word")
        .navigationTitle("Your vocabulary").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(theme.theme.paper)
        .foregroundStyle(theme.theme.ink).tint(theme.theme.accent)
    }
}
