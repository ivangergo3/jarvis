import CryptoKit
import Foundation
import Testing

@testable import QualitySupport

@Suite("Project skill discovery layout")
struct SkillLayoutTests {
    @Test func bothProvidersReadTheSameSourceAndEditsInvalidateCatalogue() throws {
        let fixture = try makeFixture()
        #expect(try SkillLayout.inspect(root: fixture.url).map(\.name) == ["example"])
        let original = try Data(
            contentsOf: fixture.url.appendingPathComponent("skills/example/SKILL.md"))
        for provider in [".agents", ".claude"] {
            #expect(
                try Data(
                    contentsOf: fixture.url.appendingPathComponent(
                        "\(provider)/skills/example/SKILL.md")) == original)
        }
        try Data("changed".utf8).write(
            to: fixture.url.appendingPathComponent("skills/example/SKILL.md"))
        #expect(throws: (any Error).self) { try SkillLayout.inspect(root: fixture.url) }
    }

    @Test func wrongExternalAndBrokenLinksAreRejected() throws {
        for target in ["../../../skills/example", "/private/tmp", "../../skills/missing"] {
            let fixture = try makeFixture()
            let link = fixture.url.appendingPathComponent(".agents/skills/example")
            try FileManager.default.removeItem(at: link)
            try FileManager.default.createSymbolicLink(
                atPath: link.path, withDestinationPath: target)
            #expect(throws: (any Error).self) { try SkillLayout.inspect(root: fixture.url) }
        }
        let fixture = try makeFixture()
        let source = fixture.url.appendingPathComponent("skills/example")
        let external = try TemporaryDirectory(prefix: "external-skill-")
        try FileManager.default.removeItem(at: source)
        try FileManager.default.createSymbolicLink(at: source, withDestinationURL: external.url)
        #expect(throws: (any Error).self) { try SkillLayout.inspect(root: fixture.url) }
    }

    @Test func missingUnexpectedAndCopiedEntriesAreRejected() throws {
        let fixture = try makeFixture()
        let link = fixture.url.appendingPathComponent(".claude/skills/example")
        try FileManager.default.removeItem(at: link)
        #expect(throws: (any Error).self) { try SkillLayout.inspect(root: fixture.url) }
        try FileManager.default.copyItem(
            at: fixture.url.appendingPathComponent("skills/example"), to: link)
        #expect(throws: (any Error).self) { try SkillLayout.inspect(root: fixture.url) }
        try FileManager.default.removeItem(at: link)
        try FileManager.default.createSymbolicLink(
            atPath: link.path, withDestinationPath: "../../skills/example")
        try FileManager.default.createDirectory(
            at: fixture.url.appendingPathComponent(".agents/skills/extra"),
            withIntermediateDirectories: true)
        #expect(throws: (any Error).self) { try SkillLayout.inspect(root: fixture.url) }
    }

    @Test func invalidManifestMetadataAndStaleHashesAreRejected() throws {
        let fixture = try makeFixture()
        let manifest = fixture.url.appendingPathComponent("Tools/project-skills.json")
        for value in ["[]", "[\"example\",\"example\"]", "[\"../escape\"]", "not JSON"] {
            try Data(value.utf8).write(to: manifest)
            #expect(throws: (any Error).self) { try SkillLayout.inspect(root: fixture.url) }
        }
        try Data("[\"example\"]".utf8).write(to: manifest)
        let catalog = fixture.url.appendingPathComponent("docs/planning/skill-catalog.json")
        try Data("[]".utf8).write(to: catalog)
        #expect(throws: (any Error).self) { try SkillLayout.inspect(root: fixture.url) }
        let clean = try makeFixture()
        let source = clean.url.appendingPathComponent("skills/example/SKILL.md")
        let data = try Data(contentsOf: source)
        var changed = data
        changed.append(Data("\nNew instruction\n".utf8))
        try changed.write(to: source)
        #expect(throws: (any Error).self) { try SkillLayout.inspect(root: clean.url) }
    }

    @Test func failedCheckCannotLeaveOldSuccessEvidence() throws {
        let fixture = try makeFixture()
        let output = fixture.url.appendingPathComponent("results")
        try SkillLayout.check(root: fixture.url, output: output)
        try FileManager.default.removeItem(
            at: fixture.url.appendingPathComponent(".agents/skills/example"))
        #expect(throws: (any Error).self) {
            try SkillLayout.check(root: fixture.url, output: output)
        }
        let report = try JSONDecoder().decode(
            [String: Bool].self,
            from: Data(contentsOf: output.appendingPathComponent("skill-layout.json")))
        #expect(report == ["passed": false])
    }

    private func makeFixture() throws -> TemporaryDirectory {
        let fixture = try TemporaryDirectory(prefix: "skill-layout-")
        let files = FileManager.default
        for path in [
            "Tools", "docs/planning", "skills/example", ".agents/skills", ".claude/skills",
        ] {
            try files.createDirectory(
                at: fixture.url.appendingPathComponent(path), withIntermediateDirectories: true)
        }
        let skill = Data(
            "---\nname: example\ndescription: \"Synthetic example\"\n---\n# Example\n".utf8)
        try skill.write(to: fixture.url.appendingPathComponent("skills/example/SKILL.md"))
        try Data("[\"example\"]".utf8).write(
            to: fixture.url.appendingPathComponent("Tools/project-skills.json"))
        let hash = SHA256.hash(data: skill).map { String(format: "%02x", $0) }.joined()
        let catalog = [["name": "example", "path": "skills/example/SKILL.md", "sha256": hash]]
        try JSONEncoder().encode(catalog).write(
            to: fixture.url.appendingPathComponent("docs/planning/skill-catalog.json"))
        for provider in [".agents", ".claude"] {
            try files.createSymbolicLink(
                atPath: fixture.url.appendingPathComponent("\(provider)/skills/example").path,
                withDestinationPath: "../../skills/example")
        }
        return fixture
    }
}
