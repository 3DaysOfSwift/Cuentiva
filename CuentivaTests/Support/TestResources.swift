import Foundation

enum TestResources {
    // This helper lives in CuentivaTests/Support. Tests may move without breaking fixture paths.
    static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
