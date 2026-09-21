//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation

struct FantasyArchive: Codable, Sendable {
    var introductionSeen: Bool? = nil
    var profile: FantasyProfile?
    var stories: [FantasyStory] = []
    var publications: [FantasyPublication]? = nil
}

protocol FantasyRepository: Sendable {
    func load() async throws -> FantasyArchive
    func save(_ archive: FantasyArchive) async throws
}

actor LocalFantasyRepository: FantasyRepository {
    private let url: URL
    private let store: SwiftDataStore
    init(url: URL, store: SwiftDataStore) {
        self.url = url
        self.store = store
    }
    func load() async throws -> FantasyArchive {
        if let rows = try await store.read("fantasy") {
            let value = try decode(rows)
            LegacyJSONCleanup.remove([url])
            return value
        }
        let legacy =
            FileManager.default.fileExists(atPath: url.path)
            ? try JSONDecoder().decode(FantasyArchive.self, from: Data(contentsOf: url)) : FantasyArchive()
        let rows = try await store.replace("fantasy", values: encode(legacy), onlyIfAbsent: true)
        let value = try decode(rows)
        LegacyJSONCleanup.remove([url])
        return value
    }
    func save(_ archive: FantasyArchive) async throws { try await store.replace("fantasy", values: encode(archive)) }
    private struct Header: Codable {
        let introductionSeen: Bool?
        let profile: FantasyProfile?
        let stories: [UUID]
        let publications: [UUID]?
    }
    private func encode(_ archive: FantasyArchive) throws -> [String: Data] {
        guard Set(archive.stories.map(\.id)).count == archive.stories.count,
            Set((archive.publications ?? []).map(\.storyID)).count == (archive.publications ?? []).count
        else {
            throw AppFailure.unavailable("Duplicate saved story identifiers.")
        }
        let header = Header(
            introductionSeen: archive.introductionSeen, profile: archive.profile,
            stories: archive.stories.map(\.id), publications: archive.publications?.map(\.storyID))
        var rows = ["header": try RecordCoding.encode(header)]
        for story in archive.stories { rows["story/" + story.id.uuidString] = try RecordCoding.encode(story) }
        for publication in archive.publications ?? [] {
            rows["publication/" + publication.storyID.uuidString] = try RecordCoding.encode(publication)
        }
        return rows
    }
    private func decode(_ rows: [String: Data]) throws -> FantasyArchive {
        guard let data = rows["header"] else { throw AppFailure.unavailable("Your storyteller data is incomplete.") }
        let header = try RecordCoding.decode(Header.self, data)
        func read<T: Codable>(_ type: T.Type, _ key: String) throws -> T {
            guard let data = rows[key] else { throw AppFailure.unavailable("A saved story is missing.") }
            return try RecordCoding.decode(type, data)
        }
        return try FantasyArchive(
            introductionSeen: header.introductionSeen, profile: header.profile,
            stories: header.stories.map { try read(FantasyStory.self, "story/" + $0.uuidString) },
            publications: header.publications.map {
                try $0.map { try read(FantasyPublication.self, "publication/" + $0.uuidString) }
            })
    }
}
