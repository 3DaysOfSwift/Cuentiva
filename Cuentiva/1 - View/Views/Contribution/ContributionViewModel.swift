import Foundation
import Observation
@MainActor @Observable final class ContributionViewModel {
    private let feature: any ContributionFeature
    var draft = Contribution()
    var confirmingRemoval = false
    func removeDraft() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { try await feature.remove(draft.id); edit(Contribution()); notice = "Story and submission location removed from this device." }
        catch { self.error = error.localizedDescription }
    }
    func requestSubmission() async {
        guard !busy else { return }
        await save(submit: true)
    }
    var tips: [String] = []
    var error: String?
    var notice: String?
    var busy = false
    var preview = false
    var browsingTopics = false
    var topicQuery = ""
    var outstandingOnly = true
    var selectedTopic: TopicRequest? { feature.topics.first { $0.id == draft.topicID } }
    var topics: [TopicRequest] {
        feature.topics.filter { (!outstandingOnly || !$0.covered) && (topicQuery.isEmpty || "\($0.title) \($0.category)".localizedStandardContains(topicQuery)) }
    }
    var teachingNote: String { get { draft.teachingNote ?? "" } set { draft.teachingNote = newValue } }
    func checked(_ requirement: String) -> Bool { draft.checkedRequirements?.contains(requirement) == true }
    func setChecked(_ requirement: String, value: Bool) {
        var values = Set(draft.checkedRequirements ?? [])
        if value { values.insert(requirement) } else { values.remove(requirement) }
        draft.checkedRequirements = values.sorted()
    }
    func topicStatus(_ topic: TopicRequest) -> String? { drafts.first { $0.topicID == topic.id }?.status }
    private func preserveCurrentDraft() async throws {
        guard !draft.title.isEmpty || !draft.spanish.isEmpty || !(draft.teachingNote ?? "").isEmpty else { return }
        if let existing = drafts.first(where: { $0.id == draft.id }) {
            var comparable = draft; comparable.status = existing.status
            if comparable == existing { return }
        }
        var saved = draft
        if saved.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { saved.title = "Untitled draft" }
        try await feature.save(saved, submit: false)
    }
    func choose(_ topic: TopicRequest) async {
        guard !busy else { return }; busy = true; defer { busy = false }; error = nil
        do {
            try await preserveCurrentDraft()
            if let existing = drafts.first(where: { $0.topicID == topic.id }) { edit(existing) }
            else {
                var value = Contribution(); value.title = topic.title; value.topicID = topic.id
                try await feature.save(value, submit: false); edit(value)
            }
            browsingTopics = false
        } catch { self.error = error.localizedDescription }
    }
    func freestyle() async {
        guard !busy else { return }; busy = true; defer { busy = false }; error = nil
        do { try await preserveCurrentDraft(); edit(Contribution()); browsingTopics = false }
        catch { self.error = error.localizedDescription }
    }
    var eligible: Bool { feature.eligible }
    var drafts: [Contribution] { feature.drafts }
    var count: Int { feature.publishedCount }
    init(feature: any ContributionFeature = AppModel.shared.contributions) { self.feature = feature }
    func load() async { do { try await feature.load() } catch { self.error = error.localizedDescription } }
    func coach() { tips = feature.coaching(draft.spanish); if let topic = selectedTopic { tips.insert(topic.brief, at: 0); tips.append("Explain the examples in your own words: teaching is part of your learning.") } }
    func save(submit: Bool) async {
        busy = true; defer { busy = false }; error = nil; notice = nil
        do { try await feature.save(draft, submit: submit); if let saved = feature.drafts.first(where: { $0.id == draft.id }) { draft = saved }; notice = submit ? "Saved for review on this device. Nothing has been uploaded." : "Draft saved on this device." }
        catch { self.error = error.localizedDescription }
    }
    func edit(_ value: Contribution) { draft = value; notice = nil; tips = []; preview = false; browsingTopics = false }
}
