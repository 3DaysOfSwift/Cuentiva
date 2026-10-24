import Foundation
import Observation
import UIKit

/// Owns icon selection feedback independently of the storyteller reveal animation.
@MainActor @Observable final class AppIconSettingsViewModel {
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
    var creature: FantasyCreature? { feature.profile?.creature }
    var identity: FantasyIdentity? { feature.profile?.identity }
    init(feature: any FantasyFeature = AppModel.shared.fantasy,
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
        do { try await feature.load() }
        catch { iconMessage = "Your storyteller couldn’t be loaded. Please try again." }
    }
}
