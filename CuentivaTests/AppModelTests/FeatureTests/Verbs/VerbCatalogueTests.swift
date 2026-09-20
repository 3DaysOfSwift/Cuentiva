import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite struct VerbCatalogueTests {
    @Test func celebrationCountsOnlyLastTwelveAndCountsCompoundExpressionsOnce() {
        let ids = ["ir/future/yo"] + Array(repeating: "comer/perfect/yo", count: 6)
            + Array(repeating: "comer/goingTo/yo", count: 4) + ["comer/present/yo", "scene/code"]
        let summary = VerbWorkoutSummary(phraseIDs: ids)
        #expect(summary.past == 7)
        #expect(summary.future == 4)
        #expect(summary.verbs == ["comer", "escribir", "haber", "ir", "trabajar"])
        let focused = VerbWorkoutSummary(phraseIDs: (0..<12).map { "focus/comer/preterite/\($0)" })
        #expect(focused.verbs == ["comer"] && focused.past == 12 && focused.future == 0)
    }

    @Test func focusedSetsAlternateOnlyAfterTwelveCompletedRepsAndResume() throws {
        var state = VerbTrainingState()
        try state.prepare()
        let focus = try #require(state.focusedSet)
        for rep in 0..<12 {
            #expect(state.focusedSet == focus)
            let phrase = try #require(state.phrase)
            #expect(phrase == focus.phrase(rep: rep))
            #expect(state.cloud.count == phrase.words.count + 2)
            for word in phrase.words {
                #expect(try state.choose(word, round: state.roundID, index: state.position))
            }
            state = try JSONDecoder().decode(VerbTrainingState.self, from: JSONEncoder().encode(state))
            try state.prepare()
            if rep < 11 { try state.next(after: state.roundID) }
        }
        #expect(state.setComplete && state.total == 12)
        try state.next(after: state.roundID)
        #expect(!state.isFocused && state.rep == 1)
        for _ in 0..<12 {
            let phrase = try #require(state.phrase)
            #expect(!phrase.id.hasPrefix("focus/"))
            #expect(state.cloud.count == phrase.words.count * 2)
            for word in phrase.words { _ = try state.choose(word, round: state.roundID, index: state.position) }
            if !state.setComplete { try state.next(after: state.roundID) }
        }
        try state.next(after: state.roundID)
        #expect(state.isFocused && state.total == 24 && state.rep == 1)
    }
    @Test func focusedContentIsShortSolvableAndUsesOneConjugationChart() throws {
        for verb in FocusedVerbSet.complements.keys {
            for time in [VerbTime.present, .preterite, .imperfect, .future] {
                let set = FocusedVerbSet(verbID: verb, time: time)
                var firstForm: String?
                for rep in 0..<12 {
                    let phrase = try #require(set.phrase(rep: rep))
                    #expect(VerbCatalogue.phrase(id: phrase.id) == phrase)
                    #expect(phrase.words.count <= 5)
                    #expect(phrase.usedVerbs == [verb])
                    #expect(phrase.verbUses.first?.forms().count == 6)
                    if rep == 0 { firstForm = phrase.words[1] }
                    if rep < 6 {
                        #expect(phrase.words[1].trimmingCharacters(in: .punctuationCharacters) == (firstForm ?? "").trimmingCharacters(in: .punctuationCharacters))
                    }
                    var state = VerbTrainingState(); state.focusedSet = set
                    try state.select(phrase.id)
                    for word in phrase.words { _ = try state.choose(word, round: state.roundID, index: state.position) }
                    #expect(state.finished && state.total == 1)
                }
            }
        }
        #expect(FocusedVerbSet(verbID: "comer", time: .preterite).phrase(rep: 1)?.english == "I ate pasta.")
        #expect(FocusedVerbSet(verbID: "comer", time: .preterite).phrase(rep: 1)?.spanish == "Yo comí pasta.")
    }
    @Test func legacySentenceSetFinishesBeforeSwitchingToFocused() throws {
        var state = VerbTrainingState()
        try state.select("comer/present/yo")
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        object.removeValue(forKey: "focusedSet")
        let data = try JSONSerialization.data(withJSONObject: object)
        var restored = try JSONDecoder().decode(VerbTrainingState.self, from: data)
        try restored.prepare()
        #expect(!restored.isFocused && restored.phraseID == state.phraseID)
    }

    @Test func fullCloudIncludesRepeatedAnswersAndNeverChangesAfterATap() throws {
        var state = VerbTrainingState()
        try state.select("scene/happy")
        let phrase = try #require(state.phrase)
        let cloud = state.cloud
        #expect(cloud.count == phrase.words.count * 2)
        #expect(cloud.filter { $0 == "era" }.count == 2)
        for word in Set(phrase.words) {
            #expect(cloud.filter { $0 == word }.count == phrase.words.filter { $0 == word }.count)
        }
        for word in phrase.words {
            #expect(try state.choose(word, round: state.roundID, index: state.position))
            #expect(state.cloud == cloud)
        }
        #expect(Set(state.usedTiles ?? []).count == phrase.words.count)
    }
    @Test func twelveRepsStartAnotherSetWithoutDroppingTheTrail() throws {
        var state = VerbTrainingState()
        state.history = Array(repeating: "scene/happy", count: 100)
        state.repetitions = ["scene/happy": 100]
        try state.prepare()
        for rep in 1...12 {
            #expect(state.rep == rep)
            let phrase = try #require(state.phrase)
            let round = state.roundID
            #expect(throws: AppFailure.self) { try state.next(after: round) }
            for word in phrase.words { #expect(try state.choose(word, round: round, index: state.position)) }
            #expect(state.rep == rep)
            #expect(state.setComplete == (rep == 12))
            #expect(state.history.count == 100 + rep)
            try state.next(after: round)
            #expect(state.phraseID != phrase.id)
            #expect(throws: AppFailure.self) { try state.next(after: round) }
        }
        #expect(state.rep == 1 && state.total == 112)
        #expect(state.history.count == 112)
    }
    @Test func chartsCoverSupportingVerbsAndEverySceneWithoutGuessingAmbiguousForms() throws {
        let future = try #require(VerbCatalogue.phrase(id: "poder/goingTo/yo"))
        #expect(future.usedVerbs == ["ir", "poder", "leer"])
        #expect(future.verbUses.map { $0.text(in: future) } == ["voy", "poder", "leer"])
        let perfect = try #require(VerbCatalogue.phrase(id: "comer/perfect/yo"))
        #expect(perfect.usedVerbs == ["haber", "comer"])
        #expect(perfect.verbUses.map { $0.text(in: perfect) } == ["he", "comido"])
        let went = try #require(VerbCatalogue.phrase(id: "ir/preterite/yo"))
        #expect(went.usedVerbs == ["ir"])
        let was = try #require(VerbCatalogue.phrase(id: "ser/preterite/yo"))
        #expect(was.usedVerbs == ["ser"])
        for phrase in VerbCatalogue.scenes {
            #expect(!phrase.verbUses.isEmpty)
            for use in phrase.verbUses {
                #expect(use.indices.allSatisfy { phrase.words.indices.contains($0) })
                #expect(use.forms().count == 6)
            }
        }
        #expect(VerbCatalogue.phrase(id: "scene/coffee")?.usedVerbs == ["pedir", "necesitar", "pagar"])
    }
    @Test func everyVerbHasAllSixFormsAndEveryPracticeSentenceIsSolvable() throws {
        #expect(VerbCatalogue.verbs.count == 29)
        #expect(Set(VerbCatalogue.verbs.map(\.id)).count == 29)
        for verb in VerbCatalogue.verbs {
            for time in VerbTime.allCases {
                for slot in 0..<6 {
                    if slot == 0 && (time == .command || time == .negativeCommand) {
                        #expect(verb.form(time, slot: slot) == nil)
                    } else { #expect(verb.form(time, slot: slot)?.isEmpty == false) }
                }
            }
            for time in VerbTime.practice {
                for person in VerbPerson.allCases {
                    let phrase = try #require(verb.phrase(time: time, person: person))
                    #expect(!phrase.english.isEmpty)
                    #expect(!phrase.verbUses.isEmpty)
                    for use in phrase.verbUses {
                        #expect(use.indices.allSatisfy { phrase.words.indices.contains($0) })
                        #expect(use.forms().count == 6)
                    }
                    var state = VerbTrainingState(); try state.select(phrase.id)
                    for word in phrase.words {
                        #expect(state.cloud.contains(word))
                        #expect(try state.choose(word, round: state.roundID, index: state.position))
                        #expect(state.cloud.count == phrase.words.count * 2)
                        #expect(state.usedTiles?.count == state.position)
                    }
                    #expect(state.finished)
                    #expect(state.repetitions[phrase.id] == 1)
                }
            }
        }
    }
    @Test func irregularAndReflexiveFormsHaveIndependentExpectedSpellings() throws {
        let expected: [(String, VerbTime, Int, String)] = [
            ("ir", .preterite, 0, "fui"), ("ir", .future, 0, "iré"), ("comer", .preterite, 2, "comió"),
            ("pagar", .preterite, 0, "pagué"), ("pagar", .subjunctive, 3, "paguemos"),
            ("pedir", .preterite, 5, "pidieron"), ("pedir", .subjunctive, 3, "pidamos"),
            ("conducir", .preterite, 5, "condujeron"), ("hacer", .preterite, 2, "hizo"),
            ("tener", .future, 3, "tendremos"), ("saber", .present, 0, "sé"),
            ("ser", .imperfect, 3, "éramos"), ("ir", .subjunctivePast, 3, "fuéramos"),
            ("escribir", .perfect, 0, "he escrito"), ("decir", .pluperfect, 0, "había dicho"),
            ("portarse", .preterite, 0, "me porté"), ("portarse", .goingTo, 0, "me voy a portar"),
            ("portarse", .command, 1, "pórtate"), ("portarse", .command, 4, "portaos"),
            ("portarse", .negativeCommand, 1, "no te portes"),
            ("comer", .subjunctivePluperfectSe, 3, "hubiésemos comido")]
        for (id, time, slot, form) in expected {
            let verb = try #require(VerbCatalogue.verbs.first { $0.id == id })
            #expect(verb.form(time, slot: slot) == form)
        }
        #expect(VerbCatalogue.phrase(id: "comer/preterite/ella")?.english == "She ate bread with chocolate.")
        #expect(VerbCatalogue.phrase(id: "estar/present/usted")?.english == "You are at home.")
        #expect(VerbCatalogue.phrase(id: "saber/preterite/yo")?.english == "I found out the answer.")
    }
    @Test func scenesAreBilingualAndPlayable() throws {
        for phrase in VerbCatalogue.scenes {
            var state = VerbTrainingState(); try state.select(phrase.id)
            for word in phrase.words { #expect(try state.choose(word, round: state.roundID, index: state.position)) }
            #expect(state.finished)
            #expect(!phrase.english.isEmpty && !phrase.note.isEmpty)
        }
    }
}
