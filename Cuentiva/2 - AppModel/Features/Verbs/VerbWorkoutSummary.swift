//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation

struct VerbWorkoutSummary: Equatable, Sendable {
    let verbs: [String]
    let past: Int
    let future: Int

    init(phraseIDs: [String]) {
        let phrases = phraseIDs.suffix(12).compactMap(VerbCatalogue.phrase)
        verbs = Array(Set(phrases.flatMap(\.usedVerbs))).sorted()
        var pastCount = 0
        var futureCount = 0
        let pastTimes: Set<VerbTime> = [.preterite, .imperfect, .perfect, .pluperfect]
        for phrase in phrases {
            let parts = phrase.id.split(separator: "/").map(String.init)
            let timeIndex = phrase.id.hasPrefix("focus/") ? 2 : 1
            if !phrase.id.hasPrefix("scene/"), parts.indices.contains(timeIndex),
               let time = VerbTime(rawValue: parts[timeIndex]) {
                // Compound expressions such as “había comido” count once.
                if pastTimes.contains(time) { pastCount += 1 }
                if time == .future || time == .goingTo { futureCount += 1 }
            } else {
                for use in phrase.verbUses where !use.baseForm {
                    if pastTimes.contains(use.time) { pastCount += 1 }
                    if use.time == .future || use.time == .goingTo { futureCount += 1 }
                }
            }
        }
        past = pastCount
        future = futureCount
    }
}
