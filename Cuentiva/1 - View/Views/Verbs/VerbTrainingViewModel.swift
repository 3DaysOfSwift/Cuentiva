import Foundation
import Observation

@MainActor @Observable final class VerbTrainingViewModel {
    private let feature: any VerbTrainingFeature
    private(set) var busy = false
    private(set) var error: String?
    private(set) var feedback: String?
    private(set) var giftCelebrated = false
    var eligible: Bool { feature.eligible }
    var claimed: Bool { feature.claimed }
    var days: Int { feature.practiceDays }
    var state: VerbTrainingState { feature.state }
    var trail: [String] {
        let previous = state.finished ? Array(state.history.dropLast()) : state.history
        return Array(previous.suffix(12).reversed())
    }
    init(feature: any VerbTrainingFeature = AppModel.shared.verbs) { self.feature = feature }
    func openGift() async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do { try await feature.perform(.claimGift); giftCelebrated = true }
        catch { self.error = error.localizedDescription }
    }
    func enterGift() async { giftCelebrated = false; await prepare() }
    func prepare() async {
        guard eligible, claimed, !giftCelebrated else { return }
        await perform(.prepare)
    }
    func next() async { await perform(.next(after: state.phraseID == nil ? nil : state.roundID)) }
    private func perform(_ action: VerbTrainingAction) async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do { try await feature.perform(action); feedback = nil }
        catch { self.error = error.localizedDescription }
    }
    func choose(_ word: String) async {
        guard !busy else { return }
        let round = state.roundID, index = state.position
        busy = true; error = nil
        defer { busy = false }
        do {
            let correct = try await feature.perform(.choose(word, round: round, index: index))
            feedback = correct ? nil : "Try another word to build this sentence."
        } catch { self.error = error.localizedDescription }
    }
}
