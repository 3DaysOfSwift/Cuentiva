import SwiftUI
struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @Environment(ThemeManager.self) private var themeManager
    var body: some View {
        @Bindable var themeManager = themeManager
        List {
            Section("Appearance") {
                Picker("Colour theme", selection: $themeManager.selectedTheme) {
                    ForEach(ColourThemeID.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                Text("Your selected theme is used throughout Cuentiva.")
                    .font(.footnote).foregroundStyle(themeManager.theme.muted)
            }.listRowBackground(themeManager.theme.surface)
            Section("Language help") {
                NavigationLink { LanguageTermsView() } label: {
                    Label("Decipher language terms", systemImage: "text.book.closed")
                }
                Text("Nouns, verbs, lemmas and more—with examples in English and Spanish.").font(.footnote).foregroundStyle(themeManager.theme.muted)
            }.listRowBackground(themeManager.theme.surface)
            Section("Purchase") {
                Text("Cuentiva · One-time purchase")
                Button("Restore purchases") { Task { await viewModel.restore() } }
            }.listRowBackground(themeManager.theme.surface)
            Section("Your vocabulary") {
                if viewModel.words.isEmpty { Text("Words you practice will appear here.") }
                ForEach(viewModel.words, id: \.self) { word in
                    Picker(word, selection: Binding(get: { viewModel.state(word) }, set: { state in Task { await viewModel.set(word, state: state) } })) {
                        ForEach(VocabularyState.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                }
            }.listRowBackground(themeManager.theme.surface)
            Section("Privacy") {
                Text("Your progress and drafts are stored on this device. Speech recognition is on-device where supported. Recordings are not saved. There are no analytics or advertising SDKs.")
                Text("Device backups may include app data. Deleting the app removes its local data; purchases remain with your Apple Account.")
                Button("Reset learning progress", role: .destructive) { viewModel.resetConfirmation = true }
            }.listRowBackground(themeManager.theme.surface)
            Section { InlineError(message: viewModel.error) }.listRowBackground(themeManager.theme.surface)
        }.navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(themeManager.theme.paper)
            .foregroundStyle(themeManager.theme.ink)
            .confirmationDialog("Delete learning progress from this device?", isPresented: $viewModel.resetConfirmation, titleVisibility: .visible) { Button("Reset progress", role: .destructive) { Task { await viewModel.reset() } } }
    }
}
