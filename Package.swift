// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "Jarvis",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Jarvis", linkerSettings: [.linkedLibrary("sqlite3")]),
        .testTarget(name: "JarvisTests", dependencies: ["Jarvis", "QualitySupport"]),
        .target(name: "QualitySupport", path: "Tools/QualitySupport",
                swiftSettings: [.swiftLanguageMode(.v6)]),
        .executableTarget(name: "quality-gate", dependencies: ["QualitySupport"],
                          path: "Tools/QualityGate", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "QualitySupportTests", dependencies: ["QualitySupport"],
                    swiftSettings: [.swiftLanguageMode(.v6)]),
    ],
    swiftLanguageModes: [.v6]
)
