import Testing
@testable import Cuentiva

@Suite @MainActor struct MatchRewardViewModelTests {
    @Test func revealsThePersistedBalanceWithoutChangingTheReceipt() {
        let receipt = MatchRewardReceipt(previousBalance: 7, balance: 8)
        let model = MatchRewardViewModel(receipt: receipt)
        #expect(model.displayedBalance == 7)
        #expect(!model.revealed)
        model.reveal()
        #expect(model.displayedBalance == 8)
        #expect(model.revealed)
        model.reveal()
        #expect(model.displayedBalance == 8)
        #expect(model.receipt == receipt)
    }
}
