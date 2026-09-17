import Foundation
import Observation

@MainActor @Observable final class PracticeViewModel {
    enum Stage { case invitation, reading, statistics, ready, countdown, playing, result }
    let book: Book
    private let feature: any PracticeFeature
    var stage = Stage.invitation
    var timed = true
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
    var awarded = false
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
    init(book: Book, feature: any PracticeFeature = AppModel.shared.practice, now: @escaping () -> ContinuousClock.Instant = { ContinuousClock().now }) { self.book = book; self.feature = feature; self.now = now }
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
        matches = 0; mistakes = 0; missed = []; seconds = 30; countdown = 3; awarded = false; error = nil
        remaining = glossary.keys.sorted().shuffled(); board = []; selectedSpanish = nil; selectedEnglish = nil; feedback = ""
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
            if now() >= deadline { stage = .playing; self.deadline = now().advanced(by: .seconds(30)) }
        } else if stage == .playing, timed, let deadline {
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
        stage = .result
        await saveReward()
    }
    func saveReward() async {
        guard !saving, matches > 0 else { return }
        saving = true; defer { saving = false }; error = nil
        do { awarded = try await feature.reward(book, matches: matches) }
        catch { self.error = error.localizedDescription }
    }
    func suspend() {
        pacing = false
        if stage == .playing || stage == .countdown { stage = .ready; feedback = "Round interrupted. Start again when you are ready." }
    }
}
