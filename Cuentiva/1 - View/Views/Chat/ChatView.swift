import SwiftUI

struct ChatView: View {
    @State private var model: ChatViewModel
    @Environment(ThemeManager.self) private var theme
    @Environment(\.scenePhase) private var scenePhase
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
                    if !model.feature.ready {
                        if model.feature.preparing || model.preparationError == nil {
                            ProgressView("Preparing chat…")
                        } else {
                            Text("Chat couldn’t load. Your saved conversation hasn’t been changed.")
                            Button("Try again") { Task { await model.prepare() } }
                        }
                    } else if model.unlocked {
                        Picker("Spanish level", selection: $model.level) {
                            ForEach(LearningLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.disabled(model.sending)
                        if model.turns.isEmpty {
                            Text("Tell me about your day, plan a journey, or step into a world of talking dragons. You can write in Spanish or ask for help in English.")
                            ForEach(["¡Hola! ¿Cómo estás?", "Vamos a explorar un bosque mágico.", "Quiero hablar de mis viajes."], id: \.self) { prompt in
                                Button(prompt) { model.draft = prompt; composing = true }
                            }
                        }
                        ForEach(model.turns) { turn in
                            ChatTurnView(turn: turn, name: model.author.name,
                                translated: model.translations.contains(turn.id),
                                translate: { model.toggleTranslation(for: turn) }, listen: { model.listen(turn) })
                                .id(turn.id)
                        }
                        if model.sending { ProgressView("\(model.author.name) is thinking…") }
                        if let suggestion = model.turns.last?.suggestion, !suggestion.isEmpty {
                            Button { model.draft = suggestion; composing = true } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("You could say…").font(.caption)
                                    Text(suggestion)
                                }
                            }.disabled(model.sending)
                        }
                        Text("AI can make mistakes. Conversations stay on this device. Your storyteller remembers a short summary and recent messages.")
                            .font(.caption).foregroundStyle(theme.theme.muted)
                    } else {
                        ChatPaywallView(model: model)
                    }
                    if !model.unlocked {
                        Button(model.purchasing ? "Checking purchase…" : "Restore chat purchase") {
                            Task { await model.restore() }
                        }.disabled(model.purchasing)
                    }
                    if let unavailable = model.feature.unavailable {
                        Text(unavailable).foregroundStyle(theme.theme.muted)
                        Button("Check again") { Task { await model.prepare() } }
                            .disabled(model.feature.preparing || model.purchasing)
                    }
                    if let notice = model.notice { Text(notice).foregroundStyle(theme.theme.accent) }
                    InlineError(message: model.preparationError)
                    InlineError(message: model.error)
                    InlineError(message: model.audioError)
                    Color.clear.frame(height: 1).id("chat-bottom")
                }.padding(23)
            }
            .scrollDismissesKeyboard(.interactively)
            .task {
                await model.prepare()
                if !model.turns.isEmpty { proxy.scrollTo("chat-bottom", anchor: .bottom) }
            }
            .onChange(of: model.turns.count) { _, _ in
                withAnimation { proxy.scrollTo("chat-bottom", anchor: .bottom) }
            }
            .safeAreaInset(edge: .bottom) {
                if model.unlocked && model.feature.ready {
                    ChatComposerView(draft: $model.draft, composing: $composing,
                        sending: model.sending, canSend: model.canSend,
                        send: model.send, cancel: model.cancel)
                }
            }
        }
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink).tint(theme.theme.accent)
        .navigationTitle("Storyteller Chat").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.unlocked && !model.turns.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New chat", systemImage: "square.and.pencil") { model.confirmingClear = true }
                        .disabled(model.feature.busy)
                }
            }
        }
        .confirmationDialog("Delete this conversation and start again?", isPresented: $model.confirmingClear, titleVisibility: .visible) {
            Button("Delete conversation", role: .destructive) { Task { await model.clear() } }
        }
        .onDisappear { model.cancel() }
        .onChange(of: model.unlocked) { _, access in if !access { model.cancel() } }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.cancel() }
            else { Task { await model.prepare() } }
        }
    }
}
