//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Observation

@MainActor @Observable final class LanguageTermsViewModel {
    private let feature: any LanguageTermsFeature
    var query = ""
    var terms: [LanguageTerm] { feature.search(query) }
    init(feature: any LanguageTermsFeature = AppModel.shared.languageTerms) { self.feature = feature }
}
