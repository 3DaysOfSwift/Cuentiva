import Testing
@testable import Cuentiva

@Suite @MainActor struct SlideToStartViewModelTests {
    @Test func partialAndReverseSlidesDoNotConfirm() {
        let model = SlideToStartViewModel()
        var count = 0
        for distance in [0.0, 30, 90, -100] {
            model.finish(translation: distance, travel: 100, rightToLeft: false) { count += 1 }
        }
        #expect(count == 0)
        #expect(!model.confirmed)
        model.finish(translation: 95, travel: 100, rightToLeft: false) { count += 1 }
        model.activate { count += 1 }
        #expect(count == 1)
        #expect(model.confirmed)
    }
    @Test func rightToLeftAndAccessibleActivationConfirmOnce() {
        let model = SlideToStartViewModel()
        var count = 0
        model.finish(translation: -100, travel: 100, rightToLeft: true) { count += 1 }
        #expect(count == 1)
        let accessible = SlideToStartViewModel()
        accessible.activate { count += 1 }
        accessible.activate { count += 1 }
        #expect(count == 2)
    }
}
