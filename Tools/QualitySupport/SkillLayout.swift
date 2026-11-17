import CryptoKit
import Foundation

/// Checks the repository's discovery wiring; never starts an agent or installs a skill.
public enum SkillLayout {
    private struct CatalogEntry: Decodable {
        let name: String
        let path: String
        let sha256: String
    }

    public struct Entry: Codable, Equatable {
        public let name: String
        public let sha256: String
    }

    public static func check(root: URL, output: URL) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let report = output.appendingPathComponent("skill-layout.json")
        try Diagnostics.writeJSON(["passed": false], to: report)
        let entries = try inspect(root: root)
        struct Report: Encodable {
            let passed = true
            let runtimeDiscoveryVerified = false
            let skills: [Entry]
        }
        try Diagnostics.writeJSON(Report(skills: entries), to: report)
        print("Skill layout: \(entries.count) shared skills; Codex and Claude links checked")
    }

    public static func inspect(root: URL) throws -> [Entry] {
        let files = FileManager.default
        let root = root.standardizedFileURL.resolvingSymlinksInPath()
        let names = try JSONDecoder().decode(
            [String].self, from: bounded(root.appendingPathComponent("Tools/project-skills.json")))
        guard !names.isEmpty, Set(names).count == names.count,
            names.allSatisfy({
                $0.count <= 64
                    && $0.range(of: "^[a-z][a-z0-9-]*$", options: .regularExpression) != nil
            })
        else { throw QualityFailure("Invalid or duplicate project skill names") }
        let catalog = try JSONDecoder().decode(
            [CatalogEntry].self,
            from: bounded(root.appendingPathComponent("docs/planning/skill-catalog.json")))
        for directory in [".agents", ".claude", ".agents/skills", ".claude/skills", "skills"] {
            let url = root.appendingPathComponent(directory)
            guard
                try files.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType
                    == .typeDirectory
            else { throw QualityFailure("Skill discovery roots must be real directories") }
        }
        for provider in [".agents/skills", ".claude/skills"] {
            let actual = try files.contentsOfDirectory(
                atPath: root.appendingPathComponent(provider).path)
            guard Set(actual) == Set(names) else {
                throw QualityFailure("Project skill inventory differs in \(provider)")
            }
            for name in names {
                let link = root.appendingPathComponent(provider).appendingPathComponent(name)
                guard
                    try files.destinationOfSymbolicLink(atPath: link.path)
                        == "../../skills/\(name)",
                    link.resolvingSymlinksInPath().path
                        == root.appendingPathComponent("skills/\(name)").path
                else { throw QualityFailure("Project skill link must target its canonical source") }
            }
        }
        return try names.map { name in
            let relative = "skills/\(name)/SKILL.md"
            let source = root.appendingPathComponent(relative)
            guard source.resolvingSymlinksInPath().path == source.path else {
                throw QualityFailure("Skill source must stay at its canonical repository path")
            }
            let data = try bounded(source)
            let lines = String(decoding: data, as: UTF8.self).components(separatedBy: "\n")
            guard lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---") else {
                throw QualityFailure("Missing skill frontmatter: \(name)")
            }
            let header = Array(lines[1..<end])
            let descriptions = header.filter { $0.hasPrefix("description: ") }
            guard header.filter({ $0.hasPrefix("name: ") }) == ["name: \(name)"],
                descriptions.count == 1,
                descriptions[0].dropFirst("description: ".count)
                    .trimmingCharacters(
                        in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\"'"))
                    )
                    .isEmpty == false
            else { throw QualityFailure("Skill name/description mismatch: \(name)") }
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let matches = catalog.filter { $0.name == name }
            guard matches.count == 1, matches[0].path == relative, matches[0].sha256 == hash else {
                throw QualityFailure("Skill catalogue does not match source: \(name)")
            }
            return Entry(name: name, sha256: hash)
        }
    }

    private static func bounded(_ url: URL) throws -> Data {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let data = try file.read(upToCount: 65_537) ?? Data()
        guard data.count <= 65_536 else { throw QualityFailure("Oversized skill metadata file") }
        return data
    }
}
