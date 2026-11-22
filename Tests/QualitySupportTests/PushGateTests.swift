import Foundation
import Testing

@testable import QualitySupport

@Suite("Small PR and push guardrails")
struct PushGateTests {
    @Test func incompleteReviewCannotApproveEvenWithNoFindings() throws {
        let json =
            #"{"base":"base","head":"head","summary":"Unable to finish","findings":[],"limitations":["Could not read changed files"],"completed":false}"#
        let review = try JSONDecoder().decode(PushGate.Review.self, from: Data(json.utf8))
        let identity = PushGate.Identity(
            base: "base", head: "head", toolchain: "swift", nativeAvailable: false)
        let receipt = PushGate.Receipt(
            identity: identity, review: review, intent: "Expected behaviour", swiftArguments: [],
            checksPassed: true, nativeUI: "unavailable: requires full Xcode; CI required",
            typeScriptAttempt: UUID())
        #expect(throws: QualityFailure.self) { try PushGate.validate(receipt, identity: identity) }
    }
    @Test func countsAllChangesAndBlocksOverLimit() throws {
        let value = try PushGate.size(
            ["1000\t500\tTests/new\tfile.swift", "-\t-\timage.png", "1000\t0\tpnpm-lock.yaml"]
                .joined(separator: "\0"))
        #expect(value == PushGate.Size(lines: 2500, binaries: 1))
        try PushGate.checkSize(value)
        #expect(throws: QualityFailure.self) { try PushGate.checkSize(.init(lines: 2501)) }
        #expect(throws: QualityFailure.self) { try PushGate.size("invalid") }
        #expect(throws: QualityFailure.self) { try PushGate.size("-1\t0\tfile\0") }
    }

    @Test(arguments: [1999, 2000, 2499, 2500])
    func sizeWarningStartsAtTwoThousand(lines: Int) throws {
        var messages: [String] = []
        try PushGate.checkSize(.init(lines: lines)) { messages.append($0) }
        #expect(messages.contains { $0.contains("WARNING TO AGENT") } == (lines >= 2000))
    }

    @Test func secretsFailWithoutEchoingTheSecret() throws {
        let secret = "sk-" + String(repeating: "x", count: 40)
        #expect(throws: QualityFailure.self) { try PushGate.checkSecrets("+key = \(secret)") }
        #expect(throws: QualityFailure.self) { try PushGate.checkSecrets("+++" + secret) }
        #expect(throws: QualityFailure.self) {
            try PushGate.checkSecrets("+-----BEGIN " + "PRIVATE KEY-----")
        }
        try PushGate.checkSecrets("-\(secret)\n+normal content")
    }

    @Test func outgoingRefsMustMatchReviewedCandidate() throws {
        try PushGate.validatePush("refs/heads/topic abc refs/heads/topic def\n", head: "abc")
        for row in [
            "refs/heads/topic stale refs/heads/topic def",
            "refs/heads/topic abc refs/heads/main def",
            "refs/tags/tag abc refs/tags/tag def", "(delete) 000 refs/heads/topic def", "",
            "refs/heads/a abc refs/heads/a def\nrefs/heads/b abc refs/heads/b def",
        ] {
            #expect(throws: QualityFailure.self) { try PushGate.validatePush(row, head: "abc") }
        }
    }

    @Test func receiptsRequireExactPassingEvidence() throws {
        let identity = PushGate.Identity(
            base: "base", head: "head", toolchain: "swift", nativeAvailable: false)
        let good = PushGate.Review(
            base: "base", head: "head", summary: "Reviewed", findings: [], limitations: [],
            completed: true)
        func receipt(
            _ review: PushGate.Review = good, passed: Bool = true,
            native: String = "unavailable: requires full Xcode; CI required"
        ) -> PushGate.Receipt {
            .init(
                identity: identity, review: review, intent: "Expected behaviour",
                swiftArguments: [], checksPassed: passed, nativeUI: native,
                typeScriptAttempt: UUID())
        }
        try PushGate.validate(receipt(), identity: identity)
        for candidate in [
            PushGate.Identity(
                base: "new", head: "head", toolchain: "swift", nativeAvailable: false),
            .init(base: "base", head: "new", toolchain: "swift", nativeAvailable: false),
            .init(base: "base", head: "head", toolchain: "new", nativeAvailable: false),
            .init(base: "base", head: "head", toolchain: "swift", nativeAvailable: true),
            .init(
                base: "base", head: "head", toolchain: "swift", nativeAvailable: false, scope: .docs
            ),
            .init(
                base: "base", head: "head", toolchain: "swift", nativeAvailable: false,
                developerIdentity: "different Xcode/SDK"),
            .init(
                base: "base", head: "head", toolchain: "swift", nativeAvailable: false,
                nodeToolchain: "different Node or pnpm"),
            .init(
                base: "base", head: "head", toolchain: "swift", nativeAvailable: false,
                checkoutRoot: "another clone"),
        ] {
            #expect(throws: QualityFailure.self) {
                try PushGate.validate(receipt(), identity: candidate)
            }
        }
        for bad in [
            receipt(passed: false), receipt(native: "passed"),
            receipt(
                .init(
                    base: "base", head: "head", summary: "", findings: [], limitations: [],
                    completed: true)),
            receipt(
                .init(
                    base: "base", head: "head", summary: "Reviewed", findings: ["A bug"],
                    limitations: [], completed: true)),
            receipt(
                .init(
                    base: "base", head: "wrong", summary: "Reviewed", findings: [], limitations: [],
                    completed: true)
            ),
        ] {
            #expect(throws: QualityFailure.self) { try PushGate.validate(bad, identity: identity) }
        }
    }

    private static func writeAttempt(_ attempt: URL, revision: String, scenario: String = "valid")
        throws
    {
        let reports = attempt.appendingPathComponent("vitest")
        try FileManager.default.createDirectory(at: reports, withIntermediateDirectories: true)
        try VitestEvidenceTests.writeVitest(
            at: reports,
            candidate: PushGate.workspace(
                for: try #require(UUID(uuidString: attempt.lastPathComponent))),
            revision: revision,
            scenario: scenario)
    }

    private final class Fixture {
        let temporary: TemporaryDirectory
        var root: URL { temporary.url }
        init() throws { temporary = try TemporaryDirectory(prefix: "push-fixture-") }
        deinit {
            // A failing production verification retains the worktree for inspection.
            if let candidate { _ = try? git(["worktree", "remove", "--force", candidate.path]) }
        }
        var reviews = 0
        var checks = 0
        var nativeAvailable = false
        var nativeChecks = 0
        var nodeProbes = 0
        var typeScriptChecks = 0
        var failure = ""
        var candidate: URL?
        var sdk = "Synthetic SDK 1"
        func git(_ args: [String]) throws -> String { try PushGate(root: root).git(args) }
        func commitChanges() throws -> String {
            _ = try git(["add", "-A"])
            _ = try git(["commit", "-qm", "Synthetic change"])
            return try git(["rev-parse", "HEAD"])
        }
        func write(_ path: String, _ data: Data) throws {
            let file = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: file)
        }
        func setup(feature: String = "feature.txt", content: String = "feature\n") throws {
            _ = try git(["init", "-q"])
            _ = try git(["config", "user.name", "Synthetic Test"])
            _ = try git(["config", "user.email", "test@example.invalid"])
            _ = try git(["config", "core.hooksPath", "/dev/null"])
            try ".build/\n".write(
                to: root.appendingPathComponent(".gitignore"), atomically: true, encoding: .utf8)
            try "base\n".write(
                to: root.appendingPathComponent("base.txt"), atomically: true, encoding: .utf8)
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent("Tools"), withIntermediateDirectories: true)
            try Diagnostics.writeJSON(
                [["file": "fixtures/nested.vitest.ts", "name": "Nesting > works"]],
                to: root.appendingPathComponent("Tools/required-vitest.json"))
            _ = try git(["add", "."])
            _ = try git(["commit", "-qm", "base"])
            _ = try git(["update-ref", "refs/remotes/origin/main", "HEAD"])
            try write(feature, Data(content.utf8))
            _ = try commitChanges()
        }
        func runner(_ command: Command, _ log: URL, _ timeout: TimeInterval) throws -> Int32 {
            if command.executable == "/usr/bin/xcodebuild" {
                guard nativeAvailable else { return 1 }
                try "Synthetic Xcode".write(to: log, atomically: true, encoding: .utf8)
                return 0
            }
            if command.arguments == ["swift", "run", "native-ui-check"] {
                nativeChecks += 1
                #expect(reviews == 1 && checks == 1)
                return 0
            }
            if command.executable == "/usr/bin/xcrun",
                command.arguments.first?.hasPrefix("--show-sdk-") == true
            {
                try sdk.write(to: log, atomically: true, encoding: .utf8)
                return 0
            }
            if command.arguments == ["node", "--version"]
                || command.arguments == ["pnpm", "--version"]
            {
                nodeProbes += 1
                let version =
                    failure == "snapshot-toolchain" && command.directory != root
                    ? "Different working directory toolchain" : "Fixture toolchain"
                try version.write(to: log, atomically: true, encoding: .utf8)
                return 0
            }
            if command.arguments == ["swift", "--version"] {
                try "Synthetic Swift".write(to: log, atomically: true, encoding: .utf8)
                return 0
            }
            if command.arguments.first == "codex" {
                candidate = command.directory
                reviews += 1
                #expect(command.arguments.contains("read-only"))
                #expect(command.arguments.contains("--ephemeral"))
                #expect(command.arguments.contains("--ignore-user-config"))
                #expect(command.directory != root)
                if failure == "review-exit" { return 1 }
                if failure == "review-timeout" { throw QualityFailure("Synthetic timeout") }
                if failure == "review-head" {
                    _ = try PushGate(root: command.directory).git([
                        "checkout", "--detach", git(["rev-parse", "origin/main"]),
                    ])
                }
                let index = try #require(command.arguments.firstIndex(of: "--output-last-message"))
                let url = URL(fileURLWithPath: command.arguments[index + 1])
                if failure == "malformed" {
                    try "{}".write(to: url, atomically: true, encoding: .utf8)
                } else {
                    try Diagnostics.writeJSON(
                        PushGate.Review(
                            base: git(["rev-parse", "origin/main"]),
                            head: git(["rev-parse", "HEAD"]),
                            summary: "Synthetic independent review",
                            findings: failure == "findings" ? ["Bug"] : [], limitations: [],
                            completed: failure != "incomplete"),
                        to: url)
                }
                return 0
            }
            if command.arguments.first == "scripts/check-typescript.sh" {
                typeScriptChecks += 1
                #expect(reviews == 1 && checks == 1)
                #expect(
                    !command.directory.resolvingSymlinksInPath().path.hasPrefix(
                        root.resolvingSymlinksInPath().path + "/"))
                #expect(command.arguments.last == root.appendingPathComponent(".pnpm-store").path)
                if failure == "typescript-exit" { return 1 }
                return 0
            }
            if command.arguments.starts(with: ["pnpm", "exec", "vitest"]) {
                #expect(reviews == 1 && checks == 1 && typeScriptChecks == 1)
                let listing = command.arguments[3] == "list"
                if listing && failure == "discovery-exit" || !listing && failure == "vitest-exit" {
                    return 1
                }
                if listing && failure == "missing-report"
                    || !listing && failure == "execution-missing"
                {
                    return 0
                }
                let generated = try TemporaryDirectory(prefix: "synthetic-vitest-")
                try VitestEvidenceTests.writeVitest(at: generated.url, candidate: command.directory)
                let reports = log.deletingLastPathComponent()
                func deliver(_ name: String) throws {
                    try FileManager.default.copyItem(
                        at: generated.url.appendingPathComponent(name),
                        to: reports.appendingPathComponent(name))
                }
                try deliver(listing ? "vitest-discovery.json" : "vitest-results.json")
                if listing && failure == "early-result" { try deliver("vitest-results.json") }
                if !listing && failure == "changed-discovery" {
                    try Data("[]".utf8).write(
                        to: reports.appendingPathComponent("vitest-discovery.json"))
                }
                return 0
            }
            if command.executable == "/bin/bash" {
                checks += 1
                #expect(reviews == 1)
                #expect(command.directory != root)
                if failure == "mutation" {
                    try "dirty".write(
                        to: root.appendingPathComponent("base.txt"), atomically: true,
                        encoding: .utf8)
                }
                if failure == "snapshot-mutation" {
                    try "dirty".write(
                        to: command.directory.appendingPathComponent("base.txt"), atomically: true,
                        encoding: .utf8)
                }
                if failure == "snapshot-head" {
                    _ = try PushGate(root: command.directory).git([
                        "checkout", "--detach", git(["rev-parse", "origin/main"]),
                    ])
                }
                return failure == "tests" ? 1 : 0
            }
            return try command.run(log: log, timeout: timeout)
        }
        func gate() -> PushGate { PushGate(root: root, runner: runner) }
    }

    @Test func successfulPrepareRunsReviewThenTestsAndReusesExactReceipt() throws {
        let fixture = try Fixture()
        fixture.nativeAvailable = true
        try fixture.setup(feature: "Sources/Feature.swift", content: "struct Feature {}\n")
        try fixture.write("fixtures/feature.ts", Data("export const feature = true;\n".utf8))
        try fixture.write("docs/feature.md", Data("Feature behavior.\n".utf8))
        _ = try fixture.commitChanges()
        let gate = fixture.gate()
        #expect(throws: QualityFailure.self) { try gate.run(["verify"]) }
        try gate.prepare(intent: "Expected behaviour", swiftArguments: [])
        try gate.run(["verify"])
        #expect(!FileManager.default.fileExists(atPath: try #require(fixture.candidate).path))
        try gate.prepare(intent: "Expected behaviour", swiftArguments: [])
        #expect(fixture.reviews == 1 && fixture.checks == 1 && fixture.nativeChecks == 1)
        #expect(fixture.typeScriptChecks == 1)
        _ = try fixture.git(["update-ref", "refs/remotes/origin/main", "HEAD"])
        #expect(throws: QualityFailure.self) { try gate.run(["verify"]) }
    }

    @Test func documentationRequiresReviewAndSkipsBothProductSuites() throws {
        let fixture = try Fixture()
        fixture.nativeAvailable = true
        try fixture.setup(feature: "docs/engineering/cloud-harness-rewrite-plan.md")
        for path in [
            "docs/engineering/local-command-stream.md",
            "docs/engineering/local-service-contract.md",
            "docs/engineering/rewrite-verification.md",
            "docs/engineering/swift-feature-visual-inventory.md",
            "docs/engineering/test-quality.md", "docs/engineering/agent-workflow-51.md",
            "docs/planning/SKILL_SAFETY.md", "docs/planning/SKILL_EVALUATION.md",
        ] {
            try fixture.write(path, Data("Updated plan\n".utf8))
        }
        _ = try fixture.commitChanges()
        let gate = fixture.gate()
        let identity = try gate.identity()
        #expect(identity.scope == .docs)
        fixture.failure = "findings"
        #expect(throws: QualityFailure.self) {
            try gate.prepare(intent: "Document the fixture", swiftArguments: [])
        }
        #expect(throws: QualityFailure.self) { try gate.verify(identity) }
        fixture.failure = ""
        try gate.prepare(intent: "Document the fixture", swiftArguments: [])
        try gate.verify(identity)
        try gate.prepare(intent: "Document the fixture", swiftArguments: [])
        #expect(fixture.reviews == 2 && fixture.checks == 0 && fixture.nativeChecks == 0)
        #expect(fixture.nodeProbes == 0 && fixture.typeScriptChecks == 0)
    }

    @Test func cancellationAtPublicationAndNewGitRefsPreventApproval() throws {
        let fixture = try Fixture()
        try fixture.setup(feature: "README.md")
        let gate = fixture.gate()
        let identity = try gate.identity()
        #expect(throws: QualityFailure.self) {
            try gate.prepare(intent: "Document the fixture", swiftArguments: []) { _ in
                throw QualityFailure("Interrupted after encoding and before publication")
            }
        }
        #expect(throws: QualityFailure.self) { try gate.verify(identity) }
        try gate.prepare(intent: "Document the fixture", swiftArguments: [])
        try gate.verify(identity)
        #expect(throws: QualityFailure.self) {
            try gate.prepare(intent: "New intent", swiftArguments: []) { _ in
                throw QualityFailure("Interrupted while revalidating old receipt")
            }
        }
        try gate.verify(identity)
        try fixture.write("README.md", Data("A concurrent local edit".utf8))
        #expect(throws: QualityFailure.self) { try gate.verify(identity) }
        _ = try fixture.git(["restore", "--", "README.md"])
        _ = try fixture.git(["update-ref", "refs/remotes/origin/main", identity.head])
        #expect(throws: QualityFailure.self) { try gate.verify(identity) }
    }

    @Test func documentationWhitespaceFailsBeforeIndependentReview() throws {
        let fixture = try Fixture()
        try fixture.setup(feature: "README.md", content: "Trailing space \n")
        let gate = fixture.gate()
        #expect(throws: QualityFailure.self) { try gate.run(["ci"]) }
        #expect(throws: QualityFailure.self) { try gate.run(["integration"]) }
        #expect(throws: QualityFailure.self) {
            try gate.prepare(intent: "Document the fixture", swiftArguments: [])
        }
        #expect(fixture.reviews == 0 && fixture.checks == 0)
    }

    @Test func whitespaceDiagnosticsDoNotPrintCredentialFilenames() throws {
        let fixture = try Fixture()
        let secret = "ghp_" + String(repeating: "x", count: 40)
        try fixture.setup(feature: "docs/" + secret + ".md", content: "Trailing space \n")
        do {
            try fixture.gate().run(["ci"])
            Issue.record("Whitespace check should reject the candidate")
        } catch let error as QualityFailure {
            #expect(!error.message.contains(secret))
        }
    }

    @Test func scopeUsesBothGitPathsAndTheCompleteCommittedDifference() throws {
        let fixture = try Fixture()
        try fixture.setup(feature: "README.md")
        let gate = fixture.gate()
        let base = try fixture.git(["rev-parse", "origin/main"])
        let readme = try fixture.git(["rev-parse", "HEAD"])
        #expect(try gate.scope(base: base, head: readme) == .docs)
        #expect(try gate.scope(base: readme, head: readme) == .full)

        try fixture.write("docs/planning/GITHUB_TICKETS.md", Data("Status\n".utf8))
        try fixture.write("docs/guide with spaces.md", Data("Initial\n".utf8))
        let added = try fixture.commitChanges()
        #expect(try gate.scope(base: readme, head: added) == .docs)
        try fixture.write("docs/guide with spaces.md", Data("Revised\n".utf8))
        let edited = try fixture.commitChanges()
        #expect(try gate.scope(base: added, head: edited) == .docs)
        _ = try fixture.git(["mv", "docs/guide with spaces.md", "docs/renamed.md"])
        let renamed = try fixture.commitChanges()
        #expect(try gate.scope(base: edited, head: renamed) == .docs)
        _ = try fixture.git(["mv", "docs/renamed.md", "source.swift"])
        let mixed = try fixture.commitChanges()
        #expect(try gate.scope(base: base, head: mixed) == .full)
        #expect(try gate.scope(base: renamed, head: mixed) == .full)
        _ = try fixture.git(["mv", "source.swift", "docs/renamed.md"])
        let restored = try fixture.commitChanges()
        #expect(try gate.scope(base: mixed, head: restored) == .full)
        _ = try fixture.git(["rm", "docs/renamed.md"])
        let deleted = try fixture.commitChanges()
        #expect(try gate.scope(base: restored, head: deleted) == .docs)
    }

    @Test func executableBinarySymlinkAndPolicyChangesRequireFullVerification() throws {
        let fixture = try Fixture()
        try fixture.setup(feature: "docs/guide.md")
        let gate = fixture.gate()
        var base = try fixture.git(["rev-parse", "HEAD"])
        func requireFull() throws {
            let head = try fixture.commitChanges()
            #expect(try gate.scope(base: base, head: head) == .full)
            base = head
        }
        for path in [
            "planning.md", "docs/engineering/push-guardrails.md",
            "docs/nested/AGENTS.md", "docs/nested/AGENTS.override.md",
            "docs/nested/CLAUDE.local.md",
            "docs/nested/CLAUDE.md", "docs/nested/SKILL.md", "docs/.private/guide.md",
            "docs/.hidden.md", "docs/example.swift", ".github/workflows/check.yml",
        ] {
            try fixture.write(path, Data("Proposed change\n".utf8))
            try requireFull()
        }
        try fixture.write("docs/control-prefix.md", Data([11]) + Data("Example".utf8))
        try requireFull()
        try fixture.write("docs/binary-tail.md", Data(repeating: 65, count: 10000) + Data([0]))
        try requireFull()
        try fixture.write("docs/data.md", Data([0, 1, 2]))
        try requireFull()
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: fixture.root.appendingPathComponent("docs/guide.md").path)
        try requireFull()
        try FileManager.default.createSymbolicLink(
            atPath: fixture.root.appendingPathComponent("docs/link.md").path,
            withDestinationPath: "guide.md")
        try requireFull()
    }

    @Test func cltSDKChangesInvalidateEvidence() throws {
        let fixture = try Fixture()
        try fixture.setup()
        let gate = fixture.gate()
        try gate.prepare(intent: "Expected behaviour", swiftArguments: [])
        try gate.run(["verify"])
        fixture.sdk = "Synthetic SDK 2"
        #expect(throws: QualityFailure.self) { try gate.run(["verify"]) }
    }

    @Test func failuresAndMutationsCannotCreateReceipts() throws {
        for failure in [
            "review-exit", "review-timeout", "malformed", "findings", "tests", "mutation",
            "snapshot-mutation", "review-head", "snapshot-head", "incomplete", "typescript-exit",
            "missing-report", "discovery-exit", "vitest-exit", "execution-missing", "early-result",
            "changed-discovery", "snapshot-toolchain",
        ] {
            let fixture = try Fixture()
            try fixture.setup()
            fixture.failure = failure
            let gate = fixture.gate()
            #expect(throws: (any Error).self) {
                try gate.prepare(intent: "Expected behaviour", swiftArguments: [])
            }
            let head = try fixture.git(["rev-parse", "HEAD"])
            #expect(FileManager.default.fileExists(atPath: try #require(fixture.candidate).path))
            #expect(
                !FileManager.default.fileExists(
                    atPath: gate.directory(head).appendingPathComponent("receipt.json").path))
            if failure.hasPrefix("review") || failure == "malformed" || failure == "findings"
                || failure == "incomplete"
            {
                #expect(fixture.checks == 0)
            }
        }
    }

    @Test func cumulativeSizeAndUntrackedFilesAreNotHidden() throws {
        let fixture = try Fixture()
        try fixture.setup()
        let root = fixture.root
        let gate = fixture.gate()
        try String(repeating: "line\n", count: 2501).write(
            to: root.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)
        #expect(throws: QualityFailure.self) { try gate.identity() }
        _ = try fixture.git(["add", "new.txt"])
        #expect(throws: QualityFailure.self) { try gate.run(["size", "--staged"]) }
        _ = try fixture.git(["commit", "-qm", "oversized synthetic fixture"])
        #expect(throws: QualityFailure.self) { try gate.run(["ci"]) }
        try gate.run(["integration"])
        #expect(throws: QualityFailure.self) { try gate.run(["ci", "--staged"]) }
        #expect(throws: QualityFailure.self) { try gate.run(["prepare"]) }
    }

    @Test func gitDisplayPreferencesCannotHideAddedCredentials() throws {
        let fixture = try Fixture()
        try fixture.setup()
        _ = try fixture.git(["config", "color.ui", "always"])
        _ = try fixture.git(["config", "diff.outputIndicatorNew", "!"])
        try ("++sk-" + String(repeating: "x", count: 40)).write(
            to: fixture.root.appendingPathComponent("example.txt"), atomically: true,
            encoding: .utf8)
        _ = try fixture.git(["add", "example.txt"])
        do {
            try fixture.gate().run(["size", "--staged"])
            Issue.record("Credential scan accepted custom diff markers")
        } catch let error as QualityFailure {
            #expect(error.message.hasPrefix("Possible credential/private key"))
        }
    }

    @Test func outgoingHistoryAndCommitMessagesCannotHideCredentials() throws {
        for location in ["file", "message"] {
            let fixture = try Fixture()
            try fixture.setup()
            let secret = "sk-" + String(repeating: "x", count: 40)
            if location == "file" {
                try secret.write(
                    to: fixture.root.appendingPathComponent("example.txt"), atomically: true,
                    encoding: .utf8)
                _ = try fixture.git(["add", "example.txt"])
                _ = try fixture.git(["commit", "-qm", "synthetic addition"])
                _ = try fixture.git(["rm", "example.txt"])
                _ = try fixture.git(["commit", "-qm", "synthetic removal"])
            } else {
                _ = try fixture.git(["commit", "--allow-empty", "-qm", secret])
            }
            do {
                try fixture.gate().run(["ci"])
                Issue.record("Outgoing history credential was accepted")
            } catch let error as QualityFailure {
                #expect(error.message.hasPrefix("Possible credential/private key"))
            }
        }
    }

    @Test func actualHookBlocksMissingEvidenceAndAcceptsExactCandidate() throws {
        let fixture = try Fixture()
        try fixture.setup()
        let root = fixture.root
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let support = try TemporaryDirectory(prefix: "push-hook-")
        let remote = support.url.appendingPathComponent("remote.git")
        _ = try fixture.git(["clone", "--bare", root.path, remote.path])
        _ = try fixture.git([
            "--git-dir=" + remote.path, "update-ref", "refs/heads/main",
            fixture.git(["rev-parse", "origin/main"]),
        ])
        _ = try fixture.git(["remote", "add", "origin", remote.path])
        let shim = support.url.appendingPathComponent("swift")
        try """
        #!/bin/bash
        if [[ "$1" == --version ]]; then exec /usr/bin/swift --version; fi
        shift 2
        exec "$GATE_BINARY" "$@"
        """.write(to: shim, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: shim.path)
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = support.url.path + ":" + (environment["PATH"] ?? "/usr/bin:/bin")
        environment["GATE_BINARY"] =
            project.appendingPathComponent(".build/debug/quality-gate").path
        let hook = project.appendingPathComponent(".githooks/pre-push")
        try FileManager.default.copyItem(
            at: hook, to: support.url.appendingPathComponent("pre-push"))
        _ = try fixture.git(["config", "core.hooksPath", support.url.path])
        _ = try fixture.git(["switch", "-c", "topic"])
        // The synthetic repository has no package installation. Select fixture tools for both identities.
        for tool in ["node", "pnpm"] {
            let url = support.url.appendingPathComponent(tool)
            try "#!/bin/sh\necho fixture-1\n".write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        let gate = PushGate(root: root) { command, log, timeout in
            var command = command
            command.environment = environment
            return try command.run(log: log, timeout: timeout)
        }
        let identity = try gate.identity()
        var pushEnvironment = environment
        pushEnvironment["TMPDIR"] = support.url.path
        let push = Command(
            "/usr/bin/git", ["push", "origin", "topic"], directory: root,
            environment: pushEnvironment)
        let log = support.url.appendingPathComponent("hook.log")
        #expect(try push.run(log: log, timeout: 60) != 0)
        #expect(try Diagnostics.tail(of: log).contains("No review/test receipt"))
        let attempt = UUID()
        let output = gate.directory(identity.head).appendingPathComponent(attempt.uuidString)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        // Synthetic receipt exercises hook wiring, not actual model/test execution.
        try Diagnostics.writeJSON(
            PushGate.Receipt(
                identity: identity,
                review: .init(
                    base: identity.base, head: identity.head, summary: "Fixture", findings: [],
                    limitations: [], completed: true),
                intent: "Fixture", swiftArguments: [], checksPassed: true,
                nativeUI: identity.nativeAvailable
                    ? "passed" : "unavailable: requires full Xcode; CI required",
                typeScriptAttempt: attempt),
            to: gate.directory(identity.head).appendingPathComponent("receipt.json"))
        #expect(try push.run(log: log, timeout: 60) != 0)
        #expect(
            try Diagnostics.tail(of: log).contains("Missing Vitest discovery or result evidence"))
        try Self.writeAttempt(output, revision: identity.head, scenario: "missing-required")
        #expect(try push.run(log: log, timeout: 60) != 0)
        #expect(
            try Diagnostics.tail(of: log).contains(
                "Vitest inventory, totals or required cases are incomplete"))
        #expect(try fixture.git(["ls-remote", "origin", "refs/heads/topic"]).isEmpty)
        try Self.writeAttempt(output, revision: identity.head, scenario: "unhandled")
        #expect(try push.run(log: log, timeout: 60) != 0)
        #expect(try Diagnostics.tail(of: log).contains("Vitest process failed"))
        #expect(try fixture.git(["ls-remote", "origin", "refs/heads/topic"]).isEmpty)
        try Self.writeAttempt(output, revision: identity.head, scenario: "stale")
        #expect(try push.run(log: log, timeout: 60) != 0)
        #expect(
            try Diagnostics.tail(of: log).contains("Vitest reports refer to a different commit"))
        try Self.writeAttempt(output, revision: identity.head)
        let finalStatus = try push.run(log: log, timeout: 60)
        let diagnostic = try Diagnostics.tail(of: log)
        #expect(finalStatus == 0, Comment(rawValue: diagnostic))
        #expect(
            try fixture.git(["ls-remote", "origin", "refs/heads/topic"]).hasPrefix(identity.head))
    }

    @Test func interruptedPrepareStopsWorkerAndIssuesNoReceipt() throws {
        let fixture = try Fixture()
        try fixture.setup(feature: "docs/fixture.md")
        let support = try TemporaryDirectory(prefix: "push-interrupt-")
        let reviewer = support.url.appendingPathComponent("codex")
        try """
        #!/bin/sh
        /bin/sleep 30 &
        echo "$!" > "$WORKER_PID_FILE"
        kill -INT "$PPID"
        wait
        """.write(to: reviewer, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: reviewer.path)
        let marker = support.url.appendingPathComponent("pid")
        let intent = support.url.appendingPathComponent("intent")
        try "Check interruption".write(to: intent, atomically: true, encoding: .utf8)
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = support.url.path + ":" + (environment["PATH"] ?? "/usr/bin:/bin")
        environment["WORKER_PID_FILE"] = marker.path
        let log = support.url.appendingPathComponent("prepare.log")
        let command = Command(
            project.appendingPathComponent(".build/debug/quality-gate").path,
            ["push", "prepare", "--intent-file=" + intent.path],
            directory: fixture.root, environment: environment)
        #expect(try command.run(log: log, timeout: 20) != 0)
        #expect(try Diagnostics.tail(of: log).contains("Push preparation interrupted"))
        let pid = try #require(
            Int32(
                String(contentsOf: marker, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines)))
        if let info = try OwnedProcessTree.inspect(pid) {
            #expect(info.pbi_status == UInt32(SZOMB))
        }
        let head = try fixture.git(["rev-parse", "HEAD"])
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.root.appendingPathComponent(
                    ".build/push-gate/\(head)/receipt.json"
                ).path))
    }

    @Test func installerPreservesExistingHooks() throws {
        let fixture = try Fixture()
        try fixture.setup()
        let root = fixture.root
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("scripts"), withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: project.appendingPathComponent("scripts/install-hooks.sh"),
            to: root.appendingPathComponent("scripts/install-hooks.sh"))
        try FileManager.default.copyItem(
            at: project.appendingPathComponent(".githooks"),
            to: root.appendingPathComponent(".githooks"))
        let command = Command("/bin/bash", ["scripts/install-hooks.sh"], directory: root)
        let log = root.appendingPathComponent("install.log")
        #expect(try command.run(log: log, timeout: 30) != 0)
        #expect(try fixture.git(["config", "--get", "core.hooksPath"]) == "/dev/null")
        _ = try fixture.git(["config", "--unset", "core.hooksPath"])
        let hook = root.appendingPathComponent(".git/hooks/pre-push")
        try "existing hook".write(to: hook, atomically: true, encoding: .utf8)
        #expect(try command.run(log: log, timeout: 30) != 0)
        #expect(try String(contentsOf: hook, encoding: .utf8) == "existing hook")
        try FileManager.default.removeItem(at: hook)
        let otherHook = root.appendingPathComponent(".git/hooks/commit-msg")
        try "other existing hook".write(to: otherHook, atomically: true, encoding: .utf8)
        #expect(try command.run(log: log, timeout: 30) != 0)
        #expect(try String(contentsOf: otherHook, encoding: .utf8) == "other existing hook")
        try FileManager.default.removeItem(at: otherHook)
        #expect(try command.run(log: log, timeout: 30) == 0)
        #expect(try fixture.git(["config", "--get", "core.hooksPath"]) == ".githooks")
    }
}
