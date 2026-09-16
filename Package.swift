// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CuentivaCore",
    platforms: [.macOS(.v15)],
    products: [.library(name: "CuentivaCore", targets: ["CuentivaCore"])],
    targets: [
        .target(name: "CuentivaCore", path: "Cuentiva/2 - AppModel", exclude: ["AppModel.swift", "Features/Audio"]),
        .testTarget(name: "CuentivaCoreTests", dependencies: ["CuentivaCore"], path: "CuentivaTests", exclude: ["ViewModelTests.swift"])
    ]
)
