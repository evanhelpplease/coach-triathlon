// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TriathlonEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TriathlonEngine", targets: ["TriathlonEngine"]),
        .executable(name: "EngineChecks", targets: ["EngineChecks"])
    ],
    targets: [
        .target(
            name: "TriathlonEngine",
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        ),
        // Harnais de vérification SANS dépendance à XCTest : runnable via
        // `swift run EngineChecks` même quand seul le Command Line Tools est installé.
        .executableTarget(
            name: "EngineChecks",
            dependencies: ["TriathlonEngine"]
        ),
        // Suite XCTest complète : `swift test` une fois Xcode installé (+ CI).
        .testTarget(
            name: "TriathlonEngineTests",
            dependencies: ["TriathlonEngine"]
        )
    ]
)
