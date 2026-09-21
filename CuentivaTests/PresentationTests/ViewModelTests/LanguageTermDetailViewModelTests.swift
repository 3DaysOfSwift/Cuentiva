//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Testing
@testable import Cuentiva

@Suite @MainActor struct LanguageTermDetailViewModelTests {
    @Test func validTermResolvesRelatedTermsAndMissingTermHasNoRelatedResults() throws {
        let feature = LanguageTermsManager()
        let model = LanguageTermDetailViewModel(id: "noun", feature: feature)
        let term = try #require(model.term)
        #expect(model.related.map(\.id) == term.related)
        let missing = LanguageTermDetailViewModel(id: "missing", feature: feature)
        #expect(missing.term == nil)
        #expect(missing.related.isEmpty)
    }
}
