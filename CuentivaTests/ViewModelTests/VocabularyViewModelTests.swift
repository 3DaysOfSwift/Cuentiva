import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct VocabularyViewModelTests {
    @Test func vocabularySearchAndEditingUseProgressFeature() async throws {
        let (_,s,_,_,_) = try await makeViewModelTestGraph(); let vm = VocabularyViewModel(progress: s)
        await vm.set("café", state: .known); #expect(vm.state("café") == .known)
        await vm.set("casa", state: .learning)
        vm.query = " CAFE "
        #expect(vm.words == ["café"])
        vm.query = "missing"; #expect(vm.words.isEmpty)
        await vm.select(.b1); #expect(vm.selectedLevel == .b1)
        #expect(vm.state("casa") == .learning)
        await vm.select(nil); #expect(vm.selectedLevel == nil)
    }
}
