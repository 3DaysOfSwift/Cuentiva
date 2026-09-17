import SwiftUI

struct PracticeView: View {
    @State private var model: PracticeViewModel
    @State private var stampVisible = false
    let streak: Int?
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(book: Book, match: Bool = false, streak: Int? = nil) {
        let model = PracticeViewModel(book: book)
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
            Text("About \(model.stats.families) word families").foregroundStyle(theme.theme.muted)
            if let previous = model.stats.previous, let newWords = model.stats.newWords {
                Text("\(previous) encountered before this book")
                Text("\(newWords) first encountered in this book").font(.title2)
            } else { Text("Earlier exposure wasn’t recorded for this book. We won’t guess which words were new.") }
            Text("Reading counts as exposure, not mastery. Different verb forms count as distinct written words.").font(.caption)
            Button("Match pairs") { model.prepareGame() }.buttonStyle(PrimaryButton())
            Button("Finish for today") { dismiss() }
        }
    }
    private var ready: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Match pairs").font(.system(.largeTitle, design: .serif))
            if model.glossary != nil {
                Text("Tap a Spanish word and its English meaning. Five pairs at a time, with every distinct word in this book waiting in the deck.")
                Toggle("30-second challenge", isOn: $model.timed)
                Text(model.timed ? "The timer starts after a three-second countdown." : "Untimed practice: work through the whole deck.")
                Text("Earn one doubloon for your first finished round with at least one match. Replays improve your score. Coins have no spending feature yet.").font(.caption)
                Button("Ready") { model.startGame() }.buttonStyle(PrimaryButton())
                Text(model.feedback).font(.caption)
            } else {
                Text("This book needs a checked English word glossary before Match Pairs is available. Try Ana’s little café or My father’s garden. Your turn is available for every completed book.")
            }
        }
    }
    private var game: some View {
        VStack(spacing: 18) {
            HStack { Text(model.timed ? "\(model.seconds)s" : "Untimed"); Spacer(); Text(model.matches == 1 ? "1 match" : "\(model.matches) matches") }.font(.title2)
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
            Text("Well played.").font(.system(.largeTitle, design: .serif))
            Text("\(model.matches == 1 ? "1 match" : "\(model.matches) matches") · \(model.accuracy)% accuracy")
            Text("Personal best: \(model.best == 1 ? "1 match" : "\(model.best) matches")")
            if !model.missed.isEmpty {
                Text("Words to revisit").font(.headline)
                ForEach(model.missed.sorted(), id: \.self) { word in Text("\(word) — \(model.glossary?[word] ?? "")") }
            }
            Label(model.awarded ? "+1 gold doubloon" : "\(model.coins) doubloons collected", systemImage: "circle.circle.fill").font(.title2).foregroundStyle(theme.theme.rewardGold)
            if model.matches == 0 { Text("Make at least one match in a finished round to earn this book’s doubloon.") }
            if model.saving { ProgressView("Saving your round…") }
            if model.error != nil { Button("Retry saving reward") { Task { await model.saveReward() } } }
            Button("Play again") { model.prepareGame() }.buttonStyle(PrimaryButton()).disabled(model.saving || model.error != nil)
            Button("Finish for today") { dismiss() }
        }
    }
}
