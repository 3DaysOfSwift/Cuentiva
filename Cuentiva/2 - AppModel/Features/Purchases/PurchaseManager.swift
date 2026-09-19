import Foundation
import OSLog
import Observation
import StoreKit

enum LibraryPlan: String, CaseIterable, Identifiable, Sendable {
    case monthly, annual
    var id: Self { self }
    var productID: String { "com.3DaysOfSwiftConcurrency.Cuentiva.\(rawValue)" }
    var title: String { self == .monthly ? "Monthly" : "Annual" }
    var billingPeriod: String { self == .monthly ? "month" : "year" }
}

/// Only verified transactions reach this policy; renewal cancellation alone is not expiry.
enum LibraryAccess {
    static func shouldPromoteAnnual(total: Int, isNew: Bool, monthlyOnly: Bool, checking: Bool, saves: Bool) -> Bool {
        isNew && total > 0 && total.isMultiple(of: 10) && monthlyOnly && !checking && saves
    }

    static func isActive(expiration: Date?, revoked: Bool, upgraded: Bool, lifetime: Bool, now: Date = .now) -> Bool {
        guard !revoked, !upgraded else { return false }
        if lifetime { return true }
        guard let expiration else { return false }
        return expiration > now
    }
}

@MainActor protocol PurchaseFeature: AnyObject, Sendable {
    var hasAccess: Bool { get }
    var checking: Bool { get }
    var offers: [Product] { get }
    var isMonthlySubscriber: Bool { get }
    var message: String? { get }
    func hasOneWeekTrial(for plan: LibraryPlan) -> Bool
    func refresh() async
    func purchase(plan: LibraryPlan) async throws
    func restore() async throws
}
extension PurchaseFeature {
    var isMonthlySubscriber: Bool { false }
    func shouldPromoteAnnual(_ receipt: CompletionReceipt) -> Bool {
        LibraryAccess.shouldPromoteAnnual(total: receipt.total, isNew: receipt.isNew,
            monthlyOnly: hasAccess && isMonthlySubscriber, checking: checking, saves: annualPlanSaves)
    }
    func hasOneWeekTrial(for plan: LibraryPlan) -> Bool { false }

    func offer(for plan: LibraryPlan) -> Product? {
        offers.first { $0.id == plan.productID }
    }

    var annualPlanSaves: Bool {
        guard let monthly = offer(for: .monthly), let annual = offer(for: .annual) else { return false }
        return annual.priceFormatStyle.currencyCode == monthly.priceFormatStyle.currencyCode
            && annual.price < monthly.price * 12
    }
}

@MainActor @Observable final class PurchaseManager: PurchaseFeature {
    static let legacyLifetimeProductID = "com.3DaysOfSwiftConcurrency.Cuentiva.lifetime"
    private let entitlementProductIDs = Set(LibraryPlan.allCases.map(\.productID) + [PurchaseManager.legacyLifetimeProductID])
    private var expirationTask: Task<Void, Never>?
    private(set) var isMonthlySubscriber = false
    private(set) var hasAccess = false
    private(set) var checking = true
    private(set) var offers: [Product] = []
    private var trialEligiblePlans: Set<LibraryPlan> = []
    func hasOneWeekTrial(for plan: LibraryPlan) -> Bool {
        !hasAccess && trialEligiblePlans.contains(plan)
    }
    private(set) var message: String?
    private var listener: Task<Void, Never>?
    private var verificationFailure: String?
    private var entitlementRevision = 0
    private var operationInProgress = false
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.3DaysOfSwiftConcurrency.Cuentiva", category: "Purchases")
    private let observesTransactions: Bool
    private let readEntitlements: @MainActor () async -> [VerificationResult<Transaction>]
    private let readLatest: @MainActor (String) async -> VerificationResult<Transaction>?
    private let loadProducts: @MainActor ([String]) async throws -> [Product]
    init(
        readEntitlements: @escaping @MainActor () async -> [VerificationResult<Transaction>] = {
            var results: [VerificationResult<Transaction>] = []
            for await result in Transaction.currentEntitlements { results.append(result) }
            return results
        },
        readLatest: @escaping @MainActor (String) async -> VerificationResult<Transaction>? = {
            await Transaction.latest(for: $0)
        },
        loadProducts: @escaping @MainActor ([String]) async throws -> [Product] = {
            try await Product.products(for: $0)
        },
        observesTransactions: Bool = true
    ) {
        self.observesTransactions = observesTransactions
        self.readEntitlements = readEntitlements
        self.readLatest = readLatest
        self.loadProducts = loadProducts
    }
    func refresh() async {
        if let refreshTask { await refreshTask.value; return }
        // Owned by the feature: cancelling one caller must not cancel other waiters.
        let task = Task { await self.performRefresh() }
        refreshTask = task
        await task.value
        refreshTask = nil
    }
    private func performRefresh() async {
        if observesTransactions { observeTransactions() }
        let started = Date()
        logger.info("Entitlement check started")
        await updateEntitlements()
        logger.info("Entitlement check took \(Date().timeIntervalSince(started), privacy: .public) seconds")
        checking = false
        // Owners need verified access, not a network lookup for a price.
        // Keep an already loaded offer when returning to the foreground.
        trialEligiblePlans = []
        guard !hasAccess else { return }
        do {
            if offers.count < LibraryPlan.allCases.count {
                offers = try await loadProducts(LibraryPlan.allCases.map(\.productID)).filter { $0.type == .autoRenewable }
            }
            // The group, not the selected billing period, determines trial eligibility.
            var eligible: Set<LibraryPlan> = []
            for plan in LibraryPlan.allCases {
                guard let subscription = offer(for: plan)?.subscription,
                      let intro = subscription.introductoryOffer,
                      intro.paymentMode == .freeTrial,
                      intro.periodCount == 1,
                      (intro.period.unit == .week && intro.period.value == 1)
                        || (intro.period.unit == .day && intro.period.value == 7),
                      await subscription.isEligibleForIntroOffer else { continue }
                eligible.insert(plan)
            }
            trialEligiblePlans = hasAccess ? [] : eligible
            message = offers.isEmpty ? "Purchase options are temporarily unavailable. Please try again later." : nil
        } catch { message = error.localizedDescription }
    }
    private func observeTransactions() {
        if listener == nil {
            listener = Task { [weak self] in
                for await update in Transaction.updates {
                    guard let self else { return }
                    switch update {
                    case .verified(let transaction):
                        guard self.entitlementProductIDs.contains(transaction.productID) else { continue }
                        await self.updateEntitlements(confirmed: transaction)
                        await transaction.finish()
                    case .unverified(let transaction, let error):
                        guard entitlementProductIDs.contains(transaction.productID) else { continue }
                        self.recordVerificationFailure(error)
                    }
                }
            }
        }
    }

    private func updateEntitlements(confirmed: Transaction? = nil) async {
        entitlementRevision += 1
        let revision = entitlementRevision
        var active = false
        var expiry: Date?
        var failedVerification: String?
        var results = await readEntitlements()
        // The latest verified transaction also recovers an incomplete entitlement index.
        for id in entitlementProductIDs {
            if let latest = await readLatest(id) { results.append(latest) }
        }
        if let confirmed { results.append(.verified(confirmed)) }
        var verified: [String: Transaction] = [:]
        for result in results {
            switch result {
            case .verified(let transaction):
                verified[transaction.productID] = transaction
            case .unverified(let transaction, let error):
                guard entitlementProductIDs.contains(transaction.productID) else { continue }
                failedVerification = verificationMessage(error)
            }
        }
        for transaction in verified.values where isActive(transaction) {
            active = true
            if let date = transaction.expirationDate { expiry = min(expiry ?? date, date) }
        }
        // A purchase, revocation, or newer scan supersedes an in-flight snapshot.
        guard revision == entitlementRevision else { return }
        hasAccess = active
        let activeIDs = Set(verified.values.filter { isActive($0) }.map(\.productID))
        isMonthlySubscriber = activeIDs == [LibraryPlan.monthly.productID]
        scheduleExpirationCheck(at: expiry)
        verificationFailure = active ? nil : failedVerification
        logger.info("Entitlement check finished; access: \(active), verification failure: \(failedVerification != nil)")
    }
    private func scheduleExpirationCheck(at expiry: Date?) {
        expirationTask?.cancel()
        expirationTask = nil
        if let expiry {
            expirationTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(max(0, expiry.timeIntervalSinceNow))) } catch { return }
                await self?.updateEntitlements()
            }
        }
    }

    private func verificationMessage(_ error: Error) -> String {
        "A purchase for this feature was found, but Apple could not verify it. Your purchase has not been treated as missing. Please reconnect to the internet and restore again. (\(String(describing: error)))"
    }
    private func recordVerificationFailure(_ error: Error) {
        verificationFailure = verificationMessage(error)
        message = verificationFailure
        logger.error("Transaction verification failed: \(String(reflecting: error), privacy: .public)")
    }
    private func isActive(_ transaction: Transaction) -> Bool {
        guard entitlementProductIDs.contains(transaction.productID) else { return false }
        let lifetime = transaction.productID == Self.legacyLifetimeProductID && transaction.productType == .nonConsumable
        guard lifetime || transaction.productType == .autoRenewable else { return false }
        return LibraryAccess.isActive(expiration: transaction.expirationDate,
            revoked: transaction.revocationDate != nil, upgraded: transaction.isUpgraded, lifetime: lifetime)
    }
    func purchase(plan: LibraryPlan = .annual) async throws {
        guard !operationInProgress else { return }
        operationInProgress = true
        defer { operationInProgress = false }
        await updateEntitlements()
        guard !hasAccess else { return }
        guard let offer = offer(for: plan) else {
            throw AppFailure.unavailable("Purchase options have not loaded. Please retry.")
        }
        let result: Product.PurchaseResult
        do { result = try await offer.purchase() } catch {
            // StoreKit may report an error after an existing purchase has become available.
            await updateEntitlements()
            guard !hasAccess else { return }
            logger.error("Purchase failed: \(String(reflecting: error), privacy: .public)")
            if let verificationFailure { throw AppFailure.unavailable(verificationFailure) }
            throw AppFailure.unavailable(
                "The App Store could not complete the request. If you already purchased Cuentiva, tap Restore purchases. \(error.localizedDescription)"
            )
        }
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                if case .unverified(_, let error) = verification { recordVerificationFailure(error) }
                throw AppFailure.unavailable(
                    verificationFailure ?? "The purchase could not be verified. Please try Restore purchases.")
            }
            // Deliver access from the verified result before finishing the transaction.
            guard isActive(transaction) else {
                throw AppFailure.unavailable("This transaction does not provide active access to this feature.")
            }
            await updateEntitlements(confirmed: transaction)
            await transaction.finish()
        case .pending:
            throw AppFailure.unavailable("Your purchase is awaiting approval. Access will update when it is approved.")
        case .userCancelled: break
        @unknown default: throw AppFailure.unavailable("The purchase could not be completed.")
        }
    }
    func restore() async throws {
        guard !operationInProgress else { return }
        operationInProgress = true
        defer { operationInProgress = false }
        await updateEntitlements()
        guard !hasAccess else {
            message = nil
            return
        }
        try await AppStore.sync()
        await updateEntitlements()
        if !hasAccess {
            throw AppFailure.unavailable(
                verificationFailure
                    ?? "No purchase for this feature was returned by the current store. For an Xcode test purchase, run this app with the same StoreKit configuration. For an App Store purchase, check that you are signed into the Apple Account that bought it."
            )
        }
        message = nil
    }
    isolated deinit {
        listener?.cancel()
        expirationTask?.cancel()
    }
}
