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
                Text(model.stage == .details ? "Your storyteller" : "Your storyteller")
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
                        Text("Make Cuentiva yours. Let your storyteller welcome you from your Home Screen.").foregroundStyle(theme.theme.muted)
                    } else if model.stage == .details {
                        Text("Your character is chosen. Make this name and biography your own, or keep them just as they are.").foregroundStyle(theme.theme.muted)
                        TextField("Storyteller name", text: $model.name).focused($editingDetails)
                            .padding().background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 12))
                        Text("One short name, up to 24 letters.").font(.caption).foregroundStyle(theme.theme.muted)
                        TextField("Storyteller biography", text: $model.biography, axis: .vertical)
                            .focused($editingDetails).lineLimit(4...8).padding().background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                if let message = model.iconMessage { Text(message).font(.footnote) }
                InlineError(message: model.error)
                if !model.ready, model.error != nil {
                    Button("Retry loading my storyteller") { Task { await model.prepare() } }
                }
                if model.stage != .details && model.stage != .creature {
                    Button("Continue to the library for now") {
                        operation = Task { if await model.finish() { onContinue() } }
                    }.font(.footnote).disabled(model.busy)
                }
            }.multilineTextAlignment(.center).padding(26)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.stage == .creature || model.stage == .details {
                VStack(spacing: 10) {
                    if model.stage == .creature {
                        if model.canOfferIcon {
                            Button(model.changingIcon ? "Changing icon…" : "Use my storyteller as the app icon") {
                                operation = Task { await model.chooseIconAndEdit() }
                            }.buttonStyle(PrimaryButton()).disabled(model.changingIcon || model.busy)
                            Button("Keep Pipa and continue") { model.editDetails() }
                                .font(.footnote).disabled(model.changingIcon || model.busy)
                        } else {
                            Button("Name my storyteller") { model.editDetails() }.buttonStyle(PrimaryButton())
                        }
                    } else {
                        Button(model.busy ? "Saving…" : "Save my storyteller") {
                            editingDetails = false
                            operation = Task {
                                await model.saveDetails()
                                if model.savedMessage != nil { onContinue() }
                            }
                        }.buttonStyle(PrimaryButton()).disabled(!model.canSaveDetails)
                    }
                }.padding(.horizontal, 26).padding(.vertical, 12)
                    .background(theme.theme.paper).dockedAreaBorder()
            }
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
