import Foundation
protocol BookRepository: Sendable { func books() async throws -> [Book] }
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
