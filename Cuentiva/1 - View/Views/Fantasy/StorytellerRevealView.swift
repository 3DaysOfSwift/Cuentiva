import SwiftUI

struct StorytellerRevealView: View {
    @State private var model: StorytellerRevealViewModel
    @FocusState private var editingDetails: Bool
    @State private var operation: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeManager.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onContinue: () -> Void

    init(feature: any FantasyFeature, onContinue: @escaping () -> Void) {
        _model = State(initialValue: StorytellerRevealViewModel(feature: feature))
        self.onContinue = onContinue
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(model.stage == .identity ? "Meet your storyteller" : "Reveal your spirit animal")
                    .font(.system(.largeTitle, design: .serif))
                if [.spinning, .slowing, .number].contains(model.stage) {
                    Text("\(model.number)")
                        .font(.system(size: 92, weight: .medium, design: .serif)).monospacedDigit()
                        .scaleEffect(model.stage == .number ? 1.35 : 1)
                        .frame(height: 210)
                        .accessibilityLabel("Your creature is waiting to be revealed")
                    Text("A little chance. A whole new character.").foregroundStyle(theme.theme.muted)
                    Button(model.busy ? "Finding your creature…" : "Choose my creature") {
                        operation = Task { await model.choose() }
                    }.buttonStyle(PrimaryButton()).disabled(model.busy || !model.ready)
                } else {
                    if let creature = model.creature {
                        Image(creature.portrait).resizable().scaledToFill()
                            .frame(width: 190, height: 190).clipShape(Circle())
                            .overlay { Circle().strokeBorder(theme.theme.accent.opacity(0.18), lineWidth: 1) }
                            .accessibilityLabel(creature.title)
                    }
                    if model.stage == .creature {
                        Text("You’re a \(model.creature?.title.lowercased() ?? "storyteller")!").font(.title2)
                        Button("Give my storyteller a voice") { model.editDetails() }.buttonStyle(PrimaryButton())
                    } else if model.stage == .details {
                        Text("Save your name and bio on this device. When Apple Intelligence is available, it can turn them into a fantasy name and biography.").foregroundStyle(theme.theme.muted)
                        TextField("Your name", text: $model.name).textContentType(.givenName).focused($editingDetails)
                            .padding().background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 12))
                        TextField("A short bio: your adventures, interests and dreams", text: $model.biography, axis: .vertical)
                            .focused($editingDetails).lineLimit(3...6).padding().background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 12))
                        Button("Save name and bio") {
                            editingDetails = false
                            operation = Task { await model.saveDetails() }
                        }.buttonStyle(PrimaryButton()).disabled(!model.canSaveDetails)
                        if let message = model.savedMessage {
                            Text(message).font(.footnote).foregroundStyle(theme.theme.accent)
                        }
                        Button(model.busy ? "Dreaming up your storyteller…" : "Reveal my storyteller") {
                            editingDetails = false
                            operation = Task { await model.generateIdentity() }
                        }.buttonStyle(.bordered).disabled(model.busy || model.availabilityMessage != nil || model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.biography.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else if let identity = model.identity {
                        Text(identity.name).font(.system(.largeTitle, design: .serif)).transition(.scale.combined(with: .opacity))
                        Text(identity.biography)
                        Button("Edit my name and bio") { model.editDetails() }
                        Button("Begin my next chapter") {
                            operation = Task { if await model.finish() { onContinue() } }
                        }.buttonStyle(PrimaryButton())
                    }
                }
                if let message = model.availabilityMessage {
                    Text(message).font(.footnote).foregroundStyle(theme.theme.muted)
                    Button("Check again") { Task { await model.refreshAvailability() } }
                }
                InlineError(message: model.error)
                if !model.ready, model.error != nil {
                    Button("Retry loading my storyteller") { Task { await model.prepare() } }
                }
                if model.stage != .identity {
                    Button("Continue to the library for now") {
                        operation = Task { if await model.finish() { onContinue() } }
                    }.font(.footnote).disabled(model.busy)
                }
            }.multilineTextAlignment(.center).padding(26)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink)
        .animation(reduceMotion ? nil : .spring(duration: 0.45), value: model.stage)
        .overlay {
            if let start = model.confettiStart, !reduceMotion {
                ConfettiBurst(start: start).allowsHitTesting(false).accessibilityHidden(true)
                    .task(id: start) {
                        try? await Task.sleep(for: .seconds(ConfettiBurst.duration))
                        if model.confettiStart == start { model.confettiStart = nil }
                    }
            }
        }
        .task { await model.prepare() }
        .task(id: model.stage == .spinning) {
            if model.stage == .spinning, !reduceMotion { await model.animateNumbers() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refreshAvailability() } }
        }
        .onDisappear { operation?.cancel() }
    }
}
