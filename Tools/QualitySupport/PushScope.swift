import Foundation

extension PushGate {
    enum Scope: String, Codable {
        case docs
        case full
    }

    /// Use both sides of every change so that moving code into docs still runs the app checks.
    func scope(base: String, head: String) throws -> Scope {
        let range = try [commit(base) + "..." + commit(head), "--"]
        let diff = ["diff", "--no-ext-diff", "--no-textconv", "--no-renames"]
        let raw = try git(diff + ["--raw", "--no-abbrev", "-z"] + range)
        let fields = raw.split(separator: "\0")
        guard !fields.isEmpty, fields.count.isMultiple(of: 2) else { return .full }
        var blobs = Set<Substring>()
        for index in stride(from: 0, to: fields.count, by: 2) {
            let metadata = fields[index].split(separator: " ")
            guard metadata.count == 5, [":100644", ":000000"].contains(metadata[0]),
                ["100644", "000000"].contains(metadata[1]), ["A", "D", "M"].contains(metadata[4]),
                Self.isProsePath(fields[index + 1])
            else { return .full }
            if metadata[0] != ":000000" { blobs.insert(metadata[2]) }
            if metadata[1] != "000000" { blobs.insert(metadata[3]) }
        }
        let stats = try Self.size(git(diff + ["--numstat", "-z"] + range))
        guard stats.binaries == 0 else { return .full }
        for blob in blobs {
            // Git samples the beginning of each blob to detect binaries. Check the rest too.
            let id = String(blob)
            guard let length = try Int(git(["cat-file", "-s", id])), length <= 1_048_576,
                let text = try? git(["cat-file", "blob", id]),
                text.utf8.allSatisfy({ $0 == 9 || $0 == 10 || $0 == 13 || ($0 >= 32 && $0 != 127) })
            else { return .full }
        }
        return .docs
    }

    // Operational policies for review, architecture and verification are themselves gate inputs.
    private static let engineeringPolicies: Set<String> = [
        "agent-workflow-51.md", "authority-boundaries-49.md", "native-boundaries-48.md",
        "native-ui.md", "push-guardrails.md", "swift_quality.md", "traceability-54.md",
        "workspace-boundaries-46.md", "test-quality.md", "command-timeouts.md",
        "performance-47.md", "verification-44.md", "rewrite-verification.md",
    ]

    private static func isProsePath(_ path: Substring) -> Bool {
        if path == "README.md" { return true }
        let parts = path.split(separator: "/")
        guard parts.first == "docs", path.hasSuffix(".md"), let name = parts.last,
            !parts.contains(where: { $0.hasPrefix(".") }),
            path.rangeOfCharacter(from: .controlCharacters) == nil
        else { return false }
        if parts.count >= 3, parts[1].lowercased() == "planning" { return false }
        if parts.count == 3, parts[1].lowercased() == "engineering",
            engineeringPolicies.contains(name.lowercased())
        {
            return false
        }
        return !["agents.md", "agents.override.md", "claude.md", "claude.local.md", "skill.md"]
            .contains(name.lowercased())
    }
}
