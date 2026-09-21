//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

enum InAppPurchases: String, CaseIterable, Identifiable, Sendable {
    case monthly = "com.cuentiva.monthly"
    case annual = "com.cuentiva.annual"
    var id: Self { self }
    var productID: String { rawValue }
    var title: String { self == .monthly ? "Cuentiva Monthly" : "Cuentiva Annual" }
    var billingPeriod: String { self == .monthly ? "month" : "year" }
}
