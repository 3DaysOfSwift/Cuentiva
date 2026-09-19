import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct CompletionViewModelTests {
    @Test func celebrationCountsOnce() {
        let receipt = CompletionReceipt(book: sample(), isNew: true, total: 2), vm = CompletionViewModel()
        vm.prepare(receipt); #expect(vm.displayedTotal == 1); vm.celebrate(receipt); vm.prepare(receipt); #expect(vm.displayedTotal == 2)
    }

    @Test func firstCompletionHasPreviousCountBeforeAppearance() {
        let first = CompletionReceipt(book: sample(), isNew: true, total: 1)
        let vm = CompletionViewModel(receipt: first)
        #expect(vm.displayedTotal == 0); #expect(!vm.hasCelebrated)
        vm.prepare(first)
        #expect(vm.displayedTotal == 0)
        vm.celebrate(first); vm.prepare(first); vm.celebrate(first)
        #expect(vm.displayedTotal == 1); #expect(vm.hasCelebrated)
        let second = CompletionReceipt(book: sample("second"), isNew: true, total: 2)
        vm.prepare(second)
        #expect(vm.displayedTotal == 1); #expect(!vm.hasCelebrated)
        vm.celebrate(second)
        #expect(vm.displayedTotal == 2)
    }

    @Test func rereadCelebrationNeverInventsAnIncrement() {
        let receipt = CompletionReceipt(book: sample(), isNew: false, total: 4)
        let vm = CompletionViewModel(receipt: receipt)
        #expect(vm.displayedTotal == 4)
        vm.celebrate(receipt)
        #expect(vm.displayedTotal == 4); #expect(vm.hasCelebrated)
    }

    @Test func reviewRequestIsConsumedOnceAndIndependentOfWriting() {
        let fifth = CompletionReceipt(book: sample(), isNew: true, total: 5)
        let model = CompletionViewModel(receipt: fifth)
        model.presentWritingMilestone(fifth)
        #expect(model.showingWritingMilestone)
        #expect(!model.takeReviewRequest(fifth))
        model.showingWritingMilestone = false
        model.presentWritingMilestone(fifth)
        #expect(!model.showingWritingMilestone)
        let fifteenth = CompletionReceipt(book: sample(), isNew: true, total: 15)
        model.prepare(fifteenth)
        #expect(!model.showingWritingMilestone)
        #expect(model.takeReviewRequest(fifteenth))
        model.prepare(fifteenth)
        #expect(!model.takeReviewRequest(fifteenth))
    }
}
