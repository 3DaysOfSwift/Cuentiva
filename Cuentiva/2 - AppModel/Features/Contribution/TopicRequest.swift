import Foundation

struct TopicRequest: Identifiable, Sendable {
    let id: String
    let title: String
    let category: String
    let priority: String
    let brief: String
    let scope: String
    let forms: [String]
    let requirements: [String]
    let target: Int
    let reviewedBooks: Int
    let demoExamples: Int
    var covered: Bool { reviewedBooks >= target }
    var coverageLabel: String { covered ? "Covered" : demoExamples == 0 && reviewedBooks == 0 ? "Missing coverage" : "More coverage needed" }
    func occurrences(in text: String) -> [Int] {
        let words = WordComparison.words(text).map(WordComparison.normalized)
        return forms.map { form in words.filter { $0 == form }.count }
    }
    func ready(_ draft: Contribution) -> Bool {
        !draft.teachingNote.orEmpty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Set(requirements).isSubset(of: Set(draft.checkedRequirements ?? [])) &&
        occurrences(in: draft.spanish).allSatisfy { $0 >= 2 }
    }
}
private extension Optional where Wrapped == String { var orEmpty: String { self ?? "" } }

