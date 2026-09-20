import Foundation
import Observation

@MainActor @Observable final class DailyPracticeViewModel {
    private let feature: any DailyPracticeFeature
    let books: [Book]
    var selected: DailyPracticeGame?
    private(set) var busy = false
    private(set) var error: String?
    private(set) var feedback: String?
    var session: DailyPracticeSession? { feature.session }
    init(books: [Book], feature: any DailyPracticeFeature) { self.books = books; self.feature = feature }
    func prepare() async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do { try await feature.prepare(books: books) } catch { self.error = error.localizedDescription }
    }
    func select(_ game: DailyPracticeGame) {
        guard !busy, session?.completed.contains(game) == false else { return }
        selected = game; feedback = nil
    }
    func choose(_ choice: String) async {
        guard !busy, let game = selected, let day = session?.day else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            let correct = try await feature.choose(choice, game: game, day: day)
            feedback = correct ? "That fits!" : game == .sentenceTrail ? "That word broke the trail." : "Try another tile to rebuild the book’s sentence."
        } catch { self.error = error.localizedDescription }
    }
    func scenario(_ scenario: PracticeScenario) async {
        guard !busy, let day = session?.day else { return }
        busy = true; error = nil
        defer { busy = false }
        do { try await feature.selectScenario(scenario, day: day) } catch { self.error = error.localizedDescription }
    }
    func stop() async {
        guard !busy, let day = session?.day else { return }
        busy = true; error = nil
        defer { busy = false }
        do { try await feature.stopTrail(day: day) } catch { self.error = error.localizedDescription }
    }
}
