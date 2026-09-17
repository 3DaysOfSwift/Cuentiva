import Foundation
import Observation

@MainActor @Observable final class StorytellerRevealViewModel {
    enum Stage { case spinning, slowing, number, creature, details, identity }
    private let feature: any FantasyFeature
    var stage: Stage = .spinning
    var number = 1
    var name = ""
    var biography = ""
    var busy = false
    var ready = false
    var error: String?
    var savedMessage: String?
    var canSaveDetails: Bool {
        !busy && ready && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !biography.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    func editDetails() {
        name = feature.profile?.details?.name ?? ""
        biography = feature.profile?.details?.biography ?? ""
        savedMessage = nil; error = nil; stage = .details
    }
    func saveDetails() async {
        guard !busy else { return }
        busy = true; error = nil; savedMessage = nil; defer { busy = false }
        do {
            try await feature.saveDetails(name: name, biography: biography)
            savedMessage = "Your name and bio are saved on this device. You can reveal your fantasy storyteller later."
        } catch { self.error = error.localizedDescription }
    }
    var confettiStart: Date?
    var availabilityMessage: String? { feature.availabilityMessage }
    func refreshAvailability() async { await feature.refreshAvailability() }
    func finish() async -> Bool {
        do { try await feature.finishIntroduction(); return true }
        catch { self.error = error.localizedDescription; return false }
    }
    var creature: FantasyCreature? { feature.profile?.creature }
    var identity: FantasyIdentity? { feature.profile?.identity }

    init(feature: any FantasyFeature) { self.feature = feature }

    func prepare() async {
        do {
            try await feature.load()
            await feature.refreshAvailability()
            ready = true
            name = feature.profile?.details?.name ?? ""
            biography = feature.profile?.details?.biography ?? ""
            if identity != nil { stage = .identity }
            else if let creature { number = feature.profile?.revealNumber ?? creature.rawValue; stage = feature.profile?.details == nil ? .creature : .details }
        } catch { self.error = error.localizedDescription }
    }
    func animateNumbers() async {
        do {
            while stage == .spinning {
                number = Int.random(in: 1...999)
                try await Task.sleep(for: .milliseconds(75))
            }
        } catch { }
    }
    func choose() async {
        guard ready, stage == .spinning, !busy else { return }
        busy = true; error = nil; stage = .slowing
        defer { busy = false }
        do {
            // 15 steps, progressively slower, total duration exactly three seconds.
            for step in 0..<15 {
                number = Int.random(in: 1...999)
                try await Task.sleep(for: .milliseconds(60 + step * 20))
            }
            let chosen = try await feature.drawCreature()
            number = feature.profile?.revealNumber ?? chosen.rawValue; stage = .number
            try await Task.sleep(for: .milliseconds(450))
            stage = .creature; confettiStart = Date().addingTimeInterval(-0.65)
        } catch is CancellationError {
            stage = creature == nil ? .spinning : .creature
        } catch {
            self.error = error.localizedDescription; stage = .spinning
        }
    }
    func generateIdentity() async {
        guard !busy else { return }
        busy = true; error = nil; defer { busy = false }
        do {
            try await feature.saveDetails(name: name, biography: biography)
            try await feature.createIdentity(name: name, biography: biography)
            name = ""; biography = "" // Clear the form; saved details remain editable.
            stage = .identity; confettiStart = Date().addingTimeInterval(-0.65)
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}
