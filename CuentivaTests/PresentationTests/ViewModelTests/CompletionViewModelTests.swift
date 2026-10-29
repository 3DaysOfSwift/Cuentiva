//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct CompletionViewModelTests {
    @Test func nextChapterPreservesWritingGiftAndNormalDismissal() {
        let writingReceipt = CompletionReceipt(book: sample(), isNew: true, total: ReadingMilestones.writingBookCount)
        let vm = CompletionViewModel(receipt: writingReceipt)
        #expect(!vm.continueJourney(writingReceipt, practiceAllowed: false))
        #expect(vm.showingWritingMilestone)
        let ordinary = CompletionReceipt(book: sample(), isNew: true, total: 7)
        #expect(ordinary.themePackGift == nil)
        vm.prepare(ordinary)
        #expect(vm.continueJourney(ordinary, practiceAllowed: false))
        #expect(!vm.showingWritingMilestone)
        #expect(!vm.showingPractice)
    }

    @Test func earnedThemePackIsPresentedInsteadOfDismissing() throws {
        for pack in ThemePack.allCases {
            guard let count = pack.requiredBooks else { continue }
            let receipt = CompletionReceipt(book: sample(), isNew: true, total: count)
            let model = CompletionViewModel(receipt: receipt)
            #expect(!model.continueJourney(receipt, practiceAllowed: false))
            #expect(model.showingThemePack == pack)
            let reread = CompletionReceipt(book: sample(), isNew: false, total: count)
            model.prepare(reread)
            #expect(model.showingThemePack == nil)
            #expect(model.continueJourney(reread, practiceAllowed: false))
        }
    }

    @Test func chatMilestoneOffersGiftButRereadsDoNot() {
        let receipt = CompletionReceipt(book: sample(), isNew: true, total: ReadingMilestones.chatOfferBookCount)
        let model = CompletionViewModel(receipt: receipt, supportsChat: true)
        #expect(receipt.unlocksChat)
        #expect(!model.continueJourney(receipt, practiceAllowed: false))
        #expect(model.showingChatGift)
        let reread = CompletionReceipt(book: sample(), isNew: false, total: ReadingMilestones.chatOfferBookCount)
        model.prepare(reread)
        #expect(!reread.unlocksChat)
        #expect(!model.showingChatGift)
        #expect(model.continueJourney(reread, practiceAllowed: false))
    }

    @Test func unsupportedDeviceNeverOffersChatGift() {
        let receipt = CompletionReceipt(book: sample(), isNew: true, total: ReadingMilestones.chatOfferBookCount)
        let model = CompletionViewModel(receipt: receipt, supportsChat: false)
        #expect(!model.offersChatGift(receipt))
        #expect(model.continueJourney(receipt, practiceAllowed: false))
        #expect(!model.showingChatGift)
        #expect(!model.showingChat)
    }

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
        let writingReceipt = CompletionReceipt(book: sample(), isNew: true, total: ReadingMilestones.writingBookCount)
        let model = CompletionViewModel(receipt: writingReceipt)
        model.presentWritingMilestone(writingReceipt)
        #expect(model.showingWritingMilestone)
        #expect(!model.takeReviewRequest(writingReceipt))
        model.showingWritingMilestone = false
        model.presentWritingMilestone(writingReceipt)
        #expect(!model.showingWritingMilestone)
        let reviewReceipt = CompletionReceipt(book: sample(), isNew: true, total: ReadingMilestones.reviewBookCount)
        model.prepare(reviewReceipt)
        #expect(!model.showingWritingMilestone)
        #expect(model.takeReviewRequest(reviewReceipt))
        model.prepare(reviewReceipt)
        #expect(!model.takeReviewRequest(reviewReceipt))
    }
}
