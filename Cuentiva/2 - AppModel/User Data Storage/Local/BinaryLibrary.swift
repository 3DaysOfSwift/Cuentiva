import Foundation

/// Versioned, little-endian offset tables plus UTF-8 text. Opening reads only
/// the header; a Book is materialized on demand. No Swift object-memory dumps.
struct BinaryLibrary: Sendable {
    private let data: Data
    let count: Int
    private static let bookStride = 140

    init(data: Data) throws {
        guard data.count >= 16, data.prefix(8) == Data("CUENLIB\0".utf8) else {
            throw AppFailure.invalidBook
        }
        self.data = data
        self.count = Int(Self.word(data, at: 12))
        guard Self.word(data, at: 8) == 1, count > 0, count <= 20_000,
            count <= (data.count - 16) / Self.bookStride else { throw AppFailure.invalidBook }
    }

    init(url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }

    func books() throws -> [Book] { try (0..<count).map(book(at:)) }

    func book(at index: Int) throws -> Book {
        guard index >= 0, index < count else { throw AppFailure.invalidBook }
        let base = 16 + index * Self.bookStride
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
            verbFocus: try r.optionalRecord(base + 128, read: r.verb)
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
