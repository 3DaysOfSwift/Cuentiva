import Foundation
import Testing
import CryptoKit
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite struct PersistenceTests {
    @Test func swiftDataProgressRoundTrip() async throws {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = SwiftDataStore(url: folder.appending(path: "app.store"))
        let repo = LocalProgressRepository(url: folder.appending(path: "progress.json"), store: store)
        var value = LearnerProgress(); value.completed = ["cafe"]; value.positions["garden"] = 3
        try await repo.save(value)
        let reloaded = try await repo.load()
        #expect(reloaded.completed == ["cafe"]); #expect(reloaded.positions["garden"] == 3)
    }
    @Test func corruptDataDoesNotSilentlyResetProgress() async throws {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = SwiftDataStore(url: folder.appending(path: "app.store"))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "progress.json")
        try Data("not-json".utf8).write(to: url)
        await #expect(throws: (any Error).self) { try await LocalProgressRepository(url: url, store: store).load() }
    }
}
