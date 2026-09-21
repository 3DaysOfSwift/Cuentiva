//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Testing
@testable import Cuentiva

@Suite @MainActor struct WritingUnlockedViewModelTests {
    @Test func invitationAdvancesOneScreenAtATimeAndStopsAtCharacterSelection() {
        let model = WritingUnlockedViewModel()
        #expect(model.stage == .announcement)
        model.next()
        #expect(model.stage == .invitation)
        model.next()
        #expect(model.stage == .character)
        model.next()
        #expect(model.stage == .character)
    }
}
