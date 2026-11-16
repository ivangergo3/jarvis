import Foundation

/// Explicit policy for the agreed workspace slice, not a general effect/security analyser.
public enum WorkspaceArchitecture {
    private struct Manifest: Decodable {
        let targets: [Target]
    }
    private struct Target: Decodable {
        let name: String
        let type: String
        let path: String?
        let exclude: [String]
        let dependencies: [Dependency]
    }
    private struct Dependency: Decodable {
        let name: String
        enum CodingKeys: String, CodingKey { case byName, target }
        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            for key in [CodingKeys.byName, .target] {
                if let parts = try values.decodeIfPresent([String?].self, forKey: key),
                    let first = parts.first, let first
                {
                    name = first
                    return
                }
            }
            // A product/unknown dependency in protected targets is not an allowed edge.
            name = "<external-or-unsupported>"
        }
    }
    private static let graph: [String: Set<String>] = [
        "JarvisDomain": [], "JarvisWorkspace": ["JarvisDomain"],
        "Jarvis": ["JarvisDomain", "JarvisWorkspace"],
    ]

    public static func graphViolations(_ data: Data) throws -> [String] {
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        var findings: [String] = []
        for (name, allowed) in graph.sorted(by: { $0.key < $1.key }) {
            let matches = manifest.targets.filter { $0.name == name }
            guard matches.count == 1, let target = matches.first else {
                findings.append("\(name): expected exactly one protected target")
                continue
            }
            if Set(target.dependencies.map(\.name)) != allowed {
                findings.append("\(name): dependencies must be \(allowed.sorted())")
            }
            if target.path != nil && target.path != "Sources/\(name)" {
                findings.append("\(name): unexpected source root")
            }
            if !target.exclude.isEmpty {
                findings.append("\(name): source exclusions require review")
            }
            if target.type != (name == "Jarvis" ? "executable" : "regular") {
                findings.append("\(name): unexpected target kind")
            }
        }
        return findings
    }

    public static func sourceViolations(_ source: String, path: String) -> [String] {
        let tokens = codeTokens(source)
        let domain = path.hasPrefix("Sources/JarvisDomain/")
        let adapter = path.hasPrefix("Sources/JarvisWorkspace/")
        let presentation = path.hasPrefix("Sources/Jarvis/") && path != "Sources/Jarvis/Main.swift"
        guard domain || adapter || presentation else { return [] }
        var findings: [String] = []
        for index in tokens.indices where tokens[index] == "import" {
            var next = index + 1
            if next < tokens.count,
                ["struct", "class", "enum", "protocol", "func", "var", "let", "typealias"].contains(
                    tokens[next])
            {
                next += 1
            }
            guard next < tokens.count else { continue }
            let module = tokens[next]
            if (domain && module != "Foundation")
                || (adapter && !["Foundation", "JarvisDomain", "SQLite3"].contains(module))
                || (presentation && module == "JarvisWorkspace")
            {
                findings.append("\(path): forbidden import \(module)")
            }
        }
        let forbidden: Set<String> =
            domain
            ? [
                "FileManager", "FileHandle", "Process", "URLSession", "UserDefaults",
                "JSONSerialization", "contentsOf",
            ]
            : (presentation ? ["CodexReader", "ReadOnlyDatabase", "LogObservation"] : [])
        for token in Set(tokens).intersection(forbidden).sorted() {
            findings.append("\(path): forbidden workspace boundary reference \(token)")
        }
        return findings
    }

    /// Ignore comments/literals before inspecting import and API tokens. Handles nested
    /// comments, escaped/extended/multiline strings and imports split across lines.
    private static func codeTokens(_ source: String) -> [String] {
        let text = Array(source)
        var index = 0
        var tokens: [String] = []
        func matches(_ value: String, at start: Int) -> Bool {
            let characters = Array(value)
            return start + characters.count <= text.count
                && Array(text[start..<(start + characters.count)]) == characters
        }
        while index < text.count {
            if matches("//", at: index) {
                while index < text.count && text[index] != "\n" { index += 1 }
            } else if matches("/*", at: index) {
                index += 2
                var depth = 1
                while index < text.count && depth > 0 {
                    if matches("/*", at: index) {
                        depth += 1
                        index += 2
                    } else if matches("*/", at: index) {
                        depth -= 1
                        index += 2
                    } else {
                        index += 1
                    }
                }
            } else {
                var quote = index
                while quote < text.count && text[quote] == "#" { quote += 1 }
                if quote < text.count && text[quote] == "\"" {
                    let hashes = String(repeating: "#", count: quote - index)
                    let delimiter = matches("\"\"\"", at: quote) ? "\"\"\"" : "\""
                    index = quote + delimiter.count
                    while index < text.count {
                        if matches("\\" + hashes, at: index) {
                            index += 2 + hashes.count
                        } else if matches(delimiter + hashes, at: index) {
                            index += delimiter.count + hashes.count
                            break
                        } else {
                            index += 1
                        }
                    }
                } else if text[index].isLetter || text[index] == "_" {
                    let start = index
                    while index < text.count
                        && (text[index].isLetter || text[index].isNumber || text[index] == "_")
                    { index += 1 }
                    tokens.append(String(text[start..<index]))
                } else {
                    index += 1
                }
            }
        }
        return tokens
    }

    public static func check(root: URL, output: URL) throws {
        let temporary = try TemporaryDirectory(prefix: "workspace-architecture-")
        let manifest = temporary.url.appendingPathComponent("package.json")
        let status = try Command(
            "/usr/bin/env", ["swift", "package", "dump-package"], directory: root
        )
        .run(log: manifest, timeout: 60)
        guard status == 0 else { throw QualityFailure("Cannot inspect SwiftPM dependency graph") }
        var findings = try graphViolations(Data(contentsOf: manifest))
        for module in graph.keys.sorted() {
            let directory = root.appendingPathComponent("Sources/\(module)")
                .resolvingSymlinksInPath()
            guard
                let files = FileManager.default.enumerator(
                    at: directory, includingPropertiesForKeys: nil)
            else {
                throw QualityFailure("Missing protected source root: \(module)")
            }
            for case let url as URL in files where url.pathExtension == "swift" {
                let normalized = url.resolvingSymlinksInPath()
                guard normalized.path.hasPrefix(directory.path + "/") else {
                    throw QualityFailure("Protected source escapes its module root")
                }
                let path =
                    "Sources/\(module)/" + normalized.path.dropFirst(directory.path.count + 1)
                findings += sourceViolations(
                    try String(contentsOf: normalized, encoding: .utf8), path: path)
            }
        }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try Diagnostics.writeJSON(
            findings.sorted(), to: output.appendingPathComponent("architecture.json"))
        guard findings.isEmpty else {
            throw QualityFailure(findings.sorted().joined(separator: "\n"))
        }
    }
}
