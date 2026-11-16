import Foundation
import QualitySupport

@main
enum QualityGate {
    static func main() {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            let mode = arguments.first ?? "test"
            var root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            var output: URL?
            var swiftArguments: [String] = []
            var index = 1
            while index < arguments.count {
                let value = arguments[index]
                if value.hasPrefix("--swift-arg=") {
                    swiftArguments.append(String(value.dropFirst("--swift-arg=".count)))
                } else if ["--root", "--output"].contains(value), index + 1 < arguments.count {
                    index += 1
                    let url = URL(fileURLWithPath: arguments[index])
                    if value == "--root" { root = url } else { output = url }
                } else {
                    throw QualityFailure("Usage: swift run quality-gate [test|mutations] [--root path] [--output path] [--swift-arg=value]")
                }
                index += 1
            }
            let destination = output ?? root.appendingPathComponent("test-results")
            switch mode {
            case "test":
                let summary = try TestGate.run(root: root, swiftArguments: swiftArguments, output: destination)
                print("Tests: \(summary.testCases), passed: \(summary.passed)")
                if let error = summary.error { FileHandle.standardError.write(Data((error + "\n").utf8)) }
                if !summary.passed { exit(1) }
            case "mutations":
                try FaultProbe.run(root: root, swiftArguments: swiftArguments, output: destination)
            default:
                throw QualityFailure("Unknown quality-gate command: \(mode)")
            }
        } catch {
            FileHandle.standardError.write(Data((Diagnostics.redact(error.localizedDescription) + "\n").utf8))
            exit(1)
        }
    }
}
