//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation

struct VerbUse: Identifiable, Sendable {
    let lemma: String
    let time: VerbTime
    let indices: [Int]
    var baseForm = false
    var explanation: String? = nil
    var id: String { lemma + indices.map(String.init).joined(separator: "-") }
    func text(in phrase: VerbPhrase) -> String {
        indices.compactMap { phrase.words.indices.contains($0) ? phrase.words[$0].trimmingCharacters(in: .punctuationCharacters) : nil }.joined(separator: " ")
    }
    func forms() -> [String] {
        if let verb = VerbCatalogue.verbs.first(where: { $0.id == lemma }) {
            return (0..<6).map { verb.form(time, slot: $0) ?? "—" }
        }
        // Supporting verbs used in the existing sentences, not guessed from text.
        if lemma == "haber" {
            return time == .imperfect ? ["había", "habías", "había", "habíamos", "habíais", "habían"] : ["he", "has", "ha", "hemos", "habéis", "han"]
        }
        if lemma == "leer" { return ["leo", "lees", "lee", "leemos", "leéis", "leen"] }
        return []
    }
}
extension VerbPhrase {
    var verbUses: [VerbUse] {
        if id.hasPrefix("focus/") {
            let parts = id.split(separator: "/").map(String.init)
            guard parts.count == 4, let time = VerbTime(rawValue: parts[2]) else { return [] }
            return [.init(lemma: verbID, time: time, indices: [1])]
        }
        if id.hasPrefix("scene/") { return sceneUses }
        let parts = id.split(separator: "/").map(String.init)
        guard parts.count == 3, let time = VerbTime(rawValue: parts[1]), let person = VerbPerson(rawValue: parts[2]),
              let verb = VerbCatalogue.verbs.first(where: { $0.id == verbID }), let form = verb.form(time, slot: person.slot) else { return [] }
        let count = form.split(separator: " ").count
        let start = verb.reflexive ? 2 : 1
        var uses: [VerbUse]
        switch time {
        case .goingTo:
            uses = [.init(lemma: "ir", time: .present, indices: [start]),
                    .init(lemma: verbID, time: .present, indices: [start + 2], baseForm: true,
                          explanation: "After ir + a, use the unchanged base verb. The chart below shows its present forms.")]
        case .perfect, .pluperfect:
            uses = [.init(lemma: "haber", time: time == .perfect ? .present : .imperfect, indices: [start]),
                    .init(lemma: verbID, time: time, indices: [start + 1], explanation: "This participle works with haber to form the completed-action expression.")]
        default: uses = [.init(lemma: verbID, time: time, indices: Array(1...count))]
        }
        if verbID == "trabajar" { uses.append(.init(lemma: "escribir", time: .present, indices: [count + 1], explanation: "Escribiendo means writing. The chart shows the related present forms.")) }
        if verbID == "necesitar" || verbID == "poder" {
            uses.append(.init(lemma: verbID == "necesitar" ? "pagar" : "leer", time: .present, indices: [count + 1], baseForm: true,
                              explanation: "This base verb stays unchanged after the first verb. The chart shows its present forms."))
        }
        return uses
    }
    var usedVerbs: [String] { verbUses.reduce(into: []) { if !$0.contains($1.lemma) { $0.append($1.lemma) } } }
    private var sceneUses: [VerbUse] {
        switch id {
        case "scene/code": [
            .init(lemma: "trabajar", time: .imperfect, indices: [1]),
            .init(lemma: "escribir", time: .present, indices: [2], explanation: "Escribiendo means writing; escribe is the present form for he, she or it."),
            .init(lemma: "escribir", time: .present, indices: [8])]
        case "scene/baker": [.init(lemma: "trabajar", time: .imperfect, indices: [1]), .init(lemma: "hacer", time: .imperfect, indices: [5])]
        case "scene/happy": [.init(lemma: "ser", time: .imperfect, indices: [1]), .init(lemma: "ser", time: .imperfect, indices: [3])]
        case "scene/fear": [.init(lemma: "tener", time: .imperfect, indices: [1]), .init(lemma: "tener", time: .imperfect, indices: [8])]
        case "scene/tired": [.init(lemma: "estar", time: .imperfect, indices: [1]), .init(lemma: "caminar", time: .present, indices: [4], baseForm: true), .init(lemma: "comprar", time: .preterite, indices: [7])]
        case "scene/pay": [.init(lemma: "pagar", time: .preterite, indices: [0]), .init(lemma: "ir", time: .future, indices: [9])]
        case "scene/coffee": [.init(lemma: "pedir", time: .preterite, indices: [0]), .init(lemma: "necesitar", time: .present, indices: [9]), .init(lemma: "pagar", time: .present, indices: [10], baseForm: true)]
        case "scene/walk": [.init(lemma: "caminar", time: .preterite, indices: [1]), .init(lemma: "ir", time: .future, indices: [7])]
        default: []
        }
    }
}
