//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation

/// Versioned, little-endian offset tables plus UTF-8 text. Opening reads only
/// the header; a Book is materialized on demand. No Swift object-memory dumps.
struct BinaryLibrary: Sendable {
    private let data: Data
    let count: Int
    private static let bookStride = 152
    private let recordStride: Int
    private let version: UInt32

    init(data: Data) throws {
        guard data.count >= 16, data.prefix(8) == Data("CUENLIB\0".utf8) else {
            throw AppFailure.invalidBook
        }
        self.data = data
        self.count = Int(Self.word(data, at: 12))
        version = Self.word(data, at: 8)
        recordStride = version == 1 ? 140 : Self.bookStride
        guard (version == 1 || version == 2), count > 0, count <= 20_000,
            count <= (data.count - 16) / recordStride else { throw AppFailure.invalidBook }
    }

    init(url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }

    func books() throws -> [Book] { try (0..<count).map(book(at:)) }

    func book(at index: Int) throws -> Book {
        guard index >= 0, index < count else { throw AppFailure.invalidBook }
        let base = 16 + index * recordStride
        let r = Reader(data: data)
        let format = try r.optionalText(base + 72)
        let kind = format.flatMap(BookFormat.init(rawValue:))
        guard format == nil || kind != nil else { throw AppFailure.invalidBook }
        let flag = try r.uint(base + 92)
        guard flag <= 2 else { throw AppFailure.invalidBook }
        let glossaryPairs: [(String, String)]? = try r.table(base + 120, stride: 16) { offset in
            (try r.text(offset), try r.text(offset + 8))
        }
        var glossary: [String: String]?
        if let glossaryPairs {
            var values: [String: String] = [:]
            for (key, value) in glossaryPairs {
                guard values.updateValue(value, forKey: key) == nil else { throw AppFailure.invalidBook }
            }
            glossary = values
        }
        guard let sentences = try r.table(base + 96, stride: 32, read: r.sentence),
            let vocabulary = try r.table(base + 104, stride: 20, read: r.vocabulary) else {
            throw AppFailure.invalidBook
        }
        return Book(
            id: try r.text(base), title: try r.text(base + 8), englishTitle: try r.text(base + 16),
            author: try r.text(base + 24), level: try r.text(base + 32), symbol: try r.text(base + 40),
            palette: Int(try r.uint(base + 88)), summary: try r.text(base + 48),
            sentences: sentences, vocabulary: vocabulary, license: try r.text(base + 56),
            authorID: try r.optionalText(base + 64), personalAuthor: try r.optionalRecord(base + 136, read: r.author),
            matchGlossary: glossary, isDemoLocation: flag == 2 ? nil : flag == 1,
            submissionLocation: try r.optionalRecord(base + 132, read: r.location), format: kind,
            scene: try r.optionalText(base + 80), continuation: try r.table(base + 112, stride: 32, read: r.sentence),
            verbFocus: try r.optionalRecord(base + 128, read: r.verb),
            ending: version >= 2 ? try r.table(base + 140, stride: 32, read: r.sentence) : nil,
            editorialRevision: version >= 2 ? try r.optionalRevision(base + 148) : nil
        )
    }

    private static func word(_ data: Data, at offset: Int) -> UInt32 {
        data.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self)) }
    }

    private struct Reader {
        let data: Data
        func check(_ offset: Int, length: Int) throws {
            guard offset >= 0, length >= 0, offset <= data.count, length <= data.count - offset else {
                throw AppFailure.invalidBook
            }
        }
        func uint(_ offset: Int) throws -> UInt32 {
            try check(offset, length: 4)
            return BinaryLibrary.word(data, at: offset)
        }
        func optionalRevision(_ offset: Int) throws -> Int? {
            let value = try uint(offset)
            return value == .max ? nil : Int(value)
        }
        func double(_ offset: Int) throws -> Double {
            try check(offset, length: 8)
            return data.withUnsafeBytes {
                Double(bitPattern: UInt64(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self)))
            }
        }
        func optionalText(_ descriptor: Int) throws -> String? {
            let offset = try uint(descriptor), length = Int(try uint(descriptor + 4))
            if offset == UInt32.max {
                guard length == 0 else { throw AppFailure.invalidBook }
                return nil
            }
            let start = Int(offset)
            try check(start, length: length)
            return try data.withUnsafeBytes { buffer in
                guard let value = String(bytes: buffer[start..<(start + length)], encoding: .utf8) else {
                    throw AppFailure.invalidBook
                }
                return value
            }
        }
        func text(_ descriptor: Int) throws -> String {
            guard let value = try optionalText(descriptor) else { throw AppFailure.invalidBook }
            return value
        }
        func table<T>(_ descriptor: Int, stride: Int, read: (Int) throws -> T) throws -> [T]? {
            let offset = try uint(descriptor), count = Int(try uint(descriptor + 4))
            if offset == UInt32.max {
                guard count == 0 else { throw AppFailure.invalidBook }
                return nil
            }
            let start = Int(offset)
            try check(start, length: 0)
            guard count <= (data.count - start) / stride else { throw AppFailure.invalidBook }
            return try (0..<count).map { try read(start + $0 * stride) }
        }
        func optionalRecord<T>(_ descriptor: Int, read: (Int) throws -> T) throws -> T? {
            let offset = try uint(descriptor)
            return offset == UInt32.max ? nil : try read(Int(offset))
        }
        func sentence(_ offset: Int) throws -> Sentence {
            Sentence(id: try text(offset), spanish: try text(offset + 8), english: try text(offset + 16),
                     speaker: try optionalText(offset + 24))
        }
        func vocabulary(_ offset: Int) throws -> VocabularyEntry {
            VocabularyEntry(word: try text(offset), lemma: try text(offset + 8), occurrences: Int(try uint(offset + 16)))
        }
        func verb(_ offset: Int) throws -> VerbFocus {
            guard let forms = try table(offset + 24, stride: 8, read: text) else { throw AppFailure.invalidBook }
            return VerbFocus(infinitive: try text(offset), tense: try text(offset + 8), forms: forms, scope: try text(offset + 16))
        }
        func location(_ offset: Int) throws -> StoryLocation {
            let value = StoryLocation(latitude: try double(offset), longitude: try double(offset + 8),
                accuracy: try double(offset + 16), capturedAt: Date(timeIntervalSinceReferenceDate: try double(offset + 24)),
                placeName: try text(offset + 32))
            guard value.valid, value.capturedAt.timeIntervalSinceReferenceDate.isFinite else { throw AppFailure.invalidBook }
            return value
        }
        func author(_ offset: Int) throws -> Author {
            Author(id: try text(offset), name: try text(offset + 8), portrait: try text(offset + 16),
                   introduction: try text(offset + 24), note: try text(offset + 32))
        }
    }
}

extension BinaryLibrary {
    /// Used only when preparing a downloaded replacement, never on the display path.
    /// Matches the build-time compiler's version-two wire format; version-one snapshots remain readable.
    static func encode(_ books: [Book]) throws -> Data {
        guard !books.isEmpty, books.count <= 20_000 else { throw AppFailure.invalidBook }
        let writer = Writer()
        writer.data = Data("CUENLIB\0".utf8) + writer.word(2) + writer.word(UInt32(books.count))
        writer.data.append(Data(count: books.count * bookStride))
        for (index, book) in books.enumerated() {
            let record = try writer.book(book)
            guard record.count == bookStride else { throw AppFailure.invalidBook }
            let start = 16 + index * bookStride
            writer.data.replaceSubrange(start..<(start + bookStride), with: record)
        }
        return writer.data
    }

    private final class Writer {
        var data = Data()
        private var strings: [String: Data] = [:]
        func word(_ value: UInt32) -> Data {
            var little = value.littleEndian
            return withUnsafeBytes(of: &little) { Data($0) }
        }
        func number(_ value: Int) throws -> Data {
            guard let value = UInt32(exactly: value) else { throw AppFailure.invalidBook }
            return word(value)
        }
        func append(_ bytes: Data) throws -> Data {
            guard data.count < Int(UInt32.max), bytes.count < Int(UInt32.max) - data.count else {
                throw AppFailure.invalidBook
            }
            let offset = try number(data.count)
            data.append(bytes)
            return offset
        }
        func text(_ value: String?) throws -> Data {
            guard let value else { return word(.max) + word(0) }
            if let descriptor = strings[value] { return descriptor }
            let bytes = Data(value.utf8)
            let descriptor = try append(bytes) + number(bytes.count)
            strings[value] = descriptor
            return descriptor
        }
        func table<T>(_ values: [T]?, encode: (T) throws -> Data) throws -> Data {
            guard let values else { return word(.max) + word(0) }
            var records = Data()
            for value in values { records.append(try encode(value)) }
            return try append(records) + number(values.count)
        }
        func record<T>(_ value: T?, encode: (T) throws -> Data) throws -> Data {
            guard let value else { return word(.max) }
            return try append(encode(value))
        }
        func sentence(_ value: Sentence) throws -> Data {
            try text(value.id) + text(value.spanish) + text(value.english) + text(value.speaker)
        }
        func vocabulary(_ value: VocabularyEntry) throws -> Data {
            try text(value.word) + text(value.lemma) + number(value.occurrences)
        }
        func author(_ value: Author) throws -> Data {
            try text(value.id) + text(value.name) + text(value.portrait) + text(value.introduction) + text(value.note)
        }
        func verb(_ value: VerbFocus) throws -> Data {
            try text(value.infinitive) + text(value.tense) + text(value.scope) + table(value.forms, encode: text)
        }
        func location(_ value: StoryLocation) throws -> Data {
            guard value.valid, value.capturedAt.timeIntervalSinceReferenceDate.isFinite else { throw AppFailure.invalidBook }
            var bytes = Data()
            for number in [value.latitude, value.longitude, value.accuracy, value.capturedAt.timeIntervalSinceReferenceDate] {
                var little = number.bitPattern.littleEndian
                bytes.append(withUnsafeBytes(of: &little) { Data($0) })
            }
            return try bytes + text(value.placeName)
        }
        func book(_ value: Book) throws -> Data {
            var bytes = Data()
            let fields: [String?] = [value.id, value.title, value.englishTitle, value.author, value.level,
                value.symbol, value.summary, value.license, value.authorID, value.format?.rawValue, value.scene]
            for field in fields { bytes.append(try text(field)) }
            bytes.append(try number(value.palette))
            bytes.append(word(value.isDemoLocation.map { $0 ? 1 : 0 } ?? 2))
            bytes.append(try table(value.sentences, encode: sentence))
            bytes.append(try table(value.vocabulary, encode: vocabulary))
            bytes.append(try table(value.continuation, encode: sentence))
            bytes.append(try table(value.matchGlossary?.sorted { $0.key < $1.key }) {
                try text($0.key) + text($0.value)
            })
            bytes.append(try record(value.verbFocus, encode: verb))
            bytes.append(try record(value.submissionLocation, encode: location))
            bytes.append(try record(value.personalAuthor, encode: author))
            bytes.append(try table(value.ending, encode: sentence))
            if let revision = value.editorialRevision {
                guard revision > 0, revision < Int(UInt32.max) else { throw AppFailure.invalidBook }
                bytes.append(try number(revision))
            } else {
                bytes.append(word(.max))
            }
            return bytes
        }
    }
}
