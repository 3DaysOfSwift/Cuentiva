//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite struct WeeklyAuthorTests {
    @Test func legacyProfilesResolveToPermanentCharactersWithoutChangingIdentity() {
        let legacy = Author(id: "ana", name: "Ana · demo narrator", portrait: "AuthorAna", introduction: "Old biography", note: "Old note")
        #expect(legacy.storyteller.id == legacy.id)
        #expect(legacy.storyteller.name == "Brasa")
        #expect(legacy.storyteller.portrait == "StorytellerBrasa")
        #expect(Set(Author.demoProfiles.map(\.portrait)).count == Author.demoProfiles.count)
        #expect(Author.demoProfiles.allSatisfy { $0.name.split(whereSeparator: { $0.isWhitespace }).count == 1 })
        var book = sample()
        book.authorID = legacy.id
        #expect(book.storytellerName == "Brasa")
        #expect(Author.supportedPortraits.contains("AuthorAna"))
        #expect(!Author.supportedPortraits.contains("https://example.com/portrait.jpg"))
    }
    @Test func stableWithinWeekAndRotatesAcrossMondayWithoutDependingOnInputOrder() {
        let monday = Date(timeIntervalSince1970: 345_600 + 2900 * 604_800)
        let authors = Author.demoProfiles
        let current = Author.weeklyOrder(authors, on: monday)
        #expect(current == Author.weeklyOrder(authors.reversed(), on: monday.addingTimeInterval(604_799)))
        let next = Author.weeklyOrder(authors, on: monday.addingTimeInterval(604_800))
        #expect(current.first?.id != next.first?.id)
        #expect(Set(current.map(\.id)) == Set(next.map(\.id)))
        #expect(Author.weeklyOrder([], on: monday).isEmpty)
        #expect(Author.weeklyOrder([authors[0]], on: monday) == [authors[0]])
    }
}
