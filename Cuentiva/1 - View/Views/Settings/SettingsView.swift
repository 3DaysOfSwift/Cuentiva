//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI
struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @Environment(ThemeManager.self) private var themeManager
    var body: some View {
        @Bindable var themeManager = themeManager
        List {
            if viewModel.isVIP {
                Section {
                    Label("VIP member", systemImage: "crown.fill")
                        .font(.headline).foregroundStyle(themeManager.theme.rewardGold)
                    Text("One hundred books and a world of curiosity. Welcome to your VIP corner.")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("The VIP workshop").font(.headline)
                        Text("A home for playful experiments, new ways to learn and little extras made with AI. Our first experiments are still being prepared.")
                            .foregroundStyle(themeManager.theme.muted)
                    }
                } header: {
                    Text("VIP")
                } footer: {
                    Text("Future experiments will be optional and may be unfinished. We’ll explain each one before you choose to try it. More VIP rewards are planned; none are available yet.")
                }.listRowBackground(themeManager.theme.surface)
            }
            Section("Appearance") {
                Picker("Colour theme", selection: $themeManager.selectedTheme) {
                    ForEach(themeManager.availableThemes) { theme in
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
            if !viewModel.themePacks.isEmpty {
                Section("Your gifts") {
                    ForEach(viewModel.themePacks) { pack in
                        Button { viewModel.showingThemePack = pack } label: {
                            HStack {
                                Label(pack.title, systemImage: viewModel.hasInstalled(pack) ? "checkmark.seal.fill" : "gift")
                                Spacer()
                                Text(viewModel.hasInstalled(pack) ? "Installed" : "Open gift").font(.caption)
                            }
                        }.foregroundStyle(themeManager.theme.accent)
                    }
                }.listRowBackground(themeManager.theme.surface)
            }
            Section("Subscription") {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    Link("Manage subscription", destination: url)
                }
            }.listRowBackground(themeManager.theme.surface)
            if viewModel.chatUnlocked {
                Section("Conversation") {
                    NavigationLink { ChatView() } label: {
                        Label("Storyteller Chat", systemImage: "bubble.left.and.bubble.right")
                    }
                    Text("Practise Spanish with your favourite characters. Earn one doubloon by completing a story, then spend it on one continuous topic chat.")
                        .font(.footnote).foregroundStyle(themeManager.theme.muted)
                }.listRowBackground(themeManager.theme.surface)
            }
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
            #if DEBUG
            Section("Developer testing") {
                Button(viewModel.verbTrainingPreview ? "Disable Verb Training preview" : "Enable Verb Training now") {
                    Task { await viewModel.toggleVerbTrainingPreview() }
                }.disabled(viewModel.changingVerbPreview)
                if viewModel.verbTrainingPreview {
                    NavigationLink("Open Verb Training") { VerbTrainingView() }
                }
                Text("Shows the Verbs tab immediately. Your practice days and earned gifts stay unchanged. This override is ignored in release builds.")
                    .font(.footnote).foregroundStyle(themeManager.theme.muted)
            }.listRowBackground(themeManager.theme.surface)
            #endif
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
            Section {
                if let url = viewModel.reviewURL {
                    Link(destination: url) {
                        Label("Write an App Store review", systemImage: "star.bubble")
                    }
                }
            } footer: {
                Text("Your review helps others discover Cuentiva, so we can help more people bring Spanish to life.")
            }.listRowBackground(themeManager.theme.surface)
            Section("Privacy") {
                Text("Your progress and drafts are stored on this device. Topic chats end when you leave the screen. Storyteller Chat uses on-device Apple Intelligence. Speech recognition is on-device where supported. Recordings are not saved. There are no analytics or advertising SDKs.")
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
            Section {
                NavigationLink { WhyCuentivaView() } label: {
                    Label("Why Cuentiva is unique", systemImage: "sparkles")
                }
            }.listRowBackground(themeManager.theme.surface)
        }.navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(themeManager.theme.paper)
            .foregroundStyle(themeManager.theme.ink)
            .tint(themeManager.theme.accent)
            .sheet(item: $viewModel.showingThemePack) { pack in
                ThemePackGiftView(pack: pack) { viewModel.showingThemePack = nil }
            }
            .confirmationDialog("Delete learning progress from this device?", isPresented: $viewModel.resetConfirmation, titleVisibility: .visible) { Button("Reset progress", role: .destructive) { Task { await viewModel.reset() } } }
    }
}
