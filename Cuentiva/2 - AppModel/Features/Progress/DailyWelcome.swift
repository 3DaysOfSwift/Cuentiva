import Foundation

struct DailyWelcome: Equatable, Sendable {
    let day: String
    let streak: Int
    let practicedToday: Bool
    let returningReader: Bool

    var nextDay: Int { practicedToday ? streak : streak + 1 }
    var startsNewStreak: Bool { streak == 0 && returningReader }
}
