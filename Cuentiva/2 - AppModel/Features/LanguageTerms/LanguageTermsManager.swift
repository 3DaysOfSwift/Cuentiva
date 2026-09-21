//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation

@MainActor protocol LanguageTermsFeature: AnyObject {
    func search(_ query: String) -> [LanguageTerm]
    func term(_ id: String) -> LanguageTerm?
}
@MainActor final class LanguageTermsManager: LanguageTermsFeature {
    func search(_ query: String) -> [LanguageTerm] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.terms.filter { query.isEmpty || "\($0.english) \($0.spanish) \($0.meaning)".localizedStandardContains(query) }
    }
    func term(_ id: String) -> LanguageTerm? { Self.terms.first { $0.id == id } }
    private static let terms: [LanguageTerm] = [
        .init(id: "noun", english: "Noun", spanish: "Sustantivo",
              meaning: "A naming word: a word for a person, place, thing or idea.",
              explanation: "Look around a kitchen. You might see a table, a cup and Ana. Table, cup and Ana are all naming words. The grammar name for a naming word is noun. You can also name something you cannot touch: love or happiness.",
              englishExample: "The **girl** holds a **cup**. Girl names the person. Cup names the thing she holds.",
              spanishExample: "La **niña** tiene una **taza** means “The girl has a cup.” Niña names the girl. Taza names the cup.",
              takeaway: "In “The dog sleeps,” dog is the noun: it names who we are talking about.", related: ["article", "gender", "adjective"]),
        .init(id: "verb", english: "Verb", spanish: "Verbo",
              meaning: "A word that tells us what happens or how someone or something is.",
              explanation: "Picture Ana with a book. Ana reads tells us what she does. Reads is the verb. Now say Ana is tired. Is is also a verb: it tells us how Ana is, even though nothing is moving. Run, eat, know and want are other examples.",
              englishExample: "Ana **reads** a book. Ana **is** tired. Reads tells us what she does; is helps tell us how she is.",
              spanishExample: "Ana **lee** un libro means “Ana reads a book.” Ana **está** cansada means “Ana is tired.” Lee and está do the same jobs as reads and is.",
              takeaway: "Ask: which word tells me what happens, or how things are?", related: ["conjugation", "tense", "lemma"]),
        .init(id: "adjective", english: "Adjective", spanish: "Adjetivo",
              meaning: "A describing word that tells us what someone or something is like.",
              explanation: "Imagine two cups. One is red and one is blue. If you ask for the red cup, red helps someone choose the right one. Red is an adjective. Small, warm and beautiful are describing words too.",
              englishExample: "A **red** cup. A **small** cup. Red tells us its colour. Small tells us its size.",
              spanishExample: "Una taza **roja** means “A red cup.” Una taza **pequeña** means “A small cup.” Roja means red; pequeña means small. Here the describing word comes after taza, the word for cup.",
              takeaway: "The cup is the thing. Red is what we tell someone about that thing.", related: ["noun", "agreement", "gender"]),
        .init(id: "pronoun", english: "Pronoun", spanish: "Pronombre",
              meaning: "A word such as I, you, she or it that points to someone or something.",
              explanation: "Ana has a cup. Ana drinks from the cup. Repeating those names soon sounds clumsy. We can say She drinks from it instead. She points to Ana and it points to the cup. These pointing words are called pronouns.",
              englishExample: "Ana has a cup. **She** drinks from **it**. She means Ana here; it means the cup.",
              spanishExample: "Ana tiene una taza. **Ella** bebe de la taza. This means “Ana has a cup. She drinks from the cup.” Ella means she and points to Ana.",
              takeaway: "To understand she, he, it or they, work out who or what the speaker is pointing to.", related: ["noun", "verb", "conjugation"]),
        .init(id: "adverb", english: "Adverb", spanish: "Adverbio",
              meaning: "A word that adds detail, such as how, when or where something happens.",
              explanation: "Ana walks tells you what happens. Ana walks slowly tells you how it happens. Slowly adds that extra detail: it is an adverb. These words can also strengthen a description. In very small, very tells you how small.",
              englishExample: "Ana walks **slowly**. Slowly tells us how she walks. The cup is **very** small. Very makes small stronger.",
              spanishExample: "Ana camina **despacio** means “Ana walks slowly.” Despacio means slowly. La taza es **muy** pequeña means “The cup is very small.” Muy means very.",
              takeaway: "Compare “a slow walk” with “Ana walks slowly.” Slow describes the walk; slowly tells us how Ana walks.", related: ["adjective", "verb"]),
        .init(id: "article", english: "Article", spanish: "Artículo",
              meaning: "A little word such as a or the that comes before the name of something.",
              explanation: "Imagine several cups on a table. Bring me a cup means any suitable cup will do. Bring me the cup means a particular cup we both know about. A and the are called articles. Spanish uses words such as un, una, el and la for this job.",
              englishExample: "I pick up **a** cup. **The** cup is blue. First I introduce a cup. Then the tells you I mean that same cup.",
              spanishExample: "Cojo **una** taza. **La** taza es azul. This means “I pick up a cup. The cup is blue.” Una does the job of a; la does the job of the.",
              takeaway: "Learn la taza together as “the cup.” It helps you remember which little word belongs with taza.", related: ["noun", "gender", "agreement"]),
        .init(id: "preposition", english: "Preposition", spanish: "Preposición",
              meaning: "A linking word such as in, on or with that shows how things connect.",
              explanation: "Picture a cup and a box. The cup could be in the box or beside the box. In and beside tell you where the cup is in relation to the box. They are prepositions. Other prepositions connect people or times: with Ana, after lunch.",
              englishExample: "The cup is **in** the box. I walk **with** Ana. In tells us where; with tells us who is alongside me.",
              spanishExample: "La taza está **en** la caja means “The cup is in the box.” Camino **con** Ana means “I walk with Ana.” En means in here; con means with.",
              takeaway: "Learn these words in little phrases, such as con Ana: with Ana. One English linking word will not always have the same Spanish translation.", related: ["noun", "article"]),
        .init(id: "conjugation", english: "Conjugation", spanish: "Conjugación",
              meaning: "Changing a word such as walk to walks or walked so it fits what you want to say.",
              explanation: "You say I walk, but she walks. Add an s and the word fits she. Say I walked and the ending tells us it happened before now. Making changes like these is called conjugation. It applies to verbs: words that tell us what happens or how things are.",
              englishExample: "I **walk**. She **walks**. Yesterday I **walked**. We change the word to show who is walking or when it happened.",
              spanishExample: "**Hablo** means “I speak.” **Hablas** means “You speak” when talking to one person informally. **Hablamos** means “We speak.” Here the endings tell us who is speaking.",
              takeaway: "Conjugation is the changing, not the chart. When you choose hablo for “I speak,” you are already doing it.", related: ["verb", "tense", "pronoun", "lemma"]),
        .init(id: "tense", english: "Tense", spanish: "Tiempo verbal",
              meaning: "A way of changing the words in a sentence to show time: before now, now or later.",
              explanation: "I worked tells you the work happened before now. I will work points ahead to later. These different ways of showing time are called tenses. Words such as yesterday and tomorrow help too, but notice that worked and will work already give a time clue.",
              englishExample: "Today I **work**. Yesterday I **worked**. Tomorrow I **will work**. Watch how the words change as the time changes.",
              spanishExample: "Hoy **trabajo** means “Today I work.” Ayer **trabajé** means “Yesterday I worked.” Mañana **trabajaré** means “Tomorrow I will work.” The endings help show the time.",
              takeaway: "Start by asking: is this happening before now, now or later? That is the first clue; the rest of the sentence helps you understand the exact meaning.", related: ["verb", "conjugation"]),
        .init(id: "gender", english: "Grammatical gender", spanish: "Género gramatical",
              meaning: "The two word groups Spanish calls masculine and feminine.",
              explanation: "English says the book and the table. Spanish says el libro and la mesa. Why two words for the? Spanish sorts naming words into groups. Libro belongs to the group called masculine; mesa belongs to the group called feminine. These are grammar labels. A table is not a woman and a book is not a man.",
              englishExample: "**The book**. **The table**. English uses the for both things.",
              spanishExample: "**El libro** means “The book.” **La mesa** means “The table.” For these words, el goes with libro and la goes with mesa.",
              takeaway: "Remember el libro and la mesa as small pairs. Do not try to guess the group from what the object looks like.", related: ["noun", "article", "agreement"]),
        .init(id: "agreement", english: "Agreement", spanish: "Concordancia",
              meaning: "Changing connected words so they match each other.",
              explanation: "Start with one white house. Now imagine several white houses. In Spanish, more than just the word house changes when you say this. The nearby words change too, showing that they all describe the same group. This matching is called agreement.",
              englishExample: "She **walks**. They **walk**. English has matching too: we choose walks with she, but walk with they.",
              spanishExample: "**La casa blanca** means “The white house.” **Las casas blancas** means “The white houses.” La becomes las, casa becomes casas and blanca becomes blancas: all three now fit more than one house.",
              takeaway: "When you change who or what you are talking about, some connected words may need to change with it.", related: ["adjective", "article", "gender", "conjugation"]),
        .init(id: "lemma", english: "Lemma", spanish: "Lema",
              meaning: "The form of a word used as its dictionary heading.",
              explanation: "Imagine you want to know what **“walked”** means. You open a **dictionary** to find out. It may tell you to look under **“walk.”**\n\n**“Walked”** is a version of **“walk”** that tells us the walking happened before now. **“Walks”** and **“walking”** are other versions.\n\nThe dictionary uses **“walk”** as the main heading for these versions. That heading form is called the **lemma**. It gives you one place to look for their shared meaning.",
              englishExample: "I **walk** today. I **walked** yesterday. Same basic action, different time. The dictionary heading is **walk**. So the lemma of walked is walk.",
              spanishExample: "**Hablo** means “I speak.” **Hablas** means “You speak” to one person informally. They both describe speaking. Their dictionary heading is **hablar**, which means “to speak.” So hablar is the lemma of both hablo and hablas.",
              takeaway: "Try “cats”: the dictionary heading is “cat,” so cat is its lemma. A lemma is a word’s lookup form, not its English translation and not a group of words with similar meanings.", related: ["verb", "conjugation", "noun"])
    ]
}
