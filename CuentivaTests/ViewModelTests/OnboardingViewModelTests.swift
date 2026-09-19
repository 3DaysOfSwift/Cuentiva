import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct OnboardingViewModelTests {
    @Test func onboardingKeepsItsBook() async throws {
        let (p,s,l,_,_) = try await makeViewModelTestGraph(); let vm = OnboardingViewModel(library: l, progress: s, purchases: p)
        #expect(vm.book?.id == "cafe"); #expect(!vm.completed)
    }
}
