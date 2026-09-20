import Foundation
import Testing
@testable import Cuentiva

@MainActor final class TestAudio: LessonAudio {
    var spokenRange: NSRange?
    var transcript = "El café está aquí"
    var recording = false
    var error: String?
    var spokenRates: [Bool] = []
    func speak(_ text: String, slow: Bool) { spokenRates.append(slow) }
    func speakAndWait(_ text: String, slow: Bool) async -> Bool { true }
    func startRecording() async { recording = true }
    func stopRecording() { recording = false }
    func stop() { recording = false }
}

actor LaunchBooks: SyncingBookRepository {
    var syncCalls = 0
    func books() -> [Book] { [sample()] }
    func sync() -> [Book] { syncCalls += 1; return [sample()] }
}

@MainActor final class ReaderTestAudio: LessonAudio {
    var spokenRange: NSRange?
    var transcript = ""
    var recording = false
    var error: String?
    var spoken: [String] = []
    var rates: [Bool] = []
    var pending: CheckedContinuation<Bool, Never>?
    func speak(_ text: String, slow: Bool) {}
    func speakAndWait(_ text: String, slow: Bool) async -> Bool {
        spoken.append(text); rates.append(slow)
        return await withCheckedContinuation { pending = $0 }
    }
    func finishLine() { let value = pending; pending = nil; value?.resume(returning: true) }
    func startRecording() async {}
    func stopRecording() {}
    func stop() { let value = pending; pending = nil; value?.resume(returning: false) }
}

actor ReaderPauseProbe {
    var count = 0
    func pause() { count += 1 }
}

@MainActor final class DelayedLibrary: LibraryFeature {
    var books: [Book] = []
    var introduction: Book? { nil }
    var syncing = false
    var syncMessage: String?
    let revision = LibraryRevision()
    var pending: [CheckedContinuation<LibraryPresentation, Never>] = []
    func matchingBooks(_ query: LibraryQuery) async -> [Book] { await presentation(query).books }
    func presentation(_ query: LibraryQuery) async -> LibraryPresentation {
        await withCheckedContinuation { pending.append($0) }
    }
    func load() async throws {}
    func sync() async {}
    func prepareDailyReads() async throws {}
    func loadMoreDailyReads() async throws {}
}

@MainActor
func makeViewModelTestGraph() async throws -> (TestPurchases, ProgressManager, LibraryManager, LearningManager, ContributionManager) {
        let purchases = TestPurchases(), progress = ProgressManager(repository: MemoryProgress())
        try await progress.load()
        let library = LibraryManager(repository: MemoryBooks(values: [sample()]), purchases: purchases, progress: progress); try await library.loadIntroduction()
        return (purchases, progress, library, LearningManager(purchases: purchases, progress: progress), ContributionManager(repository: MemoryContributions(), purchases: purchases, progress: progress))
    }

@MainActor
func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !condition() {
            guard ContinuousClock.now < deadline else { throw AppFailure.unavailable("Test did not reach its gate.") }
            await Task.yield()
        }
    }
