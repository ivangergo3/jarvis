import CryptoKit
import Foundation
import QualitySupport

struct NativeGateSummary: Encodable {
    let passed: Bool
    let tests: Int
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
    let status = try Command(executable, arguments, directory: root).run(
        log: path, timeout: timeout)
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
    for directory in ["Sources/Jarvis", "UITests"] {
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
    try files.createDirectory(at: output, withIntermediateDirectories: true)
    defer {
        if files.fileExists(atPath: derived.path) {
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
    let common = [
        "-project", "Jarvis.xcodeproj", "-scheme", "NativeUI", "-configuration", "Release",
        "-destination", "platform=macOS", "-derivedDataPath", derived.path,
        "-parallel-testing-enabled", "NO",
    ]
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
        ["test-without-building"] + common + [
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
    let count = try NativeUIReport.validate(
        discovery: json("discovery.json"), results: json("tests.json"),
        summary: summary, required: Set(required))
    try Diagnostics.writeJSON(
        NativeGateSummary(passed: true, tests: count),
        to: output.appendingPathComponent("gate.json"))
    print("Native UI verification passed: \(count) tests. Evidence: \(output.path)")
} catch {
    FileHandle.standardError.write(
        Data((Diagnostics.redact(error.localizedDescription) + "\nEvidence: \(output.path)\n").utf8)
    )
    exit(1)
}
