import Foundation
import Observation

@MainActor @Observable final class DailyWelcomeViewModel {
    let welcome: DailyWelcome
    private let progress: any ProgressFeature
    private let pause: (Duration) async throws -> Void
    private(set) var buttonVisible = false
    private(set) var saving = false
    private(set) var error: String?
    var buttonTitle: String {
        if welcome.startsNewStreak { return "Start a new streak" }
        return welcome.practicedToday ? "Continue day \(welcome.nextDay)" : "Begin day \(welcome.nextDay)"
    }
    init(welcome: DailyWelcome, progress: any ProgressFeature,
         pause: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.welcome = welcome
        self.progress = progress
        self.pause = pause
    }
    func revealButton() async {
        guard !buttonVisible else { return }
        do {
            try await pause(.seconds(1))
            try Task.checkCancellation()
            buttonVisible = true
        } catch { /* Leaving the screen cancels its reveal. */ }
    }
    func beginDay() async -> Bool {
        guard buttonVisible, !saving else { return false }
        saving = true
        error = nil
        defer { saving = false }
        do {
            try await progress.acknowledgeWelcome(day: welcome.day)
            return true
        } catch {
            self.error = "Couldn’t save your welcome. Please try again."
            return false
        }
    }
}
