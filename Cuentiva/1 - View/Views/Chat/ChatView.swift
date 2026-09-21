//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct ChatView: View {
    @State private var model: ChatViewModel
    @Environment(ThemeManager.self) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var composing: Bool
    init(author: Author = Author.demoProfiles[0]) {
        let app = AppModel.shared
        _model = State(initialValue: ChatViewModel(author: author.storyteller, feature: app.chat,
            audio: app.makeAudio(), level: app.progress.snapshot.selectedLearningLevel?.rawValue ?? "A2"))
    }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ChatIntroductionView(locked: !model.feature.sessionAuthorized)
                    if let unavailable = model.feature.unavailable {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("On-device chat unavailable", systemImage: "iphone.slash")
                                .font(.headline)
                            Text(unavailable)
                            Button("Check again") { Task { await model.prepare() } }
                                .disabled(model.feature.preparing)
                        }.padding().frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 18))
                    }
                    if !model.feature.ready {
                        if model.feature.preparing || model.preparationError == nil {
                            ProgressView("Preparing chat…")
                        } else {
                            Text("Chat couldn’t load. Please try again.")
                            Button("Try again") { Task { await model.prepare() } }
                        }
                    } else {
                        ForEach(model.messages) { turn in
                            ChatTurnView(turn: turn, spokenRange: model.spokenRange(for: turn),
                                translated: model.translations.contains(turn.id),
                                translate: { model.toggleTranslation(for: turn) }, listen: { model.listen(turn) })
                                .id(turn.id)
                        }
                        if model.sending { ChatTypingIndicator(storyteller: model.author.name) }
                        if model.feature.sessionAuthorized, !model.admissionVisible, model.draft.isEmpty, !model.sending, let turn = model.suggestedTurn {
                            VStack(alignment: .leading, spacing: 14) {
                                Button { model.draft = turn.suggestion; composing = true } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("You could say…").font(.caption).foregroundStyle(theme.theme.muted)
                                        Text(turn.suggestion).foregroundStyle(theme.theme.ink)
                                    }.multilineTextAlignment(.leading)
                                }.buttonStyle(.plain).disabled(model.sending)
                                    .accessibilityHint("Use this suggested reply")
                                if let english = turn.suggestionEnglish, !english.isEmpty {
                                    Button(model.suggestionTranslations.contains(turn.id) ? "Hide English" : "Show English") {
                                        model.toggleSuggestionTranslation(turn)
                                    }.font(.subheadline.weight(.semibold)).buttonStyle(.plain)
                                        .tint(theme.theme.accent).foregroundStyle(theme.theme.accent)
                                    if model.suggestionTranslations.contains(turn.id) {
                                        Text(english).foregroundStyle(theme.theme.muted).textSelection(.enabled)
                                    }
                                }
                            }.padding(.top, 24).padding(.bottom, 12)
                        }
                        if !model.unlocked && !model.canPresentAdmission { ChatPaywallView() }
                    }
                    InlineError(message: model.preparationError)
                    InlineError(message: model.error)
                    InlineError(message: model.audioError)
                    Color.clear.frame(height: 1).id("chat-bottom")
                }.padding(23)
            }
            .background { ChatWallpaperView() }
            .scrollDismissesKeyboard(.interactively)
            .task { await model.prepare() }
            .onChange(of: model.messages.last(where: { $0.role == .learner })?.id) { _, messageID in
                guard let messageID else { return }
                // Only the reader sending a new message moves the viewport.
                // Incoming reply bubbles and suggestions leave their reading position alone.
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    proxy.scrollTo(messageID, anchor: .top)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if model.canPresentAdmission && model.admissionVisible {
                    ChatAdmissionView(coins: model.displayedCoins, celebrating: model.admissionCelebrating,
                        continuing: !model.messages.isEmpty,
                        confirm: model.celebrateAdmission)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                } else if model.canStart && model.feature.sessionAuthorized {
                    ChatComposerView(draft: $model.draft, composing: $composing,
                        notice: model.composerNotice, canSend: model.canSend,
                        send: model.send)
                        .onAppear { composing = true }
                }
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.5, dampingFraction: 0.85),
            value: model.admissionPhase)
        .sensoryFeedback(.success, trigger: model.admissionSuccess)
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink).tint(theme.theme.accent)
        .toolbarBackground(theme.theme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationTitle(model.author.name).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    AuthorPortrait(author: model.author, size: 32).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.author.name).font(.headline).lineLimit(1)
                        Text("AI storyteller").font(.caption2).foregroundStyle(theme.theme.muted)
                    }
                }.accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
            }
            if model.unlocked {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Spanish level", selection: $model.level) {
                            ForEach(LearningLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.disabled(model.sending)
                        if !model.messages.isEmpty {
                            Divider()
                            Button("New chat", systemImage: "square.and.pencil") { model.confirmingClear = true }
                                .disabled(model.feature.busy)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(model.level.rawValue)
                            Image(systemName: "chevron.down").font(.caption2)
                        }
                    }.accessibilityLabel("Spanish level, \(model.level.rawValue). Chat options")
                }
            }
        }
        .confirmationDialog("Start a new topic? This clears this saved conversation and its remaining allowance. The next topic costs 1 doubloon.", isPresented: $model.confirmingClear, titleVisibility: .visible) {
            Button("Start new topic", role: .destructive) { Task { await model.clear() } }
        }
        .onChange(of: model.feature.sessionAuthorized) { _, authorized in
            if !authorized { composing = false; model.resetAdmission() }
        }
        .onDisappear { composing = false; model.endSession() }
        .onChange(of: model.unlocked) { _, access in if !access { model.cancel() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { composing = false; model.endSession() }
            else if phase != .active { model.cancel() }
            else { Task { await model.prepare() } }
        }
    }
}
