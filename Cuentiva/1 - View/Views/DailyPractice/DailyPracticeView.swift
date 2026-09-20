import SwiftUI

struct DailyPracticeView: View {
    @State private var model: DailyPracticeViewModel
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(books: [Book], feature: any DailyPracticeFeature) {
        _model = State(initialValue: DailyPracticeViewModel(books: books, feature: feature))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let session = model.displayedSession {
                    if let game = model.selected {
                        if session.completed.contains(game) {
                            result(session, game: game)
                        } else {
                            if game != .sentenceBuilder {
                                Text(game.title).font(.largeTitle.bold())
                            }
                            exercise(session, game: game)
                        }
                    } else {
                        DailyPracticeOverview(session: session, select: model.select)
                    }
                } else if model.busy { ProgressView("Preparing practice…") }
                else { Button("Prepare today’s practice") { Task { await model.prepare() } } }
                if let feedback = model.feedback { Text(feedback).foregroundStyle(theme.theme.accent) }
                InlineError(message: model.error)
            }.padding(24)
        }
        .disabled(model.celebrationID != nil)
        .overlay {
            if model.celebrationID != nil {
                VStack(spacing: 24) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 110))
                        .foregroundStyle(theme.theme.accent)
                        .symbolEffect(.bounce, options: .nonRepeating, isActive: !reduceMotion)
                    Text("Round completed").font(.largeTitle.bold())
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.theme.paper)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
                .accessibilityElement(children: .combine)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.celebrationID)
        .task(id: model.celebrationID) { await model.celebrateRound() }
        .sensoryFeedback(.success, trigger: model.celebrationID)
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink).tint(theme.theme.accent)
        .navigationTitle("Daily practice").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if model.selected != nil {
                    Text("\(model.completedRounds)")
                        .font(.headline).monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.25), value: model.completedRounds)
                        .accessibilityLabel("\(model.completedRounds) rounds completed")
                }
            }
            ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
        }
        .task { await model.prepare() }
        .sensoryFeedback(.success, trigger: model.session?.rewarded ?? false)
    }
    @ViewBuilder private func exercise(_ session: DailyPracticeSession, game: DailyPracticeGame) -> some View {
        switch game {
        case .missingWord:
            Text("Sentence \(session.missingIndex + 1) of \(session.rounds)").font(.caption)
            Text(session.missingPhrase.english).font(.title3)
            Text(session.missingPhrase.words.enumerated().map { index, word in
                index == session.missingPosition ? String(repeating: "_", count: min(word.count, 12)) : word
            }.joined(separator: " ")).font(.title).padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 18))
            Text("Choose the word used in the book.").foregroundStyle(theme.theme.muted)
            tiles(session.missingOptions)
            Text(session.missingPhrase.source).font(.caption).foregroundStyle(theme.theme.muted)
        case .sentenceBuilder:
            Text(session.builderPhrase.english).font(.title3)
            Text(session.builderTokens.isEmpty ? "Tap words to rebuild the book’s sentence…" : session.builderTokens.map { session.builderPhrase.words[$0] }.joined(separator: " "))
                .font(.title).padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 18))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 95))], spacing: 12) {
                ForEach(session.builderOrder, id: \.self) { index in
                    Button(session.builderPhrase.words[index]) { Task { await model.choose(String(index)) } }
                        .buttonStyle(.bordered).disabled(model.busy || session.builderTokens.contains(index))
                }
            }
        case .sentenceTrail:
            if session.trailScore == 0 {
                Menu("Scene: \(session.scenario.title)") {
                    ForEach(PracticeScenario.allCases) { scenario in
                        Button(scenario.title) { Task { await model.scenario(scenario) } }
                    }
                }.disabled(model.busy)
            }
            Label("\(session.trailScore) words in a row", systemImage: "flame.fill").font(.title2.bold())
            Text("Follow the English prompt, one word at a time. Tiles replenish as you build each phrase. A wrong word ends today’s trail; stop whenever you like.")
                .font(.subheadline).foregroundStyle(theme.theme.muted)
            Text(session.currentTrail.english).font(.title3)
            Text(session.trailWord == 0 ? "Your next phrase…" : session.currentTrail.words.prefix(session.trailWord).joined(separator: " "))
                .font(.title).padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 18))
            tiles(session.trailOptions)
            Text(session.currentTrail.source).font(.caption).foregroundStyle(theme.theme.muted)
            Button("Stop and keep my score") { Task { await model.stop() } }
                .buttonStyle(.bordered).disabled(model.busy || session.trailScore == 0)
        }
    }
    private func tiles(_ words: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 95))], spacing: 12) {
            ForEach(words, id: \.self) { word in
                Button(word) { Task { await model.choose(word) } }
                    .font(.title3).buttonStyle(.bordered).disabled(model.busy)
            }
        }
    }
    private func result(_ session: DailyPracticeSession, game: DailyPracticeGame) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 72)).foregroundStyle(theme.theme.accent)
                .symbolEffect(.bounce, options: .nonRepeating, isActive: !reduceMotion)
            Text(game == .sentenceTrail ? "\(session.trailScore) words in a row" : "\(game.title) finished!").font(.largeTitle.bold())
            if !model.showingReward, game == .sentenceTrail, session.trailBroken {
                Text("The next word was “\(session.currentTrail.words[session.trailWord])”.")
                Text(session.currentTrail.spanish).font(.title3)
            }
            if model.showingReward {
                DoubloonIcon(size: 100)
                Text("You earned 1 doubloon!").font(.title.bold())
                Text("Practice completed. Your coin is saved to your balance.")
            }
            Text("One play-through per day. Come back tomorrow for another set.").foregroundStyle(theme.theme.muted)
            if model.showingReward {
                Button("Back to daily practice") { model.selected = nil }.buttonStyle(PrimaryButton())
            } else {
                Button("Complete practice", action: model.completePractice).buttonStyle(PrimaryButton())
            }
        }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: model.showingReward)
            .sensoryFeedback(.success, trigger: model.showingReward)
    }
}
