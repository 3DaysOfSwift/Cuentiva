import SwiftUI

struct PracticeView: View {
    @State private var model: PracticeViewModel
    @State private var stampVisible = false
    let streak: Int?
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(book: Book, match: Bool = false, streak: Int? = nil, challengeDay: String? = nil) {
        let model = PracticeViewModel(book: book, challengeDay: challengeDay)
        if match { model.prepareGame() }
        _model = State(initialValue: model); self.streak = streak
    }
    var body: some View {
        Group {
            if !model.allowed { ContentUnavailableView("Unlock Cuentiva to continue", systemImage: "lock") }
            else if model.stage == .reading { reader }
            else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch model.stage {
                        case .invitation: invitation
                        case .statistics: statistics
                        case .ready: ready
                        case .countdown:
                            Text("Ready?").font(.largeTitle)
                            Text("\(model.countdown)").font(.system(size: 90, design: .serif)).frame(maxWidth: .infinity)
                        case .playing: game
                        case .result: result
                        case .reading: EmptyView()
                        }
                        InlineError(message: model.error)
                    }.padding(24)
                }
            }
        }
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink)
        .navigationTitle("Your turn").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        .task {
            do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
            withAnimation(reduceMotion ? nil : .spring(duration: 0.6)) { stampVisible = true }
            while !Task.isCancelled {
                await model.tick()
                do { try await Task.sleep(for: .milliseconds(75)) } catch { return }
            }
        }
        .fullScreenCover(item: $model.rewardReceipt) { receipt in
            MatchRewardView(receipt: receipt) { model.rewardReceipt = nil }
        }
        .onDisappear { model.suspend() }
        .onChange(of: scenePhase) { _, value in if value != .active { model.suspend() } }
    }
    private var invitation: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let streak {
                Label("\(stampVisible ? streak : max(0, streak - 1)) day streak", systemImage: "flame.fill")
                    .font(.title2.bold()).contentTransition(.numericText()).foregroundStyle(theme.theme.accent)
                HStack {
                    ForEach(model.week) { day in
                        VStack { Text(day.label); Image(systemName: day.practiced && (!day.today || stampVisible) ? "checkmark.circle.fill" : "circle") }
                            .frame(maxWidth: .infinity).foregroundStyle(theme.theme.accent)
                            .accessibilityLabel("\(day.id): \(day.practiced ? "practiced" : "not practiced")")
                    }
                }
            }
            Text("You know this story.\nNow make it yours.").font(.system(.largeTitle, design: .serif))
            Text("Read it in Spanish, at your own pace. No audio, no score. Tap a sentence if you need its English.")
            Button("Try it in Spanish") { model.read() }.buttonStyle(PrimaryButton())
            Button("Finish for today") { dismiss() }
        }
    }
    private var reader: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Button(model.pacing ? "Pause guide" : "Start guide") { model.togglePacing() }
                        Spacer()
                        Button("Restart") { model.read() }
                    }
                    Slider(value: $model.wordsPerMinute, in: 60...180, step: 10).accessibilityLabel("Reading pace")
                    Text("\(Int(model.wordsPerMinute)) words per minute · optional guide").font(.caption)
                    ForEach(Array(model.book.fullText.enumerated()), id: \.element.id) { index, sentence in
                        VStack(alignment: .leading, spacing: 8) {
                            if let speaker = sentence.speaker { Text(speaker).font(.caption.bold()) }
                            Button { if model.revealed.contains(sentence.id) { model.revealed.remove(sentence.id) } else { model.revealed.insert(sentence.id) } } label: {
                                highlighted(sentence.spanish, active: index == model.sentenceIndex)
                                    .font(.system(.title2, design: .serif)).multilineTextAlignment(.leading)
                            }.buttonStyle(.plain).accessibilityHint("Reveal English translation")
                            if model.revealed.contains(sentence.id) { Text(sentence.english).foregroundStyle(theme.theme.muted) }
                        }.id(sentence.id)
                    }
                    Button("I’ve read it in Spanish") { model.pacing = false; model.stage = .statistics }.buttonStyle(PrimaryButton())
                }.padding(24)
            }
            .onChange(of: model.sentenceIndex) { _, index in
                withAnimation(reduceMotion ? nil : .easeInOut) { proxy.scrollTo(model.book.fullText[index].id, anchor: .center) }
            }
        }
    }
    private func highlighted(_ text: String, active: Bool) -> Text {
        text.split(separator: " ").enumerated().reduce(Text("")) { result, item in
            let word = Text(String(item.element) + " ").foregroundColor(active && model.pacing && item.offset == model.wordIndex ? theme.theme.accent : theme.theme.ink)
                .underline(active && model.pacing && item.offset == model.wordIndex)
            return Text("\(result)\(word)")
        }
    }
    private var statistics: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Look how much Spanish\nyou just read.").font(.system(.largeTitle, design: .serif))
            Text("\(model.stats.total) words · \(model.stats.distinct) distinct written words")
            NavigationLink { LanguageTermDetailView(id: "lemma") } label: {
                Label("About \(model.stats.families) word families", systemImage: "info.circle")
            }.accessibilityHint("Learn what a lemma and word family mean")
            if let previous = model.stats.previous, let newWords = model.stats.newWords {
                Text("\(previous) encountered before this book")
                Text("\(newWords) first encountered in this book").font(.title2)
            } else { Text("Earlier exposure wasn’t recorded for this book. We won’t guess which words were new.") }
            Text("Reading counts as exposure, not mastery. Different verb forms count as distinct written words.").font(.caption)

            Button("Finish for today") { dismiss() }
        }
    }
    private var ready: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Match pairs").font(.system(.largeTitle, design: .serif))
            if model.glossary != nil {
                Text(model.isDailyGame ? "Join 30 Spanish words with their English meanings. Five pairs at a time, with no time limit. Mistakes are welcome—keep trying." : "Tap a Spanish word and its English meaning. Five pairs at a time, with every distinct word in this book waiting in the deck.")
                if !model.isDailyGame { Toggle("30-second challenge", isOn: $model.timed) }
                Text(model.isDailyGame ? (model.dailyRewarded ? "You’ve collected this game’s doubloon today. Play again to practise—your balance will stay the same." : "Complete this daily game to earn 1 doubloon. Each of today’s three games has its own reward.") : model.timed ? "The timer starts after a three-second countdown." : "Untimed practice: work through the whole deck.")
                Text("Earn one doubloon when you complete a new story. Spend it on a topic chat. This practice helps improve your score.").font(.caption)
                if let best = model.fastestTimeText {
                    Label("Fastest \(model.isDailyGame ? "30 pairs" : "full deck"): \(best)", systemImage: "stopwatch")
                        .monospacedDigit().foregroundStyle(theme.theme.accent)
                }
                Button("Ready") { model.startGame() }.buttonStyle(PrimaryButton())
                Text(model.feedback).font(.caption)
            } else {
                Text("Matching practice isn’t available for this book yet. You can still practise reading with Your turn.")
            }
        }
    }
    private var game: some View {
        VStack(spacing: 18) {
            Label(model.elapsedText, systemImage: "stopwatch")
                .font(.title.monospacedDigit()).foregroundStyle(theme.theme.accent)
                .accessibilityLabel("Elapsed time: \(model.elapsedText)")
            if let best = model.fastestTimeText {
                Text("Fastest: \(best)").font(.subheadline.monospacedDigit())
            }
            HStack { Text(model.isDailyGame ? "\(model.matches) / 30 pairs" : model.timed ? "\(model.seconds)s" : "Untimed"); Spacer(); Text(model.matches == 1 ? "1 match" : "\(model.matches) matches") }.font(.title2)
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 12) {
                    ForEach(model.board, id: \.self) { word in
                        pairButton(word, selected: model.selectedSpanish == word) { await model.chooseSpanish(word) }
                    }
                }.frame(maxWidth: .infinity)
                VStack(spacing: 12) {
                    ForEach(model.right, id: \.self) { word in
                        pairButton(model.glossary?[word] ?? "", selected: model.selectedEnglish == word) { await model.chooseEnglish(word) }
                    }
                }.frame(maxWidth: .infinity)
            }
            Text(model.feedback).font(.caption).accessibilityAddTraits(.updatesFrequently)
        }
    }
    private func pairButton(_ title: String, selected: Bool, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Text(title).frame(maxWidth: .infinity, minHeight: 54).padding(8)
                .background(selected ? theme.theme.accent.opacity(0.2) : theme.theme.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(selected ? theme.theme.accent : .clear, lineWidth: 2) }
        }.buttonStyle(.plain).accessibilityValue(selected ? "Selected" : "")
    }
    private var result: some View {
        VStack(alignment: .leading, spacing: 20) {
            if model.isDailyGame && model.error == nil && !model.saving {
                Label(model.dailyRewarded ? "Daily reward collected" : "Daily game completed", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(theme.theme.accent)
            }
            Text("Well played.").font(.system(.largeTitle, design: .serif))
            Label("Your time: \(model.elapsedText)", systemImage: "stopwatch").font(.title2.monospacedDigit())
            if let best = model.fastestTimeText {
                Text("Fastest \(model.isDailyGame ? "30 pairs" : "full deck"): \(best)").font(.headline.monospacedDigit())
            }
            Text("\(model.matches == 1 ? "1 match" : "\(model.matches) matches") · \(model.accuracy)% accuracy")
            Text("Personal best: \(model.best == 1 ? "1 match" : "\(model.best) matches")")
            if !model.missed.isEmpty {
                Text("Words to revisit").font(.headline)
                ForEach(model.missed.sorted(), id: \.self) { word in Text("\(word) — \(model.glossary?[word] ?? "")") }
            }
            DoubloonBalance(count: model.coins, size: 36).font(.title2).foregroundStyle(theme.theme.rewardGold)
            if model.matches == 0 { Text("Try another round to practise these words. Your story-completion doubloon is already earned.") }
            if model.saving { ProgressView("Saving your round…") }
            if model.error != nil { Button("Retry saving score") { Task { await model.saveScore() } } }
            Button("Play again") { model.prepareGame() }.buttonStyle(PrimaryButton()).disabled(model.saving || model.error != nil)
            Button("Finish for today") { dismiss() }
        }
    }
}
