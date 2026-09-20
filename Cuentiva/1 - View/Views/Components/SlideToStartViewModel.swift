import Foundation
import Observation

@MainActor @Observable final class SlideToStartViewModel {
    private(set) var confirmed = false

    func finish(translation: CGFloat, travel: CGFloat, rightToLeft: Bool, confirm: () -> Void) {
        let distance = rightToLeft ? -translation : translation
        guard travel > 0, distance >= travel * 0.92 else { return }
        activate(confirm: confirm)
    }
    func activate(confirm: () -> Void) {
        guard !confirmed else { return }
        confirmed = true
        confirm()
    }
}
