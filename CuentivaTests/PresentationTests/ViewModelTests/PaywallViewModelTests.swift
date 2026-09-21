//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct PaywallViewModelTests {
    @Test func selectingPlanDoesNotGrantAccessOrPromiseUnconfirmedTrial() async throws {
        let (p, _, _, _, _) = try await makeViewModelTestGraph()
        let vm = PaywallViewModel(purchases: p)
        #expect(vm.selectedPlan == .annual)
        #expect(vm.trialNotice == nil)
        vm.selectedPlan = .monthly
        #expect(!p.hasAccess)
        #expect(!vm.available)
        #expect(vm.trialNotice == nil)
        await vm.purchase()
        #expect(p.hasAccess)
    }
}
