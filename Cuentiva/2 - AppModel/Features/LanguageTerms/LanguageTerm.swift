//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation

struct LanguageTerm: Identifiable, Hashable, Sendable {
    let id: String
    let english: String
    let spanish: String
    let meaning: String
    let explanation: String
    let englishExample: String
    let spanishExample: String
    let takeaway: String
    let related: [String]
}
