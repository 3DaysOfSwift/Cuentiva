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
