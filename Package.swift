// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "Jarvis",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Jarvis", linkerSettings: [.linkedLibrary("sqlite3")]),
        .testTarget(name: "JarvisTests", dependencies: ["Jarvis"]),
    ],
    swiftLanguageModes: [.v5]
)
