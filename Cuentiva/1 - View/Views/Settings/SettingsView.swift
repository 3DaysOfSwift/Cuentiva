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
                .tint(themeManager.theme.accent)
                // Recreate the native menu when its palette changes; reused controls
                // can otherwise retain the previous theme's selected-value tint.
                .id(themeManager.selectedTheme)
                Text("Your selected theme is used throughout Cuentiva.")
                    .font(.footnote).foregroundStyle(themeManager.theme.muted)
            }.listRowBackground(themeManager.theme.surface)
            Section("Conversation") {
                NavigationLink { ChatView() } label: {
                    Label("Storyteller Chat", systemImage: "bubble.left.and.bubble.right")
                }
                Text("Practise Spanish with your favourite characters. A separate one-time purchase.")
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
                if viewModel.hasAccess {
                    Label("Lifetime access active", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(themeManager.theme.accent)
                }
                Button { Task { await viewModel.restore() } } label: {
                    HStack {
                        Text(viewModel.restoring ? "Checking purchases…" : "Restore purchases")
                        Spacer()
                        if viewModel.restoring { ProgressView() }
                    }
                }
                .foregroundStyle(themeManager.theme.accent)
                .disabled(viewModel.restoring)
                if let message = viewModel.restoreMessage {
                    Label(message, systemImage: "checkmark.circle")
                        .font(.footnote).foregroundStyle(themeManager.theme.accent)
                }
                InlineError(message: viewModel.restoreError)
            }.listRowBackground(themeManager.theme.surface)
            Section("Your learning") {
                NavigationLink { VocabularyView() } label: {
                    Label("Your vocabulary", systemImage: "character.book.closed")
                }
                Text("Search your words, update what you know and choose your learning level.")
                    .font(.footnote).foregroundStyle(themeManager.theme.muted)
            }.listRowBackground(themeManager.theme.surface)
            Section("Community library") {
                Button { Task { await viewModel.syncLibrary() } } label: {
                    HStack { Text(viewModel.syncing ? "Updating library…" : "Update library"); Spacer(); if viewModel.syncing { ProgressView() } }
                }.disabled(viewModel.syncing).foregroundStyle(themeManager.theme.accent)
                if let message = viewModel.syncMessage { Text(message).font(.footnote).foregroundStyle(themeManager.theme.muted) }
            }.listRowBackground(themeManager.theme.surface)
            Section("Privacy") {
                Text("Your progress, drafts and chat conversations are stored on this device. Storyteller Chat uses on-device Apple Intelligence. Speech recognition is on-device where supported. Recordings are not saved. There are no analytics or advertising SDKs.")
                Text("Device backups may include app data. Deleting the app removes its local data; purchases remain with your Apple Account.")
                Button("Reset learning progress", role: .destructive) { viewModel.resetConfirmation = true }
            }.listRowBackground(themeManager.theme.surface)
            Section {
                if viewModel.error != nil { InlineError(message: viewModel.error) }
            } footer: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("A little story behind the name")
                        .font(.headline).foregroundStyle(themeManager.theme.ink)
                    Text("Cuento means “story” or “tale” in Spanish. Viva means “alive” or “living.” Our name, Cuentiva, playfully brings those ideas together.")
                    Text("Cuentiva — a community bringing Spanish to life through stories.")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(themeManager.theme.accent)
                }
                .font(.footnote)
                .foregroundStyle(themeManager.theme.muted)
                .textCase(nil)
                .padding(.vertical, 20)
            }.listRowBackground(themeManager.theme.surface)
        }.navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(themeManager.theme.paper)
            .foregroundStyle(themeManager.theme.ink)
            .tint(themeManager.theme.accent)
            .confirmationDialog("Delete learning progress from this device?", isPresented: $viewModel.resetConfirmation, titleVisibility: .visible) { Button("Reset progress", role: .destructive) { Task { await viewModel.reset() } } }
    }
}
