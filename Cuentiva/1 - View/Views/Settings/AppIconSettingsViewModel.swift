import Foundation
import Observation
import UIKit

/// Owns icon selection feedback independently of the storyteller reveal animation.
@MainActor @Observable final class AppIconSettingsViewModel {
    private let feature: any FantasyFeature
    private let supportsIcons: @MainActor () -> Bool
    private let currentIcon: @MainActor () -> String?
    private let changeIcon: @MainActor (String?) async throws -> Void
    @ObservationIgnored private var iconTask: Task<Void, Never>?
    private(set) var changingIcon = false
    var selectedIcon: String?
    private var loadMessage: String?
    private var changeMessage: String?
    var iconMessage: String? { changeMessage ?? loadMessage }
    private var preparing = false
    var canOfferIcon: Bool { creature != nil && supportsIcons() }
    var usesStorytellerIcon: Bool { creature != nil && selectedIcon == creature?.appIconName }

    @discardableResult
    func useStorytellerIcon() -> Task<Void, Never>? {
        guard let creature, canOfferIcon else { return nil }
        return setIcon(creature.appIconName)
    }

    @discardableResult
    func restorePipaIcon() -> Task<Void, Never>? { setIcon(nil) }

    private func setIcon(_ name: String?) -> Task<Void, Never>? {
        // The controls admit one system change at a time. Once dispatched,
        // observe its outcome even if the presenting screen disappears.
        if let iconTask { return iconTask }
        guard supportsIcons(), currentIcon() != name else { return nil }
        changingIcon = true
        changeMessage = nil
        let task = Task {
            defer { changingIcon = false; iconTask = nil }
            do {
                try Task.checkCancellation()
                try await changeIcon(name)
                selectedIcon = currentIcon()
                changeMessage = name == nil ? "Pipa is back on your Home Screen." : "Your storyteller now welcomes you from your Home Screen."
            } catch is CancellationError {
                // Cancellation before dispatch is not an icon-change failure.
            } catch {
                changeMessage = "Your app icon couldn’t be changed. Please try again."
            }
        }
        iconTask = task
        return task
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
        guard !preparing, !Task.isCancelled else { return }
        preparing = true
        loadMessage = nil
        selectedIcon = currentIcon()
        defer { preparing = false }
        do { try await feature.load() }
        catch {
            guard !Task.isCancelled else { return }
            loadMessage = "Your storyteller couldn’t be loaded. Please try again."
        }
    }
}
