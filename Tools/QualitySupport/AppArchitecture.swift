import Foundation

/// Source policy inside the executable module; compiler isolation remains at the package targets.
public enum AppArchitecture {
    private enum Layer: String {
        case shared = "Shared"
        case application = "Application"
        case integrations = "Integrations"
        case presentation = "Presentation"
        case composition = "Composition"

        var imports: Set<String> {
            switch self {
            case .shared: ["Foundation"]
            case .application: ["Foundation", "Combine", "JarvisDomain"]
            case .integrations:
                ["Foundation", "Combine", "AppKit", "AVFoundation", "Speech", "ImageIO", "Darwin"]
            case .presentation:
                ["Foundation", "Combine", "AppKit", "SwiftUI", "QuartzCore", "JarvisDomain"]
            case .composition: []
            }
        }
    }

    private static func layer(_ path: String) -> Layer? {
        if path == "Sources/Jarvis/Main.swift" { return .composition }
        let parts = path.split(separator: "/")
        guard parts.count >= 4, parts[0] == "Sources", parts[1] == "Jarvis",
            let layer = Layer(rawValue: String(parts[2]))
        else { return nil }
        if layer == .presentation {
            guard parts.count >= 5, ["Views", "Components", "Platform"].contains(parts[3]) else {
                return nil
            }
        }
        return layer
    }

    private static func declarations(_ tokens: [String], topLevelOnly: Bool = true) -> Set<String> {
        var depth = 0
        var names = Set<String>()
        for index in tokens.indices {
            let token = tokens[index]
            if token == "{" { depth += 1 }
            if token == "}" { depth -= 1 }
            if !topLevelOnly || depth == 0,
                ["struct", "enum", "class", "actor", "protocol", "typealias"].contains(token),
                index + 1 < tokens.count, index == 0 || tokens[index - 1] != "import"
            {
                names.insert(tokens[index + 1])
            }
        }
        return names
    }

    public static func violations(sources: [String: String]) -> [String] {
        let tokenized = sources.mapValues {
            WorkspaceArchitecture.codeTokens($0, punctuation: true)
        }
        var owners: [String: Set<Layer>] = [:]
        for (path, tokens) in tokenized {
            guard let owner = layer(path) else { continue }
            for name in declarations(tokens) { owners[name, default: []].insert(owner) }
        }
        var findings: [String] = []
        for (path, tokens) in tokenized.sorted(by: { $0.key < $1.key }) {
            guard let current = layer(path) else {
                findings.append("\(path): uncategorized app source")
                continue
            }
            guard current != .composition else { continue }
            for index in tokens.indices where tokens[index] == "import" {
                var next = index + 1
                if next < tokens.count,
                    ["struct", "class", "enum", "protocol", "func", "var", "let", "typealias"]
                        .contains(tokens[next])
                {
                    next += 1
                }
                if next < tokens.count, !current.imports.contains(tokens[next]) {
                    findings.append("\(path): forbidden import \(tokens[next])")
                }
            }
            var effects: Set<String> = [
                "FileManager", "FileHandle", "Process", "URLSession", "NSOpenPanel", "NSSavePanel",
                "NSAppleScript", "SQLite3", "resourceValues", "activateFileViewerSelecting",
                "CGImageSourceCreateWithURL",
            ]
            if current == .integrations { effects = [] }
            if current != .integrations,
                path != "Sources/Jarvis/Presentation/Platform/HUDAnimations.swift"
            {
                effects.insert("contentsOf")
            }
            if current != .integrations,
                path != "Sources/Jarvis/Application/DashboardState.swift"
            {
                effects.insert("UserDefaults")
            }
            for token in Set(tokens).intersection(effects).sorted() {
                findings.append("\(path): forbidden effect \(token)")
            }
            // Native clipboard/window/art rendering is permitted; launching another app is not.
            if current == .presentation,
                tokens.contains("NSWorkspace") && tokens.contains("open")
            {
                findings.append("\(path): external launches belong in Integrations")
            }
            let references = Set(tokens).subtracting(declarations(tokens, topLevelOnly: false))
            for name in references.sorted() {
                for owner in (owners[name] ?? []).sorted(by: { $0.rawValue < $1.rawValue }) {
                    if !allows(current, to: owner, name: name) {
                        findings.append("\(path): forbidden \(owner.rawValue) reference \(name)")
                    }
                }
            }
            if current == .presentation {
                for index in tokens.indices
                where ["LocalVoice", "DesktopActions", "CompanionArtwork"].contains(tokens[index]) {
                    if index + 1 < tokens.count,
                        tokens[index + 1] == "(" || tokens[index + 1] == "."
                    {
                        findings.append("\(path): inject \(tokens[index]) from composition")
                    }
                }
            }
        }
        return Array(Set(findings)).sorted()
    }

    private static func allows(_ from: Layer, to: Layer, name: String) -> Bool {
        if from == to || to == .shared || from == .composition { return true }
        if from == .presentation {
            return to == .application
                || (to == .integrations
                    && ["LocalVoice", "DesktopActions", "CompanionArtwork"].contains(name))
        }
        return false
    }

    public static func check(root: URL, output: URL) throws {
        let directory = root.appendingPathComponent("Sources/Jarvis").resolvingSymlinksInPath()
        guard
            let files = FileManager.default.enumerator(
                at: directory, includingPropertiesForKeys: nil)
        else {
            throw QualityFailure("Missing app source root")
        }
        var sources: [String: String] = [:]
        for case let url as URL in files where url.pathExtension == "swift" {
            let normalized = url.resolvingSymlinksInPath()
            guard normalized.path.hasPrefix(directory.path + "/") else {
                throw QualityFailure("App source escapes its root")
            }
            let path = "Sources/Jarvis/" + normalized.path.dropFirst(directory.path.count + 1)
            sources[path] = try String(contentsOf: normalized, encoding: .utf8)
        }
        guard !sources.isEmpty else { throw QualityFailure("Empty app source root") }
        let findings = violations(sources: sources)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try Diagnostics.writeJSON(
            findings, to: output.appendingPathComponent("app-architecture.json"))
        guard findings.isEmpty else { throw QualityFailure(findings.joined(separator: "\n")) }
    }
}
