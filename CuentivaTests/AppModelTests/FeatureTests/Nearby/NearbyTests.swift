import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct NearbyTests {
    func place(_ longitude: Double = 115.26, date: Date = .now) -> StoryLocation {
        .init(latitude: -8.51, longitude: longitude, accuracy: 100, capturedAt: date, placeName: "Ubud, Indonesia")
    }
    @Test func distanceFilteringAndLegacyLibrary() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        var local = sample("bali"); local.submissionLocation = place()
        var distant = sample("far"); distant.submissionLocation = place(0)
        let library = LibraryManager(repository: MemoryBooks(values: [sample(), local, distant]), purchases: purchases, progress: progress)
        try await library.load()
        let nearby = NearbyManager(library: library, purchases: purchases)
        #expect(nearby.stories(around: place(), kilometers: 5).map(\.id) == ["bali"])
        #expect(nearby.stories(around: place(date: .now.addingTimeInterval(-600)), kilometers: 5).isEmpty)
        #expect(await library.search("", level: nil, completedOnly: false).map(\.id) == ["cafe"])
        try await progress.recordEncounter(book: local, sentence: local.sentences[0])
        _ = try await progress.complete(book: local)
        #expect(await library.search("", level: nil, completedOnly: true).map(\.id) == ["bali"])
        purchases.hasAccess = false
        #expect(nearby.stories(around: place(), kilometers: 100).isEmpty)
    }
    @Test func submittedPlaceCannotBeMovedOrRemoved() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        let intro = sample(); try await progress.recordEncounter(book: intro, sentence: intro.sentences[0]); _ = try await progress.complete(book: intro)
        let storage = MemoryContributions()
        let feature = ContributionManager(repository: storage, purchases: purchases, progress: progress)
        var draft = Contribution(); draft.title = "Aquí"; draft.spanish = "Hoy veo una casa bonita y hablo con una amiga nueva."; draft.submissionLocation = place()
        try await feature.save(draft, submit: true)
        draft.submissionLocation = nil
        await #expect(throws: (any Error).self) { try await feature.save(draft, submit: false) }
        draft.submissionLocation = place(0)
        await #expect(throws: (any Error).self) { try await feature.save(draft, submit: true) }
        #expect(await storage.drafts().first?.submissionLocation?.longitude == 115.26)
        try await feature.remove(draft.id)
        #expect(await storage.drafts().isEmpty)
        var stale = Contribution(); stale.title = "Yesterday"; stale.spanish = draft.spanish; stale.submissionLocation = place(date: .now.addingTimeInterval(-600))
        await #expect(throws: (any Error).self) { try await feature.save(stale, submit: true) }
    }
}
