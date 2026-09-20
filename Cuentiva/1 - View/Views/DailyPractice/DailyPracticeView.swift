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
                if let session = model.session {
                    if let game = model.selected {
                        if session.completed.contains(game) {
                            result(session, game: game)
                        } else {
                            Text(game.title).font(.largeTitle.bold())
                            exercise(session, game: game)
                        }
                    } else {
                        Text("A little practice, a stronger sentence.").font(.system(.largeTitle, design: .serif))
                        Text("One daily set from your three selected books. You can leave and resume unfinished games.")
                            .foregroundStyle(theme.theme.muted)
                        ForEach(DailyPracticeGame.allCases) { game in
                            Button { model.select(game) } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: game.symbol).font(.title)
                                    Text(game.title).font(.title3.bold())
                                    Spacer()
                                    Image(systemName: session.completed.contains(game) ? "checkmark.circle.fill" : "play.circle.fill")
                                }.padding(20).background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 20))
                            }.buttonStyle(.plain).disabled(session.completed.contains(game))
                        }
                        if session.rewarded {
                            Label("All three finished. 1 doubloon earned!", systemImage: "checkmark.seal.fill")
                            DoubloonBalance(count: 1, earned: true, size: 48)
                            Text("New games tomorrow. Your reward has been saved.").foregroundStyle(theme.theme.muted)
                        } else { Text("Finish all three to earn 1 doubloon.") }
                    }
                } else if model.busy { ProgressView("Preparing practice…") }
                else { Button("Prepare today’s practice") { Task { await model.prepare() } } }
                if let feedback = model.feedback { Text(feedback).foregroundStyle(theme.theme.accent) }
                InlineError(message: model.error)
            }.padding(24)
        }
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink).tint(theme.theme.accent)
        .navigationTitle("Daily practice").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
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
            Text("Sentence \(session.builderIndex + 1) of \(session.rounds)").font(.caption)
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
            Text("Recreate the original wording. Other Spanish phrasings may also be valid.").font(.caption).foregroundStyle(theme.theme.muted)
            Text(session.builderPhrase.source).font(.caption)
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
            if game == .sentenceTrail, session.trailBroken {
                Text("The next word was “\(session.currentTrail.words[session.trailWord])”.")
                Text(session.currentTrail.spanish).font(.title3)
            }
            if session.rewarded {
                DoubloonIcon(size: 100)
                Text("You earned 1 doubloon!").font(.title.bold())
                Text("All three games finished. Your coin is saved to your balance.")
            }
            Text("One play-through per day. Come back tomorrow for another set.").foregroundStyle(theme.theme.muted)
            Button("Back to daily practice") { model.selected = nil }.buttonStyle(PrimaryButton())
        }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
    }
}
