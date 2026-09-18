import Foundation
protocol BookRepository: Sendable {
    func books() async throws -> [Book]
    func authors() async -> [Author]
    func arrivals() async -> [String: Date]
}
extension BookRepository {
    func arrivals() async -> [String: Date] { [:] }
    func authors() async -> [Author] { Author.demoProfiles } }
protocol ProgressRepository: Sendable {
    func load() async throws -> LearnerProgress
    func save(_ progress: LearnerProgress) async throws
}
protocol ContributionRepository: Sendable {
    func drafts() async throws -> [Contribution]
    func remove(_ id: UUID) async throws
    func save(_ draft: Contribution) async throws
}

protocol TopicRequestRepository: Sendable {
    func requests() async throws -> [TopicRequest]
}
