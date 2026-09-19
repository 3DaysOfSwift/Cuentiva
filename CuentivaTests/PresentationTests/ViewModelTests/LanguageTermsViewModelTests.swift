import Testing
@testable import Cuentiva

@Suite @MainActor struct LanguageTermsViewModelTests {
    @Test func changingSearchUpdatesTermsAndClearingRestoresTheCatalogue() {
        let model = LanguageTermsViewModel(feature: LanguageTermsManager())
        let all = model.terms
        #expect(!all.isEmpty)
        model.query = "Sustantivo"
        #expect(model.terms.contains { $0.id == "noun" })
        model.query = "no-such-language-term"
        #expect(model.terms.isEmpty)
        model.query = ""
        #expect(model.terms == all)
    }
}
