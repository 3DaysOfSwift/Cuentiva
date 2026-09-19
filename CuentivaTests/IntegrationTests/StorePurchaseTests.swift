import Foundation
import Testing
@testable import Cuentiva

#if targetEnvironment(simulator)
import StoreKitTest

@Suite(.serialized) @MainActor struct StorePurchaseTests {
    @Test(arguments: LibraryPlan.allCases) func subscriptionSurvivesNewManagerAndRestoresWithoutRepurchase(plan: LibraryPlan) async throws {
        let configuration = TestResources.repositoryRoot
            .appending(path: "Cuentiva/3 - App Resources/Cuentiva.storekit")
        let session = try SKTestSession(contentsOf: configuration)
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let purchases = PurchaseManager()
        await purchases.refresh()
        #expect(!purchases.hasAccess)
        #expect(purchases.offers.count == 2)
        let progress = ProgressManager(repository: MemoryProgress())
        let library = LibraryManager(repository: MemoryBooks(values: [sample()]), purchases: purchases, progress: progress)
        let root = RootViewModel(purchases: purchases, library: library, progress: progress, fantasy: FantasyManager(repository: FantasyTestRepository(), generator: FantasyTestGenerator()))
        await root.load()
        #expect(!root.hasAccess)
        try await purchases.purchase(plan: plan)
        #expect(purchases.hasAccess)
        #expect(root.hasAccess)

        // A fresh manager has no app-local record, as after reinstalling.
        let relaunched = PurchaseManager()
        await relaunched.refresh()
        #expect(relaunched.hasAccess)
        try await relaunched.restore()
        try await relaunched.purchase(plan: plan)
        #expect(relaunched.hasAccess)
        #expect(session.allTransactions().count == 1)

        // Reproduce the device failure: the entitlement index returns nothing,
        // but StoreKit still has a verified subscription transaction.
        let emptyIndex = PurchaseManager(readEntitlements: { [] })
        await emptyIndex.refresh()
        #expect(emptyIndex.hasAccess)
        try await emptyIndex.restore()
        #expect(emptyIndex.hasAccess)

        let transaction = try #require(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        // StoreKit delivers refunds asynchronously through Transaction.updates.
        for _ in 0..<50 {
            if !relaunched.hasAccess { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(!relaunched.hasAccess)
        await relaunched.refresh()
        #expect(!relaunched.hasAccess)
        await emptyIndex.refresh()
        #expect(!emptyIndex.hasAccess)
    }
}

#endif
