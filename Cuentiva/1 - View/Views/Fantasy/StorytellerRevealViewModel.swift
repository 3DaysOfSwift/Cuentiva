import Foundation
import Observation
import UIKit

@MainActor @Observable final class StorytellerRevealViewModel {
    enum Stage { case spinning, slowing, number, creature, details }
    private let feature: any FantasyFeature
    private let supportsIcons: @MainActor () -> Bool
    private let currentIcon: @MainActor () -> String?
    private let changeIcon: @MainActor (String?) async throws -> Void
    var changingIcon = false
    var selectedIcon: String?
    var iconMessage: String?
    var canOfferIcon: Bool { creature != nil && supportsIcons() }
    var usesStorytellerIcon: Bool { creature != nil && selectedIcon == creature?.appIconName }

    func useStorytellerIcon() async {
        guard let creature, canOfferIcon else { return }
        await setIcon(creature.appIconName)
    }

    func restorePipaIcon() async { await setIcon(nil) }

    private func setIcon(_ name: String?) async {
        guard supportsIcons(), !changingIcon, currentIcon() != name else { return }
        changingIcon = true; iconMessage = nil
        defer { changingIcon = false }
        do {
            try await changeIcon(name)
            selectedIcon = currentIcon()
            iconMessage = name == nil ? "Pipa is back on your Home Screen." : "Your storyteller now welcomes you from your Home Screen."
        } catch {
            iconMessage = "Your app icon couldn’t be changed. Please try again."
        }
    }
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
        let identity = feature.profile?.identity ?? creature?.defaultIdentity
        name = identity?.name ?? ""
        biography = identity?.biography ?? ""
        savedMessage = nil; error = nil; stage = .details
    }
    func saveDetails() async {
        guard !busy else { return }
        busy = true; error = nil; savedMessage = nil; defer { busy = false }
        do {
            try await feature.saveIdentity(name: name, biography: biography)
            savedMessage = "Your storyteller is saved on this device."
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

    init(feature: any FantasyFeature,
         supportsIcons: @escaping @MainActor () -> Bool = { UIApplication.shared.supportsAlternateIcons },
         currentIcon: @escaping @MainActor () -> String? = { UIApplication.shared.alternateIconName },
         changeIcon: @escaping @MainActor (String?) async throws -> Void = { try await UIApplication.shared.setAlternateIconName($0) }) {
        self.feature = feature
        self.supportsIcons = supportsIcons
        self.currentIcon = currentIcon
        self.changeIcon = changeIcon
    }

    func prepare() async {
        selectedIcon = currentIcon()
        do {
            try await feature.load()
            await feature.refreshAvailability()
            ready = true
            name = feature.profile?.details?.name ?? ""
            biography = feature.profile?.details?.biography ?? ""
            if identity != nil { editDetails() }
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
    func chooseIconAndEdit() async {
        await useStorytellerIcon()
        if usesStorytellerIcon { editDetails() }
    }
}
