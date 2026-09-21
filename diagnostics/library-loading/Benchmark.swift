//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation

@main struct Benchmark {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 4 else { throw AppFailure.unavailable("Pass JSON, library DAT and introduction DAT paths.") }
        let json = URL(fileURLWithPath: args[1]), binary = URL(fileURLWithPath: args[2]), intro = URL(fileURLWithPath: args[3])
        let expected = try JSONDecoder().decode([Book].self, from: Data(contentsOf: json))
        let actual = try BinaryLibrary(url: binary).books()
        guard expected == actual else { throw AppFailure.unavailable("Binary round trip changed book content.") }
        print("Verified exact equality of all \(actual.count) books, including text and optional metadata.")
        try measure("JSON: read + all Book values") { try JSONDecoder().decode([Book].self, from: Data(contentsOf: json)).count }
        try measure("DAT: read + header only") { try BinaryLibrary(url: binary).count }
        try measure("DAT: read + first complete Book") { try BinaryLibrary(url: binary).book(at: 0).fullText.count }
        try measure("DAT: read + all Book values") { try BinaryLibrary(url: binary).books().count }
        try measure("Introduction DAT: read + complete Book") { try BinaryLibrary(url: intro).book(at: 0).fullText.count }
    }
    static func measure(_ label: String, operation: () throws -> Int) throws {
        var samples: [Double] = []
        var consumed = 0
        for _ in 0..<101 {
            let start = DispatchTime.now().uptimeNanoseconds
            consumed += try operation()
            samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
        }
        let first = samples.removeFirst()
        samples.sort()
        print(String(format: "%@: first %.3f ms, median %.3f ms, p95 %.3f ms; checksum %d", label, first, samples[50], samples[95], consumed))
    }
}
