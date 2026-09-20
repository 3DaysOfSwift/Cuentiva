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
                    HStack(spacing: 16) {
                        AuthorPortrait(author: model.author, size: 80)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Talk with \(model.author.name)").font(.system(.title2, design: .serif))
                            Text("A little Spanish. A conversation of your own.").font(.subheadline).foregroundStyle(theme.theme.muted)
                        }
                    }
                    DoubloonBalance(count: model.displayedCoins)
                    Text(model.sessionMessage).font(.subheadline).foregroundStyle(theme.theme.accent)
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
                    } else if model.unlocked && model.feature.sessionAuthorized && !model.admissionVisible {
                        Picker("Spanish level", selection: $model.level) {
                            ForEach(LearningLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.disabled(model.sending)
                        if model.messages.isEmpty && model.feature.unavailable == nil {
                            Text("Start a conversation").font(.system(.title2, design: .serif)).accessibilityAddTraits(.isHeader)
                            ForEach(["¡Hola! ¿Cómo estás?", "Vamos a explorar un bosque mágico.", "Quiero hablar de mis viajes."], id: \.self) { prompt in
                                Button(prompt) { model.draft = prompt; composing = true }
                            }
                        }
                        ForEach(model.messages) { turn in
                            ChatTurnView(turn: turn,
                                translated: model.translations.contains(turn.id),
                                translate: { model.toggleTranslation(for: turn) }, listen: { model.listen(turn) })
                                .id(turn.id)
                        }
                        if model.sending { ChatTypingIndicator(storyteller: model.author.name) }
                        if let turn = model.suggestedTurn {
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
                                    }.font(.subheadline.weight(.semibold)).buttonStyle(.bordered)
                                        .tint(theme.theme.accent).foregroundStyle(theme.theme.accent)
                                    if model.suggestionTranslations.contains(turn.id) {
                                        Text(english).foregroundStyle(theme.theme.muted).textSelection(.enabled)
                                    }
                                }
                            }.padding(.top, 24).padding(.bottom, 12)
                        }
                        Text("AI can make mistakes. This topic stays on your device while the screen is open. Your storyteller remembers a short summary and recent messages.")
                            .font(.caption).foregroundStyle(theme.theme.muted)
                    } else if !model.unlocked {
                        ChatPaywallView()
                    }
                    InlineError(message: model.preparationError)
                    InlineError(message: model.error)
                    InlineError(message: model.audioError)
                    Color.clear.frame(height: 1).id("chat-bottom")
                }.padding(23)
            }
            .scrollDismissesKeyboard(.interactively)
            .task {
                await model.prepare()
                if !model.messages.isEmpty { proxy.scrollTo("chat-bottom", anchor: .bottom) }
            }
            .onChange(of: model.messages.count) { _, _ in
                withAnimation { proxy.scrollTo("chat-bottom", anchor: .bottom) }
            }
            .safeAreaInset(edge: .bottom) {
                if model.canStart && model.admissionVisible {
                    ChatAdmissionView(coins: model.displayedCoins, celebrating: model.admissionCelebrating,
                        confirm: model.celebrateAdmission)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                } else if model.canStart && model.feature.sessionAuthorized {
                    ChatComposerView(draft: $model.draft, composing: $composing,
                        sending: model.sending, notice: model.composerNotice, canSend: model.canSend,
                        send: model.send, cancel: model.cancel)
                        .onAppear { composing = true }
                }
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.5, dampingFraction: 0.85),
            value: model.admissionPhase)
        .sensoryFeedback(.success, trigger: model.admissionSuccess)
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink).tint(theme.theme.accent)
        .navigationTitle(model.author.name).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundStyle(theme.theme.accent).accessibilityHidden(true)
                    Text(model.author.name)
                }.font(.headline).accessibilityAddTraits(.isHeader)
            }
            if model.unlocked && !model.messages.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New chat", systemImage: "square.and.pencil") { model.confirmingClear = true }
                        .disabled(model.feature.busy)
                }
            }
        }
        .confirmationDialog("Start a new topic? This ends the current session. The next topic costs 1 doubloon.", isPresented: $model.confirmingClear, titleVisibility: .visible) {
            Button("Start new topic", role: .destructive) { Task { await model.clear() } }
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
