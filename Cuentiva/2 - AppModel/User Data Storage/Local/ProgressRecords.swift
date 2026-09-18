import Foundation

/// Fine-grained records allow a sentence advance to change only affected fields.
/// Optional collection markers preserve legacy nil-versus-empty semantics.
enum ProgressRecords {
    static func encode(_ value: LearnerProgress, previous: LearnerProgress? = nil, existing: [String: Data] = [:])
        throws -> [String: Data]
    {
        var rows = existing
        if previous == nil || previous?.schemaVersion != value.schemaVersion {
            rows["schemaVersion"] = try RecordCoding.encode(value.schemaVersion)
        }
        if previous == nil || previous?.selectedLearningLevel != value.selectedLearningLevel {
            rows["selectedLearningLevel"] = try RecordCoding.encode(value.selectedLearningLevel)
        }
        if previous == nil || previous?.completed != value.completed {
            try set("completed", value.completed, previous?.completed ?? [], into: &rows)
        }
        if previous == nil || previous?.attempts != value.attempts {
            try map("attempts", value.attempts, previous?.attempts ?? [:], into: &rows)
        }
        if previous == nil || previous?.bookArrivals != value.bookArrivals {
            rows["bookArrivals"] = try RecordCoding.encode(value.bookArrivals != nil)
            try map("bookArrivals", value.bookArrivals ?? [:], previous?.bookArrivals ?? [:], into: &rows)
        }
        if previous == nil || previous?.bookLastRead != value.bookLastRead {
            rows["bookLastRead"] = try RecordCoding.encode(value.bookLastRead != nil)
            try map("bookLastRead", value.bookLastRead ?? [:], previous?.bookLastRead ?? [:], into: &rows)
        }
        if previous == nil || previous?.dailyReadingDate != value.dailyReadingDate {
            rows["dailyReadingDate"] = try RecordCoding.encode(value.dailyReadingDate)
        }
        if previous == nil || previous?.dailyReadingIDs != value.dailyReadingIDs {
            rows["dailyReadingIDs"] = try RecordCoding.encode(value.dailyReadingIDs)
        }
        if previous == nil || previous?.positions != value.positions {
            try map("positions", value.positions, previous?.positions ?? [:], into: &rows)
        }
        if previous == nil || previous?.practiceDays != value.practiceDays {
            try set("practiceDays", value.practiceDays, previous?.practiceDays ?? [], into: &rows)
        }
        if previous == nil || previous?.vocabulary != value.vocabulary {
            try map("vocabulary", value.vocabulary, previous?.vocabulary ?? [:], into: &rows)
        }
        if previous == nil || previous?.seenWords != value.seenWords {
            rows["seenWords"] = try RecordCoding.encode(value.seenWords != nil)
            try set("seenWords", value.seenWords ?? [], previous?.seenWords ?? [], into: &rows)
        }
        if previous == nil || previous?.wordHistoryComplete != value.wordHistoryComplete {
            rows["wordHistoryComplete"] = try RecordCoding.encode(value.wordHistoryComplete)
        }
        if previous == nil || previous?.bookWordBaselines != value.bookWordBaselines {
            rows["bookWordBaselines"] = try RecordCoding.encode(value.bookWordBaselines != nil)
            try map(
                "bookWordBaselines", value.bookWordBaselines ?? [:], previous?.bookWordBaselines ?? [:], into: &rows)
        }
        if previous == nil || previous?.celebratedCompletionDays != value.celebratedCompletionDays {
            rows["celebratedCompletionDays"] = try RecordCoding.encode(value.celebratedCompletionDays != nil)
            try set(
                "celebratedCompletionDays", value.celebratedCompletionDays ?? [],
                previous?.celebratedCompletionDays ?? [], into: &rows)
        }
        if previous == nil || previous?.rewardedBooks != value.rewardedBooks {
            rows["rewardedBooks"] = try RecordCoding.encode(value.rewardedBooks != nil)
            try set("rewardedBooks", value.rewardedBooks ?? [], previous?.rewardedBooks ?? [], into: &rows)
        }
        if previous == nil || previous?.bestMatches != value.bestMatches {
            rows["bestMatches"] = try RecordCoding.encode(value.bestMatches != nil)
            try map("bestMatches", value.bestMatches ?? [:], previous?.bestMatches ?? [:], into: &rows)
        }
        if previous == nil || previous?.doubloons != value.doubloons {
            rows["doubloons"] = try RecordCoding.encode(value.doubloons)
        }
        if previous == nil || previous?.evidence != value.evidence {
            try map("evidence", value.evidence, previous?.evidence ?? [:], into: &rows)
        }
        return rows
    }
    private static func map<T: Codable & Equatable>(
        _ name: String, _ current: [String: T], _ old: [String: T], into rows: inout [String: Data]
    ) throws {
        for key in old.keys where current[key] == nil { rows.removeValue(forKey: name + "/" + key) }
        for (key, value) in current where old[key] != value { rows[name + "/" + key] = try RecordCoding.encode(value) }
    }
    private static func set(_ name: String, _ current: Set<String>, _ old: Set<String>, into rows: inout [String: Data])
        throws
    {
        for key in old.subtracting(current) { rows.removeValue(forKey: name + "/" + key) }
        for key in current.subtracting(old) { rows[name + "/" + key] = try RecordCoding.encode(true) }
    }
    static func decode(_ rows: [String: Data]) throws -> LearnerProgress {
        guard rows["schemaVersion"] != nil else {
            throw AppFailure.unavailable("Your progress records are incomplete.")
        }
        var value = LearnerProgress()
        if let data = rows["schemaVersion"] {
            value.schemaVersion = try RecordCoding.decode(type(of: value.schemaVersion), data)
        }
        if let data = rows["selectedLearningLevel"] {
            value.selectedLearningLevel = try RecordCoding.decode(type(of: value.selectedLearningLevel), data)
        }
        for (key, data) in rows where key.hasPrefix("completed/") {
            if try RecordCoding.decode(Bool.self, data) { value.completed.insert(String(key.dropFirst(10))) }
        }
        for (key, data) in rows where key.hasPrefix("attempts/") {
            value.attempts[String(key.dropFirst(9))] = try RecordCoding.decode(Set<String>.self, data)
        }
        if let marker = rows["bookArrivals"], try RecordCoding.decode(Bool.self, marker) { value.bookArrivals = [:] }
        for (key, data) in rows where key.hasPrefix("bookArrivals/") {
            value.bookArrivals?[String(key.dropFirst(13))] = try RecordCoding.decode(Date.self, data)
        }
        if let marker = rows["bookLastRead"], try RecordCoding.decode(Bool.self, marker) { value.bookLastRead = [:] }
        for (key, data) in rows where key.hasPrefix("bookLastRead/") {
            value.bookLastRead?[String(key.dropFirst(13))] = try RecordCoding.decode(Date.self, data)
        }
        if let data = rows["dailyReadingDate"] {
            value.dailyReadingDate = try RecordCoding.decode(type(of: value.dailyReadingDate), data)
        }
        if let data = rows["dailyReadingIDs"] {
            value.dailyReadingIDs = try RecordCoding.decode(type(of: value.dailyReadingIDs), data)
        }
        for (key, data) in rows where key.hasPrefix("positions/") {
            value.positions[String(key.dropFirst(10))] = try RecordCoding.decode(Int.self, data)
        }
        for (key, data) in rows where key.hasPrefix("practiceDays/") {
            if try RecordCoding.decode(Bool.self, data) { value.practiceDays.insert(String(key.dropFirst(13))) }
        }
        for (key, data) in rows where key.hasPrefix("vocabulary/") {
            value.vocabulary[String(key.dropFirst(11))] = try RecordCoding.decode(VocabularyState.self, data)
        }
        if let marker = rows["seenWords"], try RecordCoding.decode(Bool.self, marker) { value.seenWords = [] }
        for (key, data) in rows where key.hasPrefix("seenWords/") {
            if try RecordCoding.decode(Bool.self, data) { value.seenWords?.insert(String(key.dropFirst(10))) }
        }
        if let data = rows["wordHistoryComplete"] {
            value.wordHistoryComplete = try RecordCoding.decode(type(of: value.wordHistoryComplete), data)
        }
        if let marker = rows["bookWordBaselines"], try RecordCoding.decode(Bool.self, marker) {
            value.bookWordBaselines = [:]
        }
        for (key, data) in rows where key.hasPrefix("bookWordBaselines/") {
            value.bookWordBaselines?[String(key.dropFirst(18))] = try RecordCoding.decode(Set<String>.self, data)
        }
        if let marker = rows["celebratedCompletionDays"], try RecordCoding.decode(Bool.self, marker) {
            value.celebratedCompletionDays = []
        }
        for (key, data) in rows where key.hasPrefix("celebratedCompletionDays/") {
            if try RecordCoding.decode(Bool.self, data) {
                value.celebratedCompletionDays?.insert(String(key.dropFirst(25)))
            }
        }
        if let marker = rows["rewardedBooks"], try RecordCoding.decode(Bool.self, marker) { value.rewardedBooks = [] }
        for (key, data) in rows where key.hasPrefix("rewardedBooks/") {
            if try RecordCoding.decode(Bool.self, data) { value.rewardedBooks?.insert(String(key.dropFirst(14))) }
        }
        if let marker = rows["bestMatches"], try RecordCoding.decode(Bool.self, marker) { value.bestMatches = [:] }
        for (key, data) in rows where key.hasPrefix("bestMatches/") {
            value.bestMatches?[String(key.dropFirst(12))] = try RecordCoding.decode(Int.self, data)
        }
        if let data = rows["doubloons"] { value.doubloons = try RecordCoding.decode(type(of: value.doubloons), data) }
        for (key, data) in rows where key.hasPrefix("evidence/") {
            value.evidence[String(key.dropFirst(9))] = try RecordCoding.decode(Int.self, data)
        }
        guard value.schemaVersion == 1 else { throw AppFailure.unavailable("Unsupported progress version.") }
        return value
    }
}
