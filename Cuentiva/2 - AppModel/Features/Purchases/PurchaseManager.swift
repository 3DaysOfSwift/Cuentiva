import Foundation
import StoreKit
import Observation
import OSLog

@MainActor protocol PurchaseFeature: AnyObject, Sendable {
    var hasAccess: Bool { get }
    var checking: Bool { get }
    var offer: Product? { get }
    var message: String? { get }
    func refresh() async
    func purchase() async throws
    func restore() async throws
}
@MainActor @Observable final class PurchaseManager: PurchaseFeature {
    static let productID = "com.3DaysOfSwiftConcurrency.Cuentiva.lifetime"
    private(set) var hasAccess = false
    private(set) var checking = true
    private(set) var offer: Product?
    private(set) var message: String?
    private var listener: Task<Void, Never>?
    private var entitlementRevision = 0
    private var operationInProgress = false
    private let logger = Logger(subsystem: "com.3DaysOfSwiftConcurrency.Cuentiva", category: "Purchases")
    func refresh() async {
        if listener == nil {
            listener = Task { [weak self] in
                for await update in Transaction.updates {
                    guard let self else { return }
                    if case .verified(let transaction) = update, self.apply(transaction) {
                        await transaction.finish()
                    }
                }
            }
        }
        await updateEntitlements()
        checking = false
        do {
            offer = try await Product.products(for: [Self.productID]).first
            if offer?.type != .nonConsumable { offer = nil }
            message = offer == nil ? "Purchase options are unavailable. For local testing, run the Cuentiva scheme with its StoreKit configuration." : nil
        } catch { message = error.localizedDescription }
    }
    private func updateEntitlements() async {
        entitlementRevision += 1
        let revision = entitlementRevision
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.productID,
               transaction.revocationDate == nil, transaction.productType == .nonConsumable {
                active = true
            }
        }
        // A purchase, revocation, or newer scan supersedes an in-flight snapshot.
        guard revision == entitlementRevision else { return }
        hasAccess = active
    }
    @discardableResult private func apply(_ transaction: Transaction) -> Bool {
        guard transaction.productID == Self.productID, transaction.productType == .nonConsumable else { return false }
        entitlementRevision += 1
        hasAccess = transaction.revocationDate == nil && !transaction.isUpgraded
        if hasAccess { message = nil }
        logger.info("Verified lifetime transaction received; access: \(self.hasAccess)")
        return true
    }
    func purchase() async throws {
        guard !operationInProgress else { return }
        operationInProgress = true; defer { operationInProgress = false }
        await updateEntitlements()
        guard !hasAccess else { return }
        guard let offer else { throw AppFailure.unavailable("Purchase options have not loaded. Please retry.") }
        let result: Product.PurchaseResult
        do { result = try await offer.purchase() }
        catch {
            // StoreKit may report an error after an existing purchase has become available.
            await updateEntitlements()
            guard !hasAccess else { return }
            logger.error("Purchase failed: \(String(reflecting: error), privacy: .public)")
            throw AppFailure.unavailable("The App Store could not complete the request. If you already purchased Cuentiva, tap Restore purchases. \(error.localizedDescription)")
        }
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { throw AppFailure.unavailable("The purchase could not be verified. Please try Restore purchases.") }
            // Deliver access from the verified result before finishing the transaction.
            guard apply(transaction), hasAccess else { throw AppFailure.unavailable("This transaction does not provide active Cuentiva access.") }
            await transaction.finish()
        case .pending: throw AppFailure.unavailable("Your purchase is awaiting approval. Access will update when it is approved.")
        case .userCancelled: break
        @unknown default: throw AppFailure.unavailable("The purchase could not be completed.")
        }
    }
    func restore() async throws {
        guard !operationInProgress else { return }
        operationInProgress = true; defer { operationInProgress = false }
        await updateEntitlements()
        guard !hasAccess else { message = nil; return }
        try await AppStore.sync()
        await updateEntitlements()
        if !hasAccess { throw AppFailure.unavailable("No Cuentiva purchase was found in the current App Store testing environment or Apple Account.") }
        message = nil
    }
    isolated deinit { listener?.cancel() }
}
