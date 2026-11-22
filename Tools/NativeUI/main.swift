import CryptoKit
import Foundation
import QualitySupport

struct NativeGateSummary: Encodable {
    let passed: Bool
    let tests: Int
    let discoveredTests: Int
    let shard: Int?
}

let files = FileManager.default
let root = URL(fileURLWithPath: files.currentDirectoryPath)
let runID = UUID().uuidString
let output = root.appendingPathComponent("test-results/native-ui/\(runID)")
let derived = root.appendingPathComponent(".build/native-ui-\(runID)")

func run(_ executable: String, _ arguments: [String], log: String, timeout: TimeInterval = 120)
    throws
{
    let path = output.appendingPathComponent(log)
    let pending = output.appendingPathComponent("command-incomplete")
    try Data().write(to: pending)
    let status = try Command(executable, arguments, directory: root).run(
        log: path, timeout: timeout)
    try FileManager.default.removeItem(at: pending)
    guard status == 0 else {
        throw QualityFailure(
            "\(executable) failed (\(status)); see \(log).\n\(try Diagnostics.tail(of: path))")
    }
}

func json(_ name: String) throws -> Any {
    try JSONSerialization.jsonObject(with: Data(contentsOf: output.appendingPathComponent(name)))
}

func verifyProjectSources() throws {
    let data = try Data(contentsOf: root.appendingPathComponent("Jarvis.xcodeproj/project.pbxproj"))
    guard
        let project = try PropertyListSerialization.propertyList(from: data, format: nil)
            as? [String: Any],
        let objects = project["objects"] as? [String: [String: Any]]
    else {
        throw QualityFailure("Invalid Xcode project.")
    }
    let built = Set(
        objects.values.filter { $0["isa"] as? String == "PBXSourcesBuildPhase" }
            .flatMap { $0["files"] as? [String] ?? [] }
            .compactMap { objects[$0]?["fileRef"] as? String }
            .compactMap { objects[$0]?["path"] as? String })
    var owned = Set<String>()
    for directory in [
        "Sources/Jarvis", "Sources/JarvisDomain", "Sources/JarvisWorkspace", "UITests",
    ] {
        guard
            let enumerator = FileManager.default.enumerator(
                atPath: root.appendingPathComponent(directory).path)
        else {
            throw QualityFailure("Missing owned source directory: \(directory)")
        }
        for case let path as String in enumerator where path.hasSuffix(".swift") {
            owned.insert(directory + "/" + path)
        }
    }
    guard built == owned else {
        throw QualityFailure("Xcode source membership differs from owned app/UI sources.")
    }
}

do {
    let shard: NativeUIReport.Shard?
    switch Array(CommandLine.arguments.dropFirst()) {
    case []: shard = nil
    case ["--shard=1"]: shard = .interactions
    case ["--shard=2"]: shard = .remaining
    default: throw QualityFailure("Usage: native-ui-check [--shard=1|--shard=2]")
    }
    try files.createDirectory(at: output, withIntermediateDirectories: true)
    defer {
        if files.fileExists(atPath: derived.path)
            && !files.fileExists(atPath: output.appendingPathComponent("command-incomplete").path)
        {
            do { try files.removeItem(at: derived) } catch {
                FileHandle.standardError.write(
                    Data("Could not remove this run's derived data.\n".utf8))
            }
        }
    }
    try verifyProjectSources()
    try run("/usr/bin/xcodebuild", ["-version"], log: "xcode-version.log")
    try run("/usr/bin/swift", ["--version"], log: "swift-version.log")
    try run("/usr/bin/git", ["rev-parse", "HEAD"], log: "commit.log")
    try ProcessInfo.processInfo.operatingSystemVersionString.write(
        to: output.appendingPathComponent("os.txt"), atomically: true, encoding: .utf8)
    var common = [
        "-project", "Jarvis.xcodeproj", "-scheme", "NativeUI", "-configuration", "Release",
        "-destination", "platform=macOS", "-derivedDataPath", derived.path,
        "-parallel-testing-enabled", "NO",
    ]
    if shard != nil {
        // Build the Release fixture for the machine that actually executes the
        // tests. Unsharded verification keeps its original architecture settings.
        common += ["ONLY_ACTIVE_ARCH=YES", "ARCHS=$(NATIVE_ARCH_ACTUAL)"]
    }
    try run("/usr/bin/xcodebuild", ["build-for-testing"] + common, log: "build.log", timeout: 600)
    let app = derived.appendingPathComponent("Build/Products/Release/JarvisVerification.app")
    let executable = app.appendingPathComponent("Contents/MacOS/JarvisVerification")
    let hash = SHA256.hash(data: try Data(contentsOf: executable)).map {
        String(format: "%02x", $0)
    }.joined()
    try files.copyItem(at: app, to: output.appendingPathComponent("JarvisVerification.app"))
    try Diagnostics.writeJSON(
        ["binary_sha256": hash, "configuration": "Release", "run_id": runID],
        to: output.appendingPathComponent("artifact.json"))
    try run(
        "/usr/bin/xcodebuild",
        ["test-without-building"] + common + [
            "-enumerate-tests",
            "-test-enumeration-format", "json", "-test-enumeration-output-path",
            output.appendingPathComponent("discovery.json").path,
        ],
        log: "discovery.log", timeout: 180)
    let result = output.appendingPathComponent("NativeUI.xcresult")
    try run(
        "/usr/bin/xcodebuild",
        ["test-without-building"] + common + (shard?.xcodeFilters ?? []) + [
            "-resultBundlePath", result.path,
            "-maximum-test-execution-time-allowance", "90", "-test-timeouts-enabled", "YES",
        ], log: "test.log", timeout: 600)
    for kind in ["summary", "tests"] {
        try run(
            "/usr/bin/xcrun",
            ["xcresulttool", "get", "test-results", kind, "--path", result.path, "--compact"],
            log: "\(kind).json")
    }
    let required = try JSONDecoder().decode(
        [String].self,
        from: Data(contentsOf: root.appendingPathComponent("UITests/required-tests.json")))
    guard let summary = try json("summary.json") as? [String: Any] else {
        throw QualityFailure("Missing native UI result summary.")
    }
    let discovery = try json("discovery.json")
    let count = try NativeUIReport.validate(
        discovery: discovery, results: json("tests.json"),
        summary: summary, required: Set(required), shard: shard)
    let fullCount = NativeUIReport.identifiers(in: discovery).count
    try Diagnostics.writeJSON(
        NativeGateSummary(
            passed: true, tests: count, discoveredTests: fullCount, shard: shard?.rawValue),
        to: output.appendingPathComponent(shard == nil ? "gate.json" : "shard-gate.json"))
    print(
        "Native UI verification passed: \(count) of \(fullCount) discovered tests. Evidence: \(output.path)"
    )
} catch {
    let result = output.appendingPathComponent("NativeUI.xcresult")
    if files.fileExists(atPath: result.path) {
        do {
            try run(
                "/usr/bin/xcrun",
                [
                    "xcresulttool", "export", "attachments", "--path", result.path,
                    "--output-path", output.appendingPathComponent("attachments").path,
                ], log: "export.log")
            try run(
                "/usr/bin/xcrun",
                [
                    "xcresulttool", "export", "diagnostics", "--path", result.path,
                    "--output-path", output.appendingPathComponent("diagnostics").path,
                ], log: "diagnostics-export.log")
        } catch {
            FileHandle.standardError.write(
                Data("Additional result export failed; original result bundle is retained.\n".utf8))
        }
    }
    FileHandle.standardError.write(
        Data((Diagnostics.redact(error.localizedDescription) + "\nEvidence: \(output.path)\n").utf8)
    )
    exit(1)
}
