import Foundation
import Observation

struct Contribution: Identifiable, Codable, Sendable, Equatable {
    var id = UUID()
    var title = ""
    var spanish = ""
    var status = "Draft"
    var topicID: String? = nil
    var teachingNote: String? = nil
    var checkedRequirements: [String]? = nil
}
@MainActor protocol ContributionFeature: AnyObject, Sendable {
    var drafts: [Contribution] { get }
    var topics: [TopicRequest] { get }
    var eligible: Bool { get }
    var publishedCount: Int { get }
    func load() async throws
    func save(_ draft: Contribution, submit: Bool) async throws
    func coaching(_ text: String) -> [String]
}
@MainActor @Observable final class ContributionManager: ContributionFeature {
    private(set) var drafts: [Contribution] = []
    private(set) var topics: [TopicRequest] = []
    private let topicRepository: any TopicRequestRepository
    private let repository: any ContributionRepository
    private let purchases: any PurchaseFeature
    private let progress: any ProgressFeature
    private var saving = false
    init(repository: any ContributionRepository, purchases: any PurchaseFeature, progress: any ProgressFeature, topicRepository: any TopicRequestRepository = LocalTopicRequestRepository()) {
        self.repository = repository; self.purchases = purchases; self.progress = progress; self.topicRepository = topicRepository
    }
    // Demo milestone only. This does not represent an assessed CEFR level.
    var eligible: Bool { purchases.hasAccess && progress.snapshot.completed.count >= 1 }
    var publishedCount: Int { drafts.filter { $0.status == "Published" }.count }
    func load() async throws { guard purchases.hasAccess else { throw AppFailure.locked }; let requests = try await topicRepository.requests(); let saved = try await repository.drafts(); topics = requests; drafts = saved }
    func save(_ draft: Contribution, submit: Bool) async throws {
        guard eligible else { throw AppFailure.locked }
        guard !saving else { throw AppFailure.busy }
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppFailure.unavailable("Give your story a title.") }
        if submit && WordComparison.words(draft.spanish).count < 10 { throw AppFailure.unavailable("Write at least ten Spanish words before submitting your demo story.") }
        if let topicID = draft.topicID {
            guard let topic = topics.first(where: { $0.id == topicID }) else { throw AppFailure.unavailable("This topic request is unavailable. Reload before saving.") }
            if submit && !topic.ready(draft) { throw AppFailure.unavailable("Complete the teaching note, self-review checklist, and required form counts before submitting this topic draft.") }
        }
        saving = true; defer { saving = false }
        var saved = draft; saved.status = submit ? "Pending review · local demo" : "Draft"
        try await repository.save(saved)
        drafts.removeAll { $0.id == saved.id }; drafts.append(saved)
    }
    func coaching(_ text: String) -> [String] {
        var tips = ["Keep your own voice. Describe one moment, place, or person in a few short sentences.", "Check verb tense and agreement. Read each sentence aloud before submitting."]
        if text.contains("yo soy de") { tips.append("‘Yo soy de…’ is a useful way to introduce where you come from.") }
        if !text.contains(".") { tips.append("Try ending each complete thought with a full stop.") }
        return tips
    }
}
