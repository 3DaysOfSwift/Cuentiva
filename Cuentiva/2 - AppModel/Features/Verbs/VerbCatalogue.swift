import Foundation

enum VerbTime: String, Codable, CaseIterable, Identifiable, Sendable {
    case present, preterite, imperfect, future, goingTo, conditional, perfect, pluperfect
    case futurePerfect, conditionalPerfect, subjunctive, subjunctivePast, subjunctivePastSe
    case subjunctivePerfect, subjunctivePluperfect, subjunctivePluperfectSe, command, negativeCommand
    var id: Self { self }
    static let practice: [Self] = [.present, .preterite, .imperfect, .future, .goingTo, .conditional, .perfect, .pluperfect]
    var title: String {
        switch self {
        case .present: "Now / regularly"
        case .preterite: "A finished past action"
        case .imperfect: "Used to / was"
        case .future: "Will"
        case .goingTo: "Going to"
        case .conditional: "Would"
        case .perfect: "Have done"
        case .pluperfect: "Had done"
        case .futurePerfect: "Will have done"
        case .conditionalPerfect: "Would have done"
        case .subjunctive: "Present subjunctive"
        case .subjunctivePast: "Past subjunctive · -ra"
        case .subjunctivePastSe: "Past subjunctive · -se"
        case .subjunctivePerfect: "Have done · subjunctive"
        case .subjunctivePluperfect: "Had done · subjunctive -ra"
        case .subjunctivePluperfectSe: "Had done · subjunctive -se"
        case .command: "Do it · commands"
        case .negativeCommand: "Don’t do it · commands"
        }
    }
    var help: String {
        switch self {
        case .present: "Use this for what happens now or regularly. The ending changes with who does it."
        case .preterite: "See the action as a completed event: I ate, she paid. Some verbs change meaning: supe means I found out; conocí can mean I met."
        case .imperfect: "Describe what used to happen, or the background to a story: I used to work here; I was afraid. It does not set an end point."
        case .future: "Say what will happen: iré means I will go."
        case .goingTo: "Use ir + a + an unchanged verb to say what someone is going to do: voy a comer."
        case .conditional: "Imagine what someone would do: compraría means I would buy."
        case .perfect: "Use haber + a participle to connect an action with now: he comido means I have eaten."
        case .pluperfect: "Describe something already finished before another past moment: había pagado means I had paid."
        case .futurePerfect: "An action will already be finished: habré comido means I will have eaten."
        case .conditionalPerfect: "Imagine an action that would already have happened: habría ido means I would have gone."
        case .subjunctive, .subjunctivePast, .subjunctivePastSe, .subjunctivePerfect, .subjunctivePluperfect, .subjunctivePluperfectSe:
            "These forms fit wishes, doubts and possibilities. Espero que venga means I hope they come. The -ra and -se past forms are alternatives. Learn them inside a full phrase, not as a statement of fact."
        case .command, .negativeCommand: "Give an instruction to someone: come means eat; no comas means don’t eat. There is no command to yo. The third-person slots here address usted and ustedes."
        }
    }
}

enum VerbPerson: String, Codable, CaseIterable, Identifiable, Sendable {
    case yo, tu, el, ella, usted, nosotros, vosotros, ellas, ustedes
    var id: Self { self }
    var spanish: String { self == .tu ? "tú" : self == .el ? "él" : rawValue }
    var english: String {
        switch self { case .yo: "I"; case .tu, .usted, .vosotros, .ustedes: "You"; case .el: "He"; case .ella: "She"; case .nosotros: "We"; case .ellas: "They" }
    }
    var slot: Int {
        switch self { case .yo: 0; case .tu: 1; case .el, .ella, .usted: 2; case .nosotros: 3; case .vosotros: 4; case .ellas, .ustedes: 5 }
    }
    var englishThird: Bool { self == .el || self == .ella }
    var be: String { self == .yo ? "am" : englishThird ? "is" : "are" }
    var was: String { self == .yo || englishThird ? "was" : "were" }
}

struct TrainingVerb: Identifiable, Sendable {
    let id: String
    let english: String
    let third: String
    let past: String
    let englishParticiple: String
    let tail: String
    let englishTail: String
    let participle: String
    let gerund: String
    let reflexive: Bool
    let forms: [VerbTime: [String]]
    var infinitive: String { reflexive ? String(id.dropLast(2)) : id }
    func form(_ time: VerbTime, slot: Int) -> String? {
        guard (0..<6).contains(slot) else { return nil }
        let reflexives = ["me", "te", "se", "nos", "os", "se"]
        if time == .command && reflexive {
            return [nil, "pórtate", "pórtese", "portémonos", "portaos", "pórtense"][slot]
        }
        if time == .negativeCommand {
            guard slot != 0, let word = forms[.subjunctive]?[slot] else { return nil }
            return "no " + (reflexive ? reflexives[slot] + " " : "") + word
        }
        var word: String?
        switch time {
        case .goingTo: word = ["voy", "vas", "va", "vamos", "vais", "van"][slot] + " a " + infinitive
        case .perfect: word = ["he", "has", "ha", "hemos", "habéis", "han"][slot] + " " + participle
        case .pluperfect: word = ["había", "habías", "había", "habíamos", "habíais", "habían"][slot] + " " + participle
        case .futurePerfect: word = ["habré", "habrás", "habrá", "habremos", "habréis", "habrán"][slot] + " " + participle
        case .conditionalPerfect: word = ["habría", "habrías", "habría", "habríamos", "habríais", "habrían"][slot] + " " + participle
        case .subjunctivePerfect: word = ["haya", "hayas", "haya", "hayamos", "hayáis", "hayan"][slot] + " " + participle
        case .subjunctivePluperfectSe: word = ["hubiese", "hubieses", "hubiese", "hubiésemos", "hubieseis", "hubiesen"][slot] + " " + participle
        case .subjunctivePluperfect: word = ["hubiera", "hubieras", "hubiera", "hubiéramos", "hubierais", "hubieran"][slot] + " " + participle
        default: word = forms[time]?[slot]
        }
        guard let word, !word.isEmpty else { return nil }
        return (reflexive ? reflexives[slot] + " " : "") + word
    }
    func phrase(time: VerbTime, person: VerbPerson) -> VerbPhrase? {
        guard VerbTime.practice.contains(time), let conjugation = form(time, slot: person.slot) else { return nil }
        let isBe = id == "ser" || id == "estar"
        let isAble = id == "poder"
        let base = english
        let englishVerb: String
        switch time {
        case .present: englishVerb = isBe ? person.be : isAble ? person.be + " able to" : person.englishThird ? third : base
        case .preterite: englishVerb = isBe ? person.was : isAble ? person.was + " able to" : past
        case .imperfect: englishVerb = "used to " + base
        case .future: englishVerb = "will " + base
        case .goingTo: englishVerb = person.be + " going to " + base
        case .conditional: englishVerb = "would " + base
        case .perfect: englishVerb = (person.englishThird ? "has " : "have ") + englishParticiple
        case .pluperfect: englishVerb = "had " + englishParticiple
        default: return nil
        }
        return VerbPhrase(id: "\(id)/\(time.rawValue)/\(person.rawValue)", verbID: id,
            spanish: "\(person.spanish.capitalized) \(conjugation) \(tail).",
            english: "\(person.english) \(englishVerb) \(englishTail).", note: time.help)
    }
}
struct VerbPhrase: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let verbID: String
    let spanish: String
    let english: String
    let note: String
    var words: [String] { spanish.split(whereSeparator: \.isWhitespace).map(String.init) }
}

enum VerbCatalogue {
    static var verbs: [TrainingVerb] { VerbTables.all }
    static func randomPhrase(excluding previous: String?) -> VerbPhrase? {
        // Authored mixed-verb scenes make up one rep in six on average.
        if Int.random(in: 0..<6) == 0, let scene = scenes.filter({ $0.id != previous }).randomElement() { return scene }
        guard let verb = verbs.randomElement(), let person = VerbPerson.allCases.randomElement() else { return nil }
        let candidates = VerbTime.practice.compactMap { verb.phrase(time: $0, person: person) }.filter { $0.id != previous }
        return candidates.randomElement()
    }
    static func phrase(id: String) -> VerbPhrase? {
        if id.hasPrefix("focus/") { return FocusedVerbSet.phrase(id: id) }
        if let scene = scenes.first(where: { $0.id == id }) { return scene }
        let parts = id.split(separator: "/").map(String.init)
        guard parts.count == 3, let verb = verbs.first(where: { $0.id == parts[0] }),
              let time = VerbTime(rawValue: parts[1]), let person = VerbPerson(rawValue: parts[2]) else { return nil }
        return verb.phrase(time: time, person: person)
    }
    static let scenes: [VerbPhrase] = [
        .init(id: "scene/code", verbID: "trabajar", spanish: "Yo trabajaba escribiendo código y ahora un ordenador escribe código para mí.", english: "I used to work writing code, and now a computer writes code for me.", note: "Trabajaba describes an old routine. Escribe tells us what happens now."),
        .init(id: "scene/baker", verbID: "hacer", spanish: "Cuando trabajaba en la panadería, hacía pan antes del amanecer.", english: "When I used to work at the bakery, I made bread before dawn.", note: "Trabajaba and hacía describe repeated past actions, not one finished event."),
        .init(id: "scene/happy", verbID: "ser", spanish: "Cuando era joven, era feliz con una bicicleta y un libro.", english: "When I was young, I was happy with a bicycle and a book.", note: "Era describes the background to this memory. Joven and feliz work for any gender."),
        .init(id: "scene/fear", verbID: "tener", spanish: "Yo tenía miedo del ratón, pero el ratón tenía miedo de mí.", english: "I was afraid of the mouse, but the mouse was afraid of me.", note: "Spanish uses tener miedo: literally to have fear. Tenía describes how you felt."),
        .init(id: "scene/tired", verbID: "estar", spanish: "Ella estaba cansada de caminar, así que compró una bicicleta.", english: "She was tired of walking, so she bought a bicycle.", note: "Estaba cansada sets the scene; compró is the completed action. Cansada agrees with ella; for él use cansado."),
        .init(id: "scene/pay", verbID: "pagar", spanish: "Pagué solo quinientos pesos por el billete y mañana iré a Oaxaca.", english: "I paid only five hundred pesos for the ticket, and tomorrow I will go to Oaxaca.", note: "Pagué is a finished payment. Iré describes a future trip. Spanish often leaves out yo because the verb ending tells us who."),
        .init(id: "scene/coffee", verbID: "pedir", spanish: "Pedí un café con leche de coco y ahora necesito pagar.", english: "I ordered a coffee with coconut milk, and now I need to pay.", note: "Pedí is past. Necesito is now; pagar stays unchanged after necesito."),
        .init(id: "scene/walk", verbID: "caminar", spanish: "Ayer caminé hasta el gimnasio y mañana iré en bicicleta.", english: "Yesterday I walked to the gym, and tomorrow I will go by bicycle.", note: "Caminé is a finished past walk. Iré en bicicleta means I will go by bicycle.")
    ]
}
