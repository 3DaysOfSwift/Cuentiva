import Foundation

enum WordResult: String, Sendable { case correct, accent, incorrect, missing }
struct WordFeedback: Identifiable, Sendable {
    let id: Int
    let expected: String
    let received: String?
    let result: WordResult
}
struct AnswerFeedback: Sendable {
    let words: [WordFeedback]
    let extraWords: [String]
    var matched: Int { words.filter { $0.result == .correct }.count }
}
/// Minimum-edit alignment prevents one omitted word from shifting all later feedback.
enum WordComparison {
    static func words(_ text: String) -> [String] {
        text.split { !$0.isLetter && !$0.isNumber && $0 != "'" }.map(String.init)
    }
    static func normalized(_ text: String) -> String { text.lowercased().precomposedStringWithCanonicalMapping }
    static func compare(expected: String, received: String) -> AnswerFeedback {
        let a = words(expected), b = words(received)
        var costs = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { costs[i][0] = i }
        for j in 0...b.count { costs[0][j] = j }
        if !a.isEmpty && !b.isEmpty {
            for i in 1...a.count { for j in 1...b.count {
                let same = normalized(a[i-1]) == normalized(b[j-1])
                costs[i][j] = min(costs[i-1][j] + 1, costs[i][j-1] + 1, costs[i-1][j-1] + (same ? 0 : 1))
            } }
        }
        var i = a.count, j = b.count, results: [WordFeedback] = [], extras: [String] = []
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && costs[i][j] == costs[i-1][j-1] + (normalized(a[i-1]) == normalized(b[j-1]) ? 0 : 1) {
                let x = normalized(a[i-1]), y = normalized(b[j-1])
                let accentOnly = x.replacingOccurrences(of: "á", with: "a").replacingOccurrences(of: "é", with: "e").replacingOccurrences(of: "í", with: "i").replacingOccurrences(of: "ó", with: "o").replacingOccurrences(of: "ú", with: "u") == y.replacingOccurrences(of: "á", with: "a").replacingOccurrences(of: "é", with: "e").replacingOccurrences(of: "í", with: "i").replacingOccurrences(of: "ó", with: "o").replacingOccurrences(of: "ú", with: "u")
                results.append(.init(id: i-1, expected: a[i-1], received: b[j-1], result: x == y ? .correct : accentOnly ? .accent : .incorrect)); i -= 1; j -= 1
            } else if i > 0 && costs[i][j] == costs[i-1][j] + 1 {
                results.append(.init(id: i-1, expected: a[i-1], received: nil, result: .missing)); i -= 1
            } else { extras.append(b[j-1]); j -= 1 }
        }
        return .init(words: results.reversed(), extraWords: extras.reversed())
    }
}
