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
            checksPassed: true, nativeUI: "unavailable: requires full Xcode; CI required")
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
                swiftArguments: [], checksPassed: passed, nativeUI: native)
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

    private final class Fixture {
        let temporary: TemporaryDirectory
        var root: URL { temporary.url }
        init() throws { temporary = try TemporaryDirectory(prefix: "push-fixture-") }
        var reviews = 0
        var reviewPrompt: String?
        var checks = 0
        var nativeAvailable = false
        var nativeChecks = 0
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
            if command.arguments == ["swift", "--version"] {
                try "Synthetic Swift".write(to: log, atomically: true, encoding: .utf8)
                return 0
            }
            if command.arguments.first == "codex" {
                reviewPrompt = command.arguments.last
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
                            completed: failure != "incomplete",
                            followUps: failure == "review-missing-field"
                                ? nil : ["Optional suggestion"]),
                        to: url)
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
        try fixture.setup()
        let gate = fixture.gate()
        #expect(throws: QualityFailure.self) { try gate.run(["verify"]) }
        let brief =
            "Criteria: reuse exact evidence. Previous finding: stale approvals. Test: changed SDK."
        try gate.prepare(intent: brief, swiftArguments: [])
        #expect(fixture.reviewPrompt?.contains(brief) == true)
        try gate.run(["verify"])
        #expect(!FileManager.default.fileExists(atPath: try #require(fixture.candidate).path))
        try gate.prepare(intent: brief, swiftArguments: [])
        #expect(fixture.reviews == 1 && fixture.checks == 1 && fixture.nativeChecks == 1)
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
            "snapshot-mutation", "review-head", "snapshot-head", "incomplete",
            "review-missing-field",
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
        environment["HOOK"] = project.appendingPathComponent(".githooks/pre-push").path
        let gate = PushGate(root: root)
        let identity = try gate.identity()
        environment["PUSH_INPUT"] =
            "refs/heads/topic \(identity.head) refs/heads/topic "
            + String(repeating: "0", count: 40)
        let command = Command(
            "/bin/bash", ["-c", "printf '%s\\n' \"$PUSH_INPUT\" | bash \"$HOOK\" origin"],
            directory: root, environment: environment)
        let log = support.url.appendingPathComponent("hook.log")
        #expect(try command.run(log: log, timeout: 60) != 0)
        try FileManager.default.createDirectory(
            at: gate.directory(identity.head), withIntermediateDirectories: true)
        // Synthetic receipt exercises hook wiring, not actual model/test execution.
        try Diagnostics.writeJSON(
            PushGate.Receipt(
                identity: identity,
                review: .init(
                    base: identity.base, head: identity.head, summary: "Fixture", findings: [],
                    limitations: [], completed: true),
                intent: "Fixture", swiftArguments: [], checksPassed: true,
                nativeUI: identity.nativeAvailable
                    ? "passed" : "unavailable: requires full Xcode; CI required"),
            to: gate.directory(identity.head).appendingPathComponent("receipt.json"))
        #expect(try command.run(log: log, timeout: 60) == 0)
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
