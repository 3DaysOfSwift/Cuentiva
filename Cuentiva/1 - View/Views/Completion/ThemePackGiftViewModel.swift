import Foundation
import Observation

@MainActor @Observable final class ThemePackGiftViewModel {
    let pack: ThemePack
    private let progress: any ProgressFeature
    var opened = false
    private(set) var installing = false
    private(set) var error: String?
    var installed: Bool { progress.snapshot.hasInstalled(pack) }

    init(pack: ThemePack, progress: any ProgressFeature = AppModel.shared.progress) {
        self.pack = pack
        self.progress = progress
    }
    func install(keeping theme: ThemeManager) async {
        guard !installing else { return }
        let currentTheme = theme.selectedTheme
        installing = true
        error = nil
        defer { installing = false }
        do {
            try await progress.installThemePack(pack)
            theme.selectedTheme = currentTheme
        }
        catch { self.error = error.localizedDescription }
    }
}
