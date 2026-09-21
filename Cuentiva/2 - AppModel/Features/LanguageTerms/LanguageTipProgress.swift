import Foundation

struct LanguageTipProgress: Codable, Equatable, Sendable {
    var visitDays: Set<String> = []
    var seen: Set<String> = []
    var pending: String?
    mutating func visit(day: String, termIDs: [String]) {
        guard visitDays.insert(day).inserted else { return }
        guard pending == nil, visitDays.count % 2 == 1 else { return }
        pending = termIDs.first { !seen.contains($0) }
    }
    mutating func acknowledge(_ id: String) throws {
        guard pending == id else { throw AppFailure.incomplete }
        seen.insert(id); pending = nil
    }
}
