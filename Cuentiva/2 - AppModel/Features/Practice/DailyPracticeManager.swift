//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation

@MainActor protocol DailyPracticeFeature: AnyObject {
    var session: DailyPracticeSession? { get }
    func prepare(books: [Book]) async throws
    func choose(_ choice: String, game: DailyPracticeGame, day: String) async throws -> Bool
    func stopTrail(day: String) async throws
    func selectScenario(_ scenario: PracticeScenario, day: String) async throws
}
@MainActor final class DailyPracticeManager: DailyPracticeFeature {
    private let progress: any ProgressFeature
    private let purchases: any PurchaseFeature
    init(progress: any ProgressFeature, purchases: any PurchaseFeature) {
        self.progress = progress; self.purchases = purchases
    }
    var session: DailyPracticeSession? { progress.dailyPractice }
    private func checkAccess() throws {
        guard purchases.hasAccess else { throw AppFailure.unavailable("Unlock the library to practise with today’s books.") }
    }
    func prepare(books: [Book]) async throws {
        try checkAccess()
        try await progress.prepareDailyPractice(books: books)
    }
    func choose(_ choice: String, game: DailyPracticeGame, day: String) async throws -> Bool {
        try checkAccess()
        return try await progress.answerDailyPractice(choice, game: game, day: day)
    }
    func selectScenario(_ scenario: PracticeScenario, day: String) async throws {
        try checkAccess()
        try await progress.selectPracticeScenario(scenario, day: day)
    }
    func stopTrail(day: String) async throws {
        try checkAccess()
        try await progress.stopDailyTrail(day: day)
    }
}
