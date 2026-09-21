//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation

/// Authored short complements keep a focused set grammatical and conversational.
struct FocusedVerbSet: Codable, Equatable, Sendable {
    let verbID: String
    let time: VerbTime
    static let complements: [String: [(String, String)]] = [
        "comer": [("", ""), ("pasta", "pasta"), ("pan", "bread")],
        "beber": [("", ""), ("agua", "water"), ("vino tinto", "red wine")],
        "ir": [("", ""), ("al café", "to the café"), ("a casa", "home")],
        "pedir": [("vino", "wine"), ("un café", "a coffee"), ("pasta", "pasta")],
        "pagar": [("", ""), ("la cuenta", "the bill"), ("quinientos pesos", "five hundred pesos")],
        "comprar": [("pan", "bread"), ("pasta", "pasta"), ("un billete", "a ticket")],
        "querer": [("agua", "water"), ("un café", "a coffee"), ("pan", "bread")]
    ]
    static func random() -> Self? {
        guard let verb = complements.keys.sorted().randomElement(),
              let time = [VerbTime.present, verb == "querer" ? .imperfect : .preterite, .future].randomElement() else { return nil }
        return Self(verbID: verb, time: time)
    }
    func phrase(rep: Int) -> VerbPhrase? {
        guard (0..<12).contains(rep), let tails = Self.complements[verbID],
              let verb = VerbCatalogue.verbs.first(where: { $0.id == verbID }) else { return nil }
        let people: [VerbPerson] = [.yo, .yo, .yo, .yo, .yo, .yo, .el, .ella, .nosotros, .tu, .ustedes, .ella]
        let person = people[rep]
        guard let full = verb.phrase(time: time, person: person), let form = verb.form(time, slot: person.slot) else { return nil }
        let tail = tails[rep % tails.count]
        let englishStem = String(full.english.dropLast(verb.englishTail.count + 2))
        return VerbPhrase(id: "focus/\(verbID)/\(time.rawValue)/\(rep)", verbID: verbID,
            spanish: person.spanish.capitalized + " " + form + (tail.0.isEmpty ? "" : " " + tail.0) + ".",
            english: englishStem + (tail.1.isEmpty ? "" : " " + tail.1) + ".", note: time.help)
    }
    static func phrase(id: String) -> VerbPhrase? {
        let parts = id.split(separator: "/").map(String.init)
        guard parts.count == 4, parts[0] == "focus", let time = VerbTime(rawValue: parts[2]),
              let rep = Int(parts[3]), [.present, .preterite, .imperfect, .future].contains(time) else { return nil }
        return Self(verbID: parts[1], time: time).phrase(rep: rep)
    }
}
