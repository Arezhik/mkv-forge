// swift-tools-version:5.9
import PackageDescription

let package = Package(
    // Not "MKVForge". That is the Xcode project's name, and the IDE drops the
    // products when the package and the project share a name and a folder.
    name: "MKVForgeKit",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .library(name: "MKVForgeCore", targets: ["MKVForgeCore"])
    ],
    targets: [
        // Core logic only: no AppKit, SwiftUI, or Vision imports, so `swift test`
        // runs on Linux (cloud agents and the Linux CI job) as well as on a Mac.
        .target(name: "MKVForgeCore"),
        .testTarget(name: "MKVForgeCoreTests", dependencies: ["MKVForgeCore"])
    ]
)
