//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import CryptoKit

/// Fictional editorial profiles for the bundled demo; not verified contributors.
struct Author: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let portrait: String
    let introduction: String
    let note: String
    /// Stable within a Monday–Sunday UTC week, with a different lead credit each week.
    /// Rotate a deterministic shuffled baseline so smaller collections cannot repeat by chance.
    static func weeklyOrder(_ authors: [Author], on date: Date) -> [Author] {
        guard authors.count > 1 else { return authors }
        let ordered = authors.sorted {
            let lhs = SHA256.hash(data: Data($0.id.utf8)).map { String(format: "%02x", $0) }.joined()
            let rhs = SHA256.hash(data: Data($1.id.utf8)).map { String(format: "%02x", $0) }.joined()
            return lhs == rhs ? $0.id < $1.id : lhs < rhs
        }
        let week = Int(floor((date.timeIntervalSince1970 - 345_600) / 604_800))
        let offset = ((week % ordered.count) + ordered.count) % ordered.count
        return Array(ordered[offset...] + ordered[..<offset])
    }
    /// Preserve legacy pack IDs while presenting the app's permanent storyteller cast.
    var storyteller: Author {
        if let character = Self.demoProfiles.first(where: { $0.id == id }) { return character }
        return Author(id: id, name: name.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? name,
                      portrait: portrait, introduction: introduction, note: note)
    }
    static let supportedPortraits: Set<String> = Set(["", "AuthorAna", "AuthorLuis", "AuthorMarta"])
        .union(demoProfiles.map(\.portrait))
    static let pipa: Author = .init(id: "marta", name: "Pipa", portrait: "StorytellerPipa", introduction: "A curious lizard with a travel notebook and a talent for finding new paths.", note: "I used to spend my days designing clothes in an office, sketching adventures in the margins of my patterns. Eventually I packed a notebook, tied on my favourite scarf and went looking for the places I had only imagined. In Mexico, I followed the coast to Puerto Escondido, then travelled towards Tabasco, Guatemala and Belize. Every wrong turn gave me something worth writing down.\n\nCosta Rica and Peru led me to Colombia, where I swapped English lessons for Spanish practice. My friends and I made two WhatsApp chats: one for each language. I kept returning to the Spanish one because Argentina was next, and I wanted to arrive ready to talk. I’m still chasing that feeling: a new place, a shared table and enough words to tell someone how I got there.")
    static let demoProfiles: [Author] = [
        .init(id: "ana", name: "Brasa", portrait: "StorytellerBrasa", introduction: "A little dragon with a generous heart and a weakness for café stories.", note: "I’m a little dragon who can warm a coffee cup with one careful breath. The careful part took practice; the café still has a black mark on the ceiling. I spend my mornings near the kitchen, listening to travellers tell stories while the bread rises. A stranger sharing their last pastry interests me much more than a dragon guarding a mountain of gold.\n\nIn the evenings, I turn those little encounters into scenes for our travelling theatre. I play the fearsome creatures, although everyone knows I’m hopeless at being frightening. One day I want to take our show from village to village, collecting recipes, making friends and discovering how many adventures can begin with the words, ‘Is this seat taken?’"),
        .init(id: "luis", name: "Musgo", portrait: "StorytellerMusgo", introduction: "A woodland wizard who finds magic in gardens, family and everyday care.", note: "My home is a crooked cottage where the garden has rather more say than I do. The beans climb my bookshelves, the mint escapes under the gate, and a family of beetles has claimed my best teapot. I’m a woodland wizard, but most days my magic is simply noticing who needs watering, feeding or a little company.\n\nI write about the things families pass down: a recipe, a seed, a promise to come home. Lately, an unfamiliar flower has appeared beside the old forest path. Nobody remembers planting it. I’m packing my spectacles and a picnic to follow its trail, because even a creature who loves staying home needs to find out what is growing beyond the garden wall."),
        pipa,
        .init(id: "credit-fade9533cfe2", name: "Zumi", portrait: "StorytellerZumi", introduction: "A tiny fly with enormous curiosity about work, ideas and how things happen.", note: "Being a tiny fly is excellent for investigating things. I can slip into a watchmaker’s workshop, perch on a pencil and see an invention taking shape before anyone else notices it. Unfortunately, I also ask questions at exactly the wrong moment. If something goes clatter, splash or suddenly starts flying, there is a fair chance I was nearby.\n\nI keep a notebook of experiments that nearly worked. Those are my favourite stories: someone tries, something goes wrong, and a friend helps them try again. My next ambition is to build a little flying library for the creatures who cannot reach the village bookshelves. First I need to solve the problem of books being considerably heavier than flies."),
        .init(id: "credit-53e13e40b11a", name: "Luma", portrait: "StorytellerLuma", introduction: "A gentle moth who follows the light of a good idea.", note: "I’m a moth, so everyone assumes I will follow the brightest light. I prefer the small ones: a lantern outside a lonely house, a candle beside an unfinished letter, the last warm window in a sleeping street. I carry my own lantern on evening walks and write down the quiet things people tell me when the busy part of the day is over.\n\nThere is an abandoned observatory on the hill, and once a month a light appears in its highest window. I want to find out who is keeping it burning. Perhaps they need a visitor. Perhaps they have been waiting for one. I’m bringing tea, spare matches and a notebook with plenty of room for an unexpected friendship."),
        .init(id: "credit-5b644d127a59", name: "Nube", portrait: "StorytellerNube", introduction: "A wandering cloud creature with a pocket full of stories and a playful imagination.", note: "I’m a cloud creature with no talent for staying in one place. A passing breeze can carry me away halfway through breakfast, so I have learned to keep my book tucked firmly beneath my scarf. From above, I watch boats leaving harbours and people hurrying to meet someone. Down on the ground, I ask where they are going and whether they are nervous too.\n\nMy stories are full of departures, muddles and second chances. I sometimes cry a tiny shower when an ending is sad, which is inconvenient for anyone reading beside me. I’m looking for a valley that appears on none of my maps. If I find it, I hope to stay long enough to learn everyone’s name before the wind changes again."),
        .init(id: "credit-4ffea73372fb", name: "Tilo", portrait: "StorytellerTilo", introduction: "A patient tortoise who loves listening to people and bringing their conversations to life.", note: "I’m a tortoise, and I have never arrived anywhere in a hurry. This gives me time to hear the end of a conversation, notice a missing signpost or help someone pick up their shopping. I carry a small collection of plays in my satchel. At village gatherings, I lend out the parts and persuade even the shyest neighbour to read a line.\n\nI love the moment when a rehearsed sentence starts to sound like someone’s own voice. My dream is to take a little theatre along the old river road, stopping wherever there is a willing audience and a patch of shade. We will need a cart, some curtains and a wonderfully patient cast. I suspect the journey will supply all the stories we need."),
        .init(id: "credit-0047224f3651", name: "Mora", portrait: "StorytellerMora", introduction: "A mischievous mushroom sprite who makes words spring into action.", note: "I live beneath a spotted mushroom at the edge of the market garden. I deliver letters, collect curious expressions and occasionally leave a harmless riddle in somebody’s shopping basket. Words are my favourite toys. Change ‘I go’ to ‘I went’ and suddenly a story has a past; change it to ‘I will go’ and we have an adventure to plan.\n\nI write about busy kitchens, confused messengers and promises that become rather difficult to keep. Somewhere beyond the hills is a market where, they say, you can trade a story for anything you need. I’m determined to visit. I have packed three excellent tales and one very doubtful one, which I am saving in case I need to bargain for an umbrella."),
        .init(id: "credit-5f7d24711b1b", name: "Faro", portrait: "StorytellerFaro", introduction: "A curious owl with a map, a satchel and a love of faraway places.", note: "I love a late supper by candlelight. Afterwards, I settle into the rafters of our old barn and write for hours, long after the farm has gone quiet. I’m an owl, so this suits me beautifully. My stories are tall tales of the farmland that gave me a home, and of the forest stretching beyond its boundary.\n\nThey say there are monsters among those trees. At our community bonfires, somebody always claims to have heard enormous footsteps or seen a pair of eyes beside the stream. I listen, make notes and try not to look too delighted. Now I want to follow the woodland paths myself, with my map in my satchel. Perhaps I’ll find a monster. Perhaps I’ll find a neighbour with an excellent story and nobody to tell it to."),
    ]
}
