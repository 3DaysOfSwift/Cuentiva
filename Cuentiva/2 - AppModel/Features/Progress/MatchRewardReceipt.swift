import Foundation

struct MatchRewardReceipt: Identifiable, Equatable, Sendable {
    let id = UUID()
    let previousBalance: Int
    let balance: Int
}
