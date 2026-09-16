import Foundation
import Observation
@MainActor @Observable final class ContributionViewModel {
    private let feature: any ContributionFeature
    var draft = Contribution()
    var tips: [String] = []
    var error: String?
    var notice: String?
    var busy = false
    var preview = false
    var eligible: Bool { feature.eligible }
    var drafts: [Contribution] { feature.drafts }
    var count: Int { feature.publishedCount }
    init(feature: any ContributionFeature = AppModel.shared.contributions) { self.feature = feature }
    func load() async { do { try await feature.load() } catch { self.error = error.localizedDescription } }
    func coach() { tips = feature.coaching(draft.spanish) }
    func save(submit: Bool) async {
        busy = true; defer { busy = false }; error = nil; notice = nil
        do { try await feature.save(draft, submit: submit); notice = submit ? "Saved for review on this device. Nothing has been uploaded." : "Draft saved on this device." }
        catch { self.error = error.localizedDescription }
    }
    func edit(_ value: Contribution) { draft = value; notice = nil; tips = [] }
}
