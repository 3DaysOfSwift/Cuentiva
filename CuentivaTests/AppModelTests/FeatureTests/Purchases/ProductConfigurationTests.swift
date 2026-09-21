//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct ProductConfigurationTests {
    @Test(arguments: [0, 1, 9, 10, 11, 20, 30, 40, 50, 100, 110])
    func annualOfferOnlyAtNewTenBookMilestones(total: Int) {
        let eligible = LibraryAccess.shouldPromoteAnnual(total: total, isNew: true, monthlyOnly: true, checking: false, saves: true)
        #expect(eligible == (total > 0 && total.isMultiple(of: 10)))
        #expect(!LibraryAccess.shouldPromoteAnnual(total: total, isNew: false, monthlyOnly: true, checking: false, saves: true))
        #expect(!LibraryAccess.shouldPromoteAnnual(total: total, isNew: true, monthlyOnly: false, checking: false, saves: true))
        #expect(!LibraryAccess.shouldPromoteAnnual(total: total, isNew: true, monthlyOnly: true, checking: true, saves: true))
        #expect(!LibraryAccess.shouldPromoteAnnual(total: total, isNew: true, monthlyOnly: true, checking: false, saves: false))
    }

    @Test func twoSubscriptionsShareOneGroup() throws {
        let directory = TestResources.repositoryRoot
            .appending(path: "Cuentiva/3 - App Resources")
        let configuration = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appending(path: "Cuentiva.storekit"))) as? [String: Any])
        let products = try #require(configuration["products"] as? [[String: Any]])
        #expect(products.isEmpty)
        let groups = try #require(configuration["subscriptionGroups"] as? [[String: Any]])
        #expect(groups.count == 1)
        let group = try #require(groups.first)
        let subscriptions = try #require(group["subscriptions"] as? [[String: Any]])
        #expect(subscriptions.count == 2)
        for plan in InAppPurchases.allCases {
            let product = try #require(subscriptions.first { $0["productID"] as? String == plan.productID })
            #expect(product["type"] as? String == "RecurringSubscription")
            #expect(product["displayPrice"] as? String == (plan == .annual ? "39.99" : "9.99"))
            #expect(product["recurringSubscriptionPeriod"] as? String == (plan == .annual ? "P1Y" : "P1M"))
        }
    }
    @Test func expiryRevocationAndUpgradeNeverGrantAccess() {
        let now = Date()
        #expect(LibraryAccess.isActive(expiration: now.addingTimeInterval(100), revoked: false, upgraded: false, lifetime: false, now: now))
        #expect(!LibraryAccess.isActive(expiration: now, revoked: false, upgraded: false, lifetime: false, now: now))
        #expect(!LibraryAccess.isActive(expiration: nil, revoked: false, upgraded: false, lifetime: false, now: now))
        #expect(!LibraryAccess.isActive(expiration: now.addingTimeInterval(100), revoked: true, upgraded: false, lifetime: false, now: now))
        #expect(!LibraryAccess.isActive(expiration: now.addingTimeInterval(100), revoked: false, upgraded: true, lifetime: false, now: now))
        #expect(LibraryAccess.isActive(expiration: nil, revoked: false, upgraded: false, lifetime: true, now: now))
        #expect(!LibraryAccess.isActive(expiration: nil, revoked: true, upgraded: false, lifetime: true, now: now))
    }
}
