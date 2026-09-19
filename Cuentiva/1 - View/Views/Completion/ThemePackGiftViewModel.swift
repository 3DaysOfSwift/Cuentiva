import Foundation
import Observation

@MainActor @Observable final class ThemePackGiftViewModel {
    let pack: ThemePack
    private let progress: any ProgressFeature
    private let pause: (Duration) async throws -> Void
    var opened = false
    var previewTheme: ColourThemeID?
    var installationRequested = false
    private(set) var installing = false
    private(set) var installationConfirmed = false
    private(set) var shouldDismiss = false
    private(set) var error: String?
    var installed: Bool { progress.snapshot.hasInstalled(pack) }
    var canInstall: Bool {
        guard let previewTheme else { return false }
        return pack.themes.contains(previewTheme) && !installing && !installationConfirmed
    }

    init(
        pack: ThemePack,
        progress: any ProgressFeature = AppModel.shared.progress,
        pause: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.pack = pack
        self.progress = progress
        self.pause = pause
    }

    func install(using theme: ThemeManager) async {
        guard canInstall, let selected = previewTheme else { return }
        installing = true
        error = nil
        defer {
            installing = false
            installationRequested = false
        }
        do {
            try await progress.installThemePack(pack)
            theme.selectedTheme = selected
            try await pause(.seconds(1))
            try Task.checkCancellation()
            installationConfirmed = true
            // Leave the confirmation visible long enough to register before closing.
            try await pause(.milliseconds(800))
            try Task.checkCancellation()
            shouldDismiss = true
        } catch is CancellationError {
            // The committed pack/theme remain saved if the presentation goes away.
        } catch {
            self.error = error.localizedDescription
        }
    }
}
