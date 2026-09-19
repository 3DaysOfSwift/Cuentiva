import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct LanguageTermsTests {
    @Test func bilingualSearchAndRelatedEntriesStayNavigable() {
        let feature = LanguageTermsManager()
        let terms = feature.search("")
        #expect(terms.count == 12)
        #expect(Set(terms.map(\.id)).count == terms.count)
        #expect(feature.search(" SUSTANTIVO ").map(\.id) == ["noun"])
        #expect(feature.search("conjugacion").contains { $0.id == "conjugation" })
        #expect(feature.search("not-a-term").isEmpty)
        for term in terms {
            #expect(!term.meaning.isEmpty && !term.englishExample.isEmpty && !term.spanishExample.isEmpty)
            #expect(term.related.allSatisfy { $0 != term.id && feature.term($0) != nil })
        }
    }
}
