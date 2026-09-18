import Foundation
import Observation

@MainActor @Observable final class StatsViewModel {
    private let progress: any ProgressFeature

    init(progress: any ProgressFeature = AppModel.shared.progress) {
        self.progress = progress
    }

    var readerBadges: [ReaderBadge] { progress.snapshot.readerBadges }
    var streak: Int { progress.streak }
    var week: [WeekDay] { progress.week }
    var booksRead: Int { progress.snapshot.completed.count }
    var doubloons: Int { progress.snapshot.doubloons ?? 0 }
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
