// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Jarvis",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "JarvisDomain"),
        .target(
            name: "JarvisWorkspace", dependencies: ["JarvisDomain"],
            linkerSettings: [.linkedLibrary("sqlite3")]),
        .executableTarget(name: "Jarvis", dependencies: ["JarvisDomain", "JarvisWorkspace"]),
        .testTarget(
            name: "JarvisTests",
            dependencies: ["Jarvis", "JarvisDomain", "JarvisWorkspace", "QualitySupport"]),
        .executableTarget(
            name: "native-ui-check", dependencies: ["QualitySupport"], path: "Tools/NativeUI"),
        .target(
            name: "QualitySupport", path: "Tools/QualitySupport",
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .executableTarget(
            name: "quality-gate", dependencies: ["QualitySupport"],
            path: "Tools/QualityGate", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "QualitySupportTests", dependencies: ["QualitySupport"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
    ],
    swiftLanguageModes: [.v6]
)
