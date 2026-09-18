import CryptoKit
import Foundation

/// Orders an eligible pool without reading storage or changing learner progress.
/// Cache IDs rather than books so callers always receive the current book values.
struct LibraryRecommendationOrder {
    private struct OrderInput: Equatable {
        let ids: [String]
        let personal: Set<String>
        let day: Date
        let recycling: Bool
        let arrivals: [String: Date]
        let lastRead: [String: Date]
        let level: LearningLevel?
    }
    private var previousOrder: OrderInput?
    private var orderedIDs: [String] = []
    private var stableKeys: [String: String] = [:]
    private(set) var buildCount = 0
    mutating func order(
        _ values: [Book], recycling: Bool, today: Date, calendar: Calendar,
        arrivals: [String: Date], lastRead: [String: Date], level: LearningLevel?
    ) -> [Book] {
        guard !values.isEmpty else { return [] }
        let input = OrderInput(
            ids: values.map(\.id), personal: Set(values.filter { $0.personalAuthor != nil }.map(\.id)),
            day: today, recycling: recycling, arrivals: arrivals,
            lastRead: lastRead, level: level)
        let lookup = Dictionary(uniqueKeysWithValues: values.map { ($0.id, $0) })
        if input == previousOrder { return orderedIDs.compactMap { lookup[$0] } }
        let keyed = values.map { book in
            let key: String
            if let cached = stableKeys[book.id] {
                key = cached
            } else {
                key = SHA256.hash(data: Data(book.id.utf8)).map { String(format: "%02x", $0) }.joined()
                stableKeys[book.id] = key
            }
            return (book: book, key: key)
        }
        let base = keyed.sorted {
            $0.key == $1.key ? $0.book.id < $1.book.id : $0.key < $1.key
        }.map(\.book)
        let day =
            calendar.dateComponents([.day], from: calendar.startOfDay(for: Date(timeIntervalSince1970: 0)), to: today)
            .day ?? 0
        let offset = ((day * 3 % base.count) + base.count) % base.count
        let rotated = Array(base[offset...] + base[..<offset])
        let candidates = rotated.enumerated().map { rank, book in
            let arrivalDay = arrivals[book.id].map { calendar.startOfDay(for: $0) }
            let arrivalAge = arrivalDay.flatMap { calendar.dateComponents([.day], from: $0, to: today).day }
            let readAge = lastRead[book.id].flatMap {
                calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: today).day
            }
            return Candidate(
                book: book,
                personal: !recycling && book.personalAuthor != nil,
                arrival: !recycling && (0..<30).contains(arrivalAge ?? -1) ? arrivalDay ?? .distantPast : .distantPast,
                recent: !recycling && (0...3).contains(readAge ?? -1),
                matchesLevel: !recycling && book.level == level?.rawValue,
                rotationRank: rank
            )
        }
        let sorted = candidates.sorted { $0.precedes($1) }.map(\.book)
        previousOrder = input
        orderedIDs = sorted.map(\.id)
        buildCount += 1
        return sorted
    }

    /// Each priority is calculated once. The daily rotation breaks ties consistently.
    private struct Candidate {
        let book: Book
        let personal: Bool
        let arrival: Date
        let recent: Bool
        let matchesLevel: Bool
        let rotationRank: Int

        func precedes(_ other: Candidate) -> Bool {
            if personal != other.personal { return personal }
            if arrival != other.arrival { return arrival > other.arrival }
            if recent != other.recent { return recent }
            if matchesLevel != other.matchesLevel { return matchesLevel }
            return rotationRank < other.rotationRank
        }
    }

}
