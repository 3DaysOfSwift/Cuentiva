//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
import CryptoKit
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite struct StoreOpeningTests {
    @Test func independentStoresOpenConcurrentlyWithoutSharingData() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<32 {
                group.addTask {
                    let store = SwiftDataStore(url: directory.appending(path: "\(index).store"))
                    let data = Data("\(index)".utf8)
                    try await store.put("test", key: "value", data: data)
                    #expect(try await store.value("test", key: "value") == data)
                }
            }
            try await group.waitForAll()
        }
    }

    @Test func sharedStoreKeepsConcurrentCollectionsSeparateAfterReopening() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "app.store")
        let store = SwiftDataStore(url: url)
        let collections = ["progress", "drafts", "fantasy", "chat", "catalogue"]
        try await withThrowingTaskGroup(of: Void.self) { group in
            for collection in collections {
                group.addTask {
                    try await store.put(collection, key: "shared-key", data: Data(collection.utf8))
                }
            }
            try await group.waitForAll()
        }
        // A separate graph reads persisted records through a fresh container.
        let reopened = SwiftDataStore(url: url)
        for collection in collections {
            #expect(try await reopened.value(collection, key: "shared-key") == Data(collection.utf8))
        }
    }

    @Test func failedOpeningCanBeRetried() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("blocks the directory".utf8).write(to: directory)
        let store = SwiftDataStore(url: directory.appending(path: "app.store"))
        await #expect(throws: (any Error).self) { try await store.read("test") }
        try FileManager.default.removeItem(at: directory)
        let data = Data("recovered".utf8)
        try await store.put("test", key: "value", data: data)
        #expect(try await store.value("test", key: "value") == data)
    }
}
