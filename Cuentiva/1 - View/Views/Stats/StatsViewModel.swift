//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Observation

@MainActor @Observable final class StatsViewModel {
    private let progress: any ProgressFeature

    init(progress: any ProgressFeature = AppModel.shared.progress) {
        self.progress = progress
    }

    func daysPractised(inLast days: Int, now: Date = .now, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return 0 }
        return progress.snapshot.practiceDays.compactMap(Self.date).filter { $0 >= start && $0 <= today }.count
    }
    var exposedWords: Int { progress.snapshot.seenWords?.count ?? 0 }
    var exposureHistory: [ExposurePoint] {
        (progress.snapshot.wordExposureHistory ?? [:]).compactMap { key, value in
            Self.date(key).map { ExposurePoint(date: $0, count: value) }
        }.sorted { $0.date < $1.date }
    }
    private static func date(_ key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: key)
    }
    var readerBadges: [ReaderBadge] { progress.snapshot.readerBadges }
    var streak: Int { progress.streak }
    var week: [WeekDay] { progress.week }
    var booksRead: Int { progress.snapshot.completed.count }
    var doubloons: Int { progress.snapshot.availableChatCoins }
    var practiceDays: Int { progress.snapshot.practiceDays.count }
    var firstPractice: Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return progress.snapshot.practiceDays.compactMap { formatter.date(from: $0) }.min()
    }
}

struct ExposurePoint: Identifiable {
    let date: Date
    let count: Int
    var id: Date { date }
}
