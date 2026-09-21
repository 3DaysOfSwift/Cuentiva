//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Observation

@MainActor @Observable final class DailyPracticeViewModel {
    private let feature: any DailyPracticeFeature
    let books: [Book]
    var selected: DailyPracticeGame?
    private(set) var showingReward = false
    func completePractice() {
        guard let selected, session?.completed.contains(selected) == true,
              session?.creditedGames.contains(selected) == true else { return }
        showingReward = true
    }
    private(set) var busy = false
    private(set) var error: String?
    private(set) var feedback: String?
    private(set) var celebrationID: UUID?
    private var heldSession: DailyPracticeSession?
    private var heldCount: Int?
    var session: DailyPracticeSession? { feature.session }
    var displayedSession: DailyPracticeSession? { heldSession ?? session }
    var completedRounds: Int { heldCount ?? roundCount(session) }
    private func roundCount(_ value: DailyPracticeSession?) -> Int {
        guard let value else { return 0 }
        switch selected {
        case .missingWord: return value.missingIndex
        case .sentenceBuilder: return value.builderIndex
        case .sentenceTrail: return value.trailPhrase
        case nil: return 0
        }
    }
    func celebrateRound() async {
        guard let id = celebrationID else { return }
        defer {
            if celebrationID == id {
                heldCount = nil; heldSession = nil; celebrationID = nil
            }
        }
        do {
            try await Task.sleep(for: .milliseconds(650))
            guard celebrationID == id else { return }
            heldCount = nil
            try await Task.sleep(for: .milliseconds(650))
        } catch { /* Leaving the screen ends the animation; saved progress remains. */ }
    }
    init(books: [Book], feature: any DailyPracticeFeature) { self.books = books; self.feature = feature }
    func prepare() async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do { try await feature.prepare(books: books) } catch { self.error = error.localizedDescription }
    }
    func select(_ game: DailyPracticeGame) {
        guard !busy, celebrationID == nil, session != nil else { return }
        selected = game; feedback = nil; showingReward = false
    }
    func choose(_ choice: String) async {
        guard !busy, celebrationID == nil, let game = selected, let before = session else { return }
        let day = before.day
        let previousCount = roundCount(before)
        busy = true; error = nil
        defer { busy = false }
        do {
            let correct = try await feature.choose(choice, game: game, day: day)
            if correct && roundCount(session) > previousCount {
                heldSession = before
                heldCount = previousCount
                celebrationID = UUID()
            }
            feedback = correct ? nil : game == .sentenceTrail ? "That word broke the trail." : "Try another tile to rebuild the book’s sentence."
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
