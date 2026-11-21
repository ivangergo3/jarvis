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
        let raw = try git(diff + ["--raw", "-z"] + range)
        let fields = raw.split(separator: "\0")
        guard !fields.isEmpty, fields.count.isMultiple(of: 2) else { return .full }
        for index in stride(from: 0, to: fields.count, by: 2) {
            let metadata = fields[index].split(separator: " ")
            guard metadata.count == 5, [":100644", ":000000"].contains(metadata[0]),
                ["100644", "000000"].contains(metadata[1]), ["A", "D", "M"].contains(metadata[4]),
                Self.isProsePath(fields[index + 1])
            else { return .full }
        }
        let stats = try Self.size(git(diff + ["--numstat", "-z"] + range))
        return stats.binaries == 0 ? .docs : .full
    }

    // These documents supply working instructions to agents through AGENTS.md or the review prompt.
    private static let engineeringPolicies: Set<String> = [
        "agent-workflow-51.md", "authority-boundaries-49.md", "native-boundaries-48.md",
        "native-ui.md", "push-guardrails.md", "swift_quality.md", "traceability-54.md",
        "workspace-boundaries-46.md",
    ]

    private static func isProsePath(_ path: Substring) -> Bool {
        if path == "README.md" { return true }
        let parts = path.split(separator: "/")
        guard parts.first == "docs", path.hasSuffix(".md"), let name = parts.last,
            !parts.contains(where: { $0.hasPrefix(".") }),
            path.rangeOfCharacter(from: .controlCharacters) == nil
        else { return false }
        if parts.count == 3, parts[1].lowercased() == "engineering",
            engineeringPolicies.contains(name.lowercased())
        {
            return false
        }
        return !["agents.md", "claude.md", "skill.md"].contains(name.lowercased())
    }
}
