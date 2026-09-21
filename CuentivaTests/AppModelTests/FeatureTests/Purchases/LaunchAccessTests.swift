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

@Suite @MainActor struct LaunchAccessTests {
    @Test func purchaseWaitsForStorageAndFailureCanRetry() async throws {
        let gate = PurchasePreparationGate()
        var entitlementReads = 0
        let purchases = PurchaseManager(readEntitlements: {
            entitlementReads += 1
            return []
        }, readLatest: { _ in nil }, loadProducts: { _ in [] }, observesTransactions: false,
            prepareForPurchase: { try await gate.prepare() })
        let purchase = Task { try await purchases.purchase() }
        defer { gate.finish(); purchase.cancel() }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while gate.pending == nil {
            guard ContinuousClock.now < deadline else { throw AppFailure.unavailable("Purchase did not reach storage gate.") }
            await Task.yield()
        }
        #expect(entitlementReads == 0)
        #expect(!purchases.hasAccess)
        gate.failure = .unavailable("Storage unavailable")
        gate.finish()
        await #expect(throws: AppFailure.self) { try await purchase.value }
        #expect(entitlementReads == 0)
        gate.failure = nil
        // No product is injected: reaching offer validation proves preparation
        // succeeded without contacting StoreKit or pretending a payment occurred.
        await #expect(throws: AppFailure.self) { try await purchases.purchase() }
        #expect(gate.calls == 2)
        #expect(entitlementReads == 1)
        #expect(!purchases.hasAccess)
    }

    @Test func fullCatalogueIsNotReadOrSyncedUntilAccessIsConfirmed() async throws {
        let purchases = TestPurchases(); purchases.checking = true
        let progress = ProgressManager(repository: MemoryProgress())
        let repository = AccessBookProbe()
        let library = LibraryManager(repository: repository, purchases: purchases, progress: progress)
        try await library.loadIntroduction()
        #expect(library.introduction?.id == "cafe")
        #expect(!progress.loaded) // Introduction has no database dependency.
        for access in [false, true] {
            purchases.hasAccess = access
            await #expect(throws: AppFailure.self) { try await library.load() }
            await library.sync()
            #expect(library.books.isEmpty)
            #expect(await repository.reads == 0)
            #expect(await repository.syncs == 0)
        }
        purchases.hasAccess = false; purchases.checking = false
        await #expect(throws: AppFailure.self) { try await library.load() }
        #expect(await repository.reads == 0)
        purchases.hasAccess = true
        try await library.load()
        #expect(await repository.reads == 1)
        #expect(library.books.count == 2)
        #expect(!progress.loaded) // Core reads remain independent from progress.
        purchases.hasAccess = false
        #expect(library.books.isEmpty)
        #expect(await library.dailyReads.isEmpty)
        await library.sync()
        #expect(await repository.syncs == 0)
    }

    @Test func accessLossWhileLoadingDoesNotPublishPaidBooks() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let repository = AccessBookProbe(gated: true)
        let library = LibraryManager(repository: repository, purchases: purchases,
            progress: ProgressManager(repository: MemoryProgress()))
        let task = Task { try await library.load() }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !(await repository.waiting) {
            if ContinuousClock.now >= deadline {
                await repository.finish()
                task.cancel()
                _ = await task.result
                throw AppFailure.unavailable("Library did not reach its test gate.")
            }
            await Task.yield()
        }
        purchases.hasAccess = false
        await repository.finish()
        await #expect(throws: AppFailure.self) { try await task.value }
        #expect(library.books.isEmpty)
        purchases.hasAccess = true
        #expect(library.books.isEmpty)
        try await library.load()
        #expect(library.books.count == 2)
    }
}

private actor AccessBookProbe: SyncingBookRepository {
    var reads = 0
    var syncs = 0
    var waiting: Bool { continuation != nil }
    private var continuation: CheckedContinuation<Void, Never>?
    private var gated: Bool
    init(gated: Bool = false) { self.gated = gated }
    func introduction() async throws -> Book { sample() }
    func books() async throws -> [Book] {
        reads += 1
        if gated { await withCheckedContinuation { continuation = $0 } }
        return [sample(), sample("paid")]
    }
    func finish() { gated = false; let pending = continuation; continuation = nil; pending?.resume() }
    func sync() async throws -> [Book] { syncs += 1; return [sample()] }
}

@MainActor private final class PurchasePreparationGate {
    var pending: CheckedContinuation<Void, Never>?
    var failure: AppFailure?
    var calls = 0
    private var released = false
    func prepare() async throws {
        calls += 1
        if !released { await withCheckedContinuation { pending = $0 } }
        if let failure { throw failure }
    }
    func finish() { released = true; pending?.resume(); pending = nil }
}
