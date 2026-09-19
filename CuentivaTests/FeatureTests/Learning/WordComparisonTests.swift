import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite struct WordComparisonTests {
    @Test func omittedWordDoesNotShiftFollowingMatches() {
        let result = WordComparison.compare(expected: "El mundo está lleno de vida", received: "El mundo lleno de vida")
        #expect(result.words.map(\.result) == [.correct, .correct, .missing, .correct, .correct, .correct])
    }
    @Test func accentsPunctuationAndEnye() {
        let result = WordComparison.compare(expected: "¡El café está aquí!", received: "el cafe esta aqui")
        #expect(result.words.map(\.result) == [.correct, .accent, .accent, .accent])
        #expect(WordComparison.compare(expected: "año", received: "ano").words.first?.result == .incorrect)
    }
    @Test func insertionAndRepeatedWords() {
        let result = WordComparison.compare(expected: "Yo veo la casa", received: "Yo también veo la casa")
        #expect(result.matched == 4); #expect(result.extraWords == ["también"])
        #expect(WordComparison.compare(expected: "la la casa", received: "la casa").matched == 2)
    }
}
