import SwiftUI

struct VerbTrainingView: View {
    @State private var model: VerbTrainingViewModel
    @Environment(ThemeManager.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(model: VerbTrainingViewModel = VerbTrainingViewModel()) { _model = State(initialValue: model) }
    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if !model.eligible {
                        Label("A gift for day 20", systemImage: "gift.fill").font(.largeTitle)
                        Text("Practise on 20 different days to unlock Verb Training.")
                        Text("\(model.days) of 20 practice days")
                    } else if !model.claimed || model.giftCelebrated {
                        gift
                    } else {
                        Text(model.state.workoutTitle).font(.system(.largeTitle, design: .serif))
                        Text(model.state.isFocused ? "12 quick reps. One verb, one tense. Repeat the same form, then change the subject." : "12 reps. Build each sentence, explore its verbs, then move to the next.")
                            .foregroundStyle(theme.theme.muted)
                        if let phrase = model.state.phrase {
                            VStack(alignment: .leading, spacing: 18) {
                                HStack {
                                    Text("Rep \(model.state.rep) of 12").font(.headline)
                                    Spacer()
                                    Text("\(model.state.total) constructed").font(.caption).monospacedDigit()
                                }
                                ProgressView(value: Double(model.state.rep - (model.state.finished ? 0 : 1)), total: 12)
                                Text(phrase.english).font(.title2.bold())
                            }.id("current-rep")
                            if model.state.finished {
                                VerbSolutionView(phrase: phrase, showsCharts: !model.state.isFocused || model.state.setComplete)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                if model.state.setComplete {
                                    Label("12 reps complete. Nice work!", systemImage: "checkmark.seal.fill").font(.title2.bold())
                                }
                                Button(model.state.setComplete ? "Reset 12 reps" : "Next rep") {
                                    Task { await model.next() }
                                }.buttonStyle(PrimaryButton()).disabled(model.busy)
                            } else {
                                Text(model.state.built.isEmpty ? "Tap your first word…" : model.state.built)
                                    .font(.system(.title, design: .serif)).frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                                    .padding(18).background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 18))
                                Text(model.state.isFocused ? "Build the short phrase. Watch the verb ending." : "All the words you need are here, with an equal number of distractors.")
                                    .font(.footnote).foregroundStyle(theme.theme.muted)
                                WordTileLayout(spacing: 12) {
                                    ForEach(Array(model.state.cloud.enumerated()), id: \.offset) { index, word in
                                        Button { Task { await model.choose(word) } } label: {
                                            Text(word).fixedSize(horizontal: false, vertical: true)
                                        }
                                            .font(.title3.weight(.medium)).frame(minHeight: 44)
                                            .buttonStyle(.bordered)
                                            .disabled(model.busy || model.state.usedTiles?.contains(index) == true)
                                            .opacity(model.state.usedTiles?.contains(index) == true ? 0.3 : 1)
                                    }
                                }
                            }
                            if let feedback = model.feedback { Text(feedback).foregroundStyle(theme.theme.accent) }
                        } else if model.busy { ProgressView() }
                        else { Button("Start workout") { Task { await model.prepare() } }.buttonStyle(PrimaryButton()) }
                        if !model.trail.isEmpty {
                            Divider()
                            Text("Your sentence trail").font(.title2.bold())
                            ForEach(Array(model.trail.enumerated()), id: \.offset) { _, id in
                                if let phrase = VerbCatalogue.phrase(id: id) { VerbSolutionView(phrase: phrase, showsCharts: !phrase.id.hasPrefix("focus/")) }
                            }
                        }
                    }
                    InlineError(message: model.error)
                }.padding(24)
            }
            .onChange(of: model.state.roundID) { _, _ in
                if !reduceMotion { withAnimation { reader.scrollTo("current-rep", anchor: .top) } }
                else { reader.scrollTo("current-rep", anchor: .top) }
            }
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink).tint(theme.theme.accent)
            .navigationTitle("Verb Training").navigationBarTitleDisplayMode(.inline)
            .task { await model.prepare() }
            .sensoryFeedback(.success, trigger: model.giftCelebrated)
            .sensoryFeedback(.success, trigger: model.state.total)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: model.state.finished)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: model.giftCelebrated)
    }
    private var gift: some View {
        VStack(spacing: 24) {
            Image(systemName: model.giftCelebrated ? "checkmark.seal.fill" : "gift.fill")
                .font(.system(size: 90)).foregroundStyle(theme.theme.accent)
                .symbolEffect(.bounce, options: .nonRepeating, isActive: model.giftCelebrated && !reduceMotion)
            Text(model.giftCelebrated ? "Your words, in every time." : "Twenty days. A new way to speak.")
                .font(.system(.largeTitle, design: .serif))
            Text("Your Verb Training gift includes 29 everyday verbs, past and future practice, and a word cloud that keeps going. It’s yours to revisit, even if your streak ends.")
                .foregroundStyle(theme.theme.muted)
            if model.giftCelebrated {
                Button("Start workout") { Task { await model.enterGift() } }.buttonStyle(PrimaryButton())
            } else {
                Button("Open my gift") { Task { await model.openGift() } }
                    .buttonStyle(PrimaryButton()).disabled(model.busy)
            }
        }.multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}
