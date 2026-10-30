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
    @ObservationIgnored private var operationTask: Task<Void, Never>?
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
    @discardableResult
    func prepare() -> Task<Void, Never> {
        perform { try await self.feature.prepare(books: self.books) }
    }
    func select(_ game: DailyPracticeGame) {
        guard !busy, celebrationID == nil, session != nil else { return }
        selected = game; feedback = nil; showingReward = false
    }
    @discardableResult
    func choose(_ choice: String) -> Task<Void, Never> {
        perform {
            guard self.celebrationID == nil, let game = self.selected,
                  let before = self.session else { return }
            let previousCount = self.roundCount(before)
            let correct = try await self.feature.choose(choice, game: game, day: before.day)
            if correct && self.roundCount(self.session) > previousCount {
                self.heldSession = before
                self.heldCount = previousCount
                self.celebrationID = UUID()
            }
            self.feedback = correct ? nil : game == .sentenceTrail ? "That word broke the trail." : "Try another tile to rebuild the book’s sentence."
        }
    }
    @discardableResult
    func scenario(_ scenario: PracticeScenario) -> Task<Void, Never> {
        perform {
            guard let day = self.session?.day else { return }
            try await self.feature.selectScenario(scenario, day: day)
        }
    }
    @discardableResult
    func stop() -> Task<Void, Never> {
        perform {
            guard let day = self.session?.day else { return }
            try await self.feature.stopTrail(day: day)
        }
    }

    /// One admitted action at a time. Saved practice survives screen departure.
    private func perform(_ action: @escaping @MainActor () async throws -> Void) -> Task<Void, Never> {
        if let operationTask { return operationTask }
        busy = true
        error = nil
        let task = Task {
            defer { busy = false; operationTask = nil }
            do {
                try Task.checkCancellation()
                try await action()
            } catch is CancellationError {
                // Cancellation before the save begins is not a failed answer.
            } catch {
                self.error = error.localizedDescription
            }
        }
        operationTask = task
        return task
    }
}
