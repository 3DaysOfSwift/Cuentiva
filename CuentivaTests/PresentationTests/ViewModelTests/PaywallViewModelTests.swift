import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct PaywallViewModelTests {
    @Test func paywallDeclineDoesNotGrantAccess() async throws {
        let (p,_,_,_,_) = try await makeViewModelTestGraph(); let vm = PaywallViewModel(purchases: p)
        vm.declined = true; #expect(!p.hasAccess); await vm.purchase(); #expect(p.hasAccess)
    }
}
