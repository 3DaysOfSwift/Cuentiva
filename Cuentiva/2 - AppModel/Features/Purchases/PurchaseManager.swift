import Foundation
import StoreKit
import Observation

@MainActor protocol PurchaseFeature: AnyObject, Sendable {
    var hasAccess: Bool { get }
    var checking: Bool { get }
    var offer: Product? { get }
    var trialEligible: Bool { get }
    var message: String? { get }
    func refresh() async
    func purchase() async throws
    func restore() async throws
}
@MainActor @Observable final class PurchaseManager: PurchaseFeature {
    static let productID = "com.3DaysOfSwiftConcurrency.Cuentiva.monthly"
    private(set) var hasAccess = false
    private(set) var checking = true
    private(set) var offer: Product?
    private(set) var trialEligible = false
    private(set) var message: String?
    private var listener: Task<Void, Never>?
    private var expiryMonitor: Task<Void, Never>?
    func refresh() async {
        if expiryMonitor == nil {
            expiryMonitor = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(30)) } catch { return }
                    guard let self else { return }
                    await self.updateEntitlements()
                }
            }
        }
        if listener == nil {
            listener = Task { [weak self] in
                for await update in Transaction.updates {
                    guard let self else { return }
                    if case .verified(let transaction) = update {
                        await self.updateEntitlements()
                        await transaction.finish()
                    }
                }
            }
        }
        await updateEntitlements()
        checking = false
        do {
            offer = try await Product.products(for: [Self.productID]).first
            if let subscription = offer?.subscription { trialEligible = await subscription.isEligibleForIntroOffer }
            message = offer == nil ? "Purchase options are unavailable. For local testing, run the Cuentiva scheme with its StoreKit configuration." : nil
        } catch { message = error.localizedDescription }
    }
    private func updateEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.productID,
               transaction.revocationDate == nil, !transaction.isUpgraded {
                active = true
            }
        }
        hasAccess = active
    }
    func purchase() async throws {
        guard let offer else { throw AppFailure.unavailable("Purchase options have not loaded. Please retry.") }
        switch try await offer.purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { throw AppFailure.unavailable("The purchase could not be verified.") }
            await updateEntitlements(); await transaction.finish()
        case .pending: throw AppFailure.unavailable("Your purchase is awaiting approval. Access will update when it is approved.")
        case .userCancelled: break
        @unknown default: throw AppFailure.unavailable("The purchase could not be completed.")
        }
    }
    func restore() async throws { try await AppStore.sync(); await refresh(); if !hasAccess { throw AppFailure.unavailable("No active subscription was found for this Apple Account.") } }
    isolated deinit { listener?.cancel(); expiryMonitor?.cancel() }
}
