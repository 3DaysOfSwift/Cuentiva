import Observation

@MainActor @Observable final class LanguageTermDetailViewModel {
    let term: LanguageTerm?
    let related: [LanguageTerm]
    init(id: String, feature: any LanguageTermsFeature = AppModel.shared.languageTerms) {
        term = feature.term(id)
        related = (term?.related ?? []).compactMap { feature.term($0) }
    }
}
