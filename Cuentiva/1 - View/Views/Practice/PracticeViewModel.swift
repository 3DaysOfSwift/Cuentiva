//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Observation

@MainActor @Observable final class PracticeViewModel {
    enum Stage { case invitation, reading, statistics, ready, countdown, playing, result }
    let book: Book
    let challengeDay: String?
    private(set) var matchedWords: Set<String> = []
    var isDailyGame: Bool { challengeDay != nil }
    var dailyRewarded: Bool { feature.dailyChallenge?.day == challengeDay && feature.dailyChallenge?.paidBookIDs.contains(book.id) == true }
    private let feature: any PracticeFeature
    var rewardReceipt: MatchRewardReceipt?
    private var scoreSaved = false
    var stage = Stage.invitation
    var timed = true
    private(set) var elapsed = 0.0
    private var roundStarted: ContinuousClock.Instant?
    var elapsedText: String { Self.clockText(elapsed) }
    var fastestTimeText: String? { feature.fastestTime(book, daily: isDailyGame).map(Self.clockText) }
    private static func clockText(_ seconds: Double) -> String {
        let tenths = (seconds * 10).rounded()
        return String(format: "%02.0f:%04.1f", floor(tenths / 600), tenths.truncatingRemainder(dividingBy: 600) / 10)
    }
    private func updateElapsed() {
        guard let roundStarted else { return }
        let parts = roundStarted.duration(to: now()).components
        elapsed = max(0, Double(parts.seconds) + Double(parts.attoseconds) / 1e18)
    }
    var seconds = 30
    var countdown = 3
    var matches = 0
    var mistakes = 0
    var missed: Set<String> = []
    var selectedSpanish: String?
    var selectedEnglish: String?
    var board: [String] = []
    var right: [String] = []
    var remaining: [String] = []
    var feedback = ""
    var error: String?
    var saving = false
    var sentenceIndex = 0
    var wordIndex = 0
    var pacing = false
    var wordsPerMinute = 100.0
    var revealed: Set<String> = []
    private let now: () -> ContinuousClock.Instant
    private var deadline: ContinuousClock.Instant?
    private var nextWord: ContinuousClock.Instant?
    init(book: Book, challengeDay: String? = nil, feature: any PracticeFeature = AppModel.shared.practice, now: @escaping () -> ContinuousClock.Instant = { ContinuousClock().now }) { self.book = book; self.challengeDay = challengeDay; self.feature = feature; if challengeDay != nil { self.timed = false }; self.now = now }
    var allowed: Bool { feature.allowed(book) }
    var stats: PracticeStats { feature.stats(book) }
    var glossary: [String: String]? { feature.glossary(book) }
    var best: Int { feature.best(book) }
    var coins: Int { feature.coins }
    var week: [WeekDay] { feature.week }
    var accuracy: Int { matches + mistakes == 0 ? 0 : Int(Double(matches) / Double(matches + mistakes) * 100) }
    func read() { stage = .reading; sentenceIndex = 0; wordIndex = 0; pacing = false; revealed = [] }
    func togglePacing() { pacing.toggle(); nextWord = now() }
    func prepareGame() { stage = .ready; error = nil }
    func startGame() {
        guard allowed, let glossary else { return }
        matches = 0; mistakes = 0; missed = []; seconds = 30; countdown = 3; error = nil
        matchedWords = []; scoreSaved = false; rewardReceipt = nil; elapsed = 0; roundStarted = nil
        if let challengeDay {
            do { remaining = try feature.dailyDeck(book, day: challengeDay); timed = false }
            catch { self.error = error.localizedDescription; return }
        } else { remaining = glossary.keys.sorted().shuffled() }
        board = []; selectedSpanish = nil; selectedEnglish = nil; feedback = ""
        fillBoard(); stage = .countdown; deadline = now().advanced(by: .seconds(3))
    }
    private func fillBoard() {
        guard let glossary else { return }
        while board.count < 5, let index = remaining.firstIndex(where: { word in !board.contains { glossary[$0] == glossary[word] } }) {
            board.append(remaining.remove(at: index))
        }
        right = board.shuffled()
    }
    func chooseSpanish(_ word: String) async { guard acceptsInput, board.contains(word) else { await tick(); return }; selectedSpanish = word; await checkPair() }
    func chooseEnglish(_ word: String) async { guard acceptsInput, right.contains(word) else { await tick(); return }; selectedEnglish = word; await checkPair() }
    private var acceptsInput: Bool { stage == .playing && allowed && (!timed || deadline.map { now() < $0 } == true) }
    private func checkPair() async {
        guard let spanish = selectedSpanish, let english = selectedEnglish else { return }
        selectedSpanish = nil; selectedEnglish = nil
        if spanish == english {
            matchedWords.insert(spanish)
            matches += 1; feedback = "Correct: \(spanish) — \(glossary?[spanish] ?? "")"
            board.removeAll { $0 == spanish }; fillBoard()
            if board.isEmpty { await finishGame() }
        } else { missed.insert(spanish); mistakes += 1; feedback = "Try again. Those words do not match." }
    }
    func tick() async {
        guard allowed else { pacing = false; return }
        if stage == .reading, pacing, nextWord.map({ now() >= $0 }) == true {
            let count = book.fullText[sentenceIndex].spanish.split(separator: " ").count
            if wordIndex + 1 < count { wordIndex += 1 }
            else if sentenceIndex + 1 < book.fullText.count { sentenceIndex += 1; wordIndex = 0 }
            else { pacing = false }
            nextWord = now().advanced(by: .milliseconds(Int(60000 / wordsPerMinute)))
        }
        if stage == .countdown, let deadline {
            countdown = max(1, Int(ceil(secondsUntil(deadline))))
            if now() >= deadline { stage = .playing; roundStarted = now(); self.deadline = now().advanced(by: .seconds(30)) }
        }
        if stage == .playing { updateElapsed() }
        if stage == .playing, timed, let deadline {
            seconds = max(0, Int(ceil(secondsUntil(deadline))))
            if now() >= deadline { await finishGame() }
        }
    }
    private func secondsUntil(_ instant: ContinuousClock.Instant) -> Double {
        let parts = now().duration(to: instant).components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
    private func finishGame() async {
        guard stage == .playing else { return }
        updateElapsed()
        roundStarted = nil
        stage = .result
        await saveScore()
    }
    func saveScore() async {
        guard !saving, !scoreSaved, matches > 0 else { return }
        saving = true; defer { saving = false }; error = nil
        do {
            if let challengeDay {
                guard matchedWords.count == DailyMatchChallenge.pairCount else { throw AppFailure.incomplete }
                rewardReceipt = try await feature.finishDailyGame(book, day: challengeDay, words: matchedWords, elapsed: elapsed > 0 ? elapsed : nil)
            } else { try await feature.recordScore(book, matches: matches, elapsed: board.isEmpty && remaining.isEmpty && elapsed > 0 ? elapsed : nil) }
            scoreSaved = true
        }
        catch { self.error = error.localizedDescription }
    }
    func suspend() {
        pacing = false
        if stage == .playing || stage == .countdown { roundStarted = nil; stage = .ready; feedback = "Round interrupted. Start again when you are ready." }
    }
}
