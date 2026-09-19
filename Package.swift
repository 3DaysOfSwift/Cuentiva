// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CuentivaAppModel",
    platforms: [.macOS(.v15)],
    products: [.library(name: "CuentivaAppModel", targets: ["CuentivaAppModel"])],
    targets: [
        .target(name: "CuentivaAppModel", path: "Cuentiva/2 - AppModel", exclude: ["AppModel.swift", "Features/Audio", "Features/Chat/AppleChatGenerator.swift", "Features/Fantasy/AppleFantasyGenerator.swift"]),
        .testTarget(
            name: "CuentivaAppModelTests",
            dependencies: ["CuentivaAppModel"],
            path: "CuentivaTests",
            exclude: [
                "PresentationTests", "AppModelTests/AppModelTests.swift", "Support/iOS",
                "IntegrationTests/SpeechCallbackTests.swift",
                "IntegrationTests/StorePurchaseTests.swift",
                "IntegrationTests/LibraryPresentationTests.swift",
                "README.md", "API-COVERAGE.md"
            ]
        )
    ]
)
