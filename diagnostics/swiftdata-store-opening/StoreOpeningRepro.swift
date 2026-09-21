//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import SwiftData

// Standalone framework reproducer: no app code, Swift Testing or shared store URL.
@Model final class Record {
    @Attribute(.unique) var identity: String
    var collection: String
    var key: String
    var payload: Data
    init(_ key: String) {
        identity = key
        collection = "test"
        self.key = key
        payload = Data()
    }
}

enum StoreSchema: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Record.self] }
}

enum StoreMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [StoreSchema.self] }
    static var stages: [MigrationStage] { [] }
}

actor Holder {
    let container: ModelContainer
    init(_ container: ModelContainer) { self.container = container }
}

// No suspension inside open: all container initialization finishes before the next call.
actor Opener {
    func open(_ url: URL) throws -> Holder { try makeStore(url) }
}

func makeStore(_ url: URL) throws -> Holder {
    let schema = Schema(versionedSchema: StoreSchema.self)
    let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    let container = try ModelContainer(
        for: schema, migrationPlan: StoreMigration.self, configurations: [configuration])
    return Holder(container)
}

enum ReproError: Error { case invalidArguments }

@main struct StoreOpeningRepro {
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 4,
              ["parallel", "serial"].contains(arguments[1]),
              let count = Int(arguments[3]), (1...128).contains(count) else {
            throw ReproError.invalidArguments
        }
        let serial = arguments[1] == "serial"
        let root = URL(fileURLWithPath: arguments[2], isDirectory: true)
        let opener = Opener()
        let holders = try await withThrowingTaskGroup(of: Holder.self) { group in
            for index in 0..<count {
                let url = root.appending(path: "\(index).store")
                group.addTask {
                    if serial { return try await opener.open(url) }
                    return try makeStore(url)
                }
            }
            var holders: [Holder] = []
            for try await holder in group { holders.append(holder) }
            return holders
        }
        withExtendedLifetime(holders) {
            print("Opened \(holders.count) independent stores; serial=\(serial)")
        }
    }
}
