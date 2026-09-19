import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite struct RecommendationPriorityTests {
    @Test func personalThenNewThenRecentAndRecyclingUsesOnlyRotation() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_014_400))
        var personal = sample("personal")
        personal.personalAuthor = Author.demoProfiles[0]
        let fresh = sample("fresh"), recent = sample("recent"), old = sample("old")
        let books = [old, recent, fresh, personal]
        let arrivals = [fresh.id: today, old.id: today.addingTimeInterval(-31 * 86400)]
        let lastRead = [recent.id: today]
        var order = LibraryRecommendationOrder()
        let ranked = order.order(books, recycling: false, today: today, calendar: calendar,
            arrivals: arrivals, lastRead: lastRead, level: nil)
        #expect(ranked.map(\.id) == ["personal", "fresh", "recent", "old"])
        let recycled = order.order(books, recycling: true, today: today, calendar: calendar,
            arrivals: arrivals, lastRead: lastRead, level: .a1)
        var baseline = LibraryRecommendationOrder()
        let rotation = baseline.order(books.reversed(), recycling: true, today: today, calendar: calendar,
            arrivals: [:], lastRead: [:], level: nil)
        #expect(recycled.map(\.id) == rotation.map(\.id))
        #expect(Set(recycled.map(\.id)) == Set(books.map(\.id)))
    }
}
