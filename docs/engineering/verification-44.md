# Issue 44 verification — 2026-11-16

## Swift-only tooling revision

The initial scripting implementation below was replaced at the owner's request.
All active app-test fixtures and quality/CI tooling now use Swift and native
Foundation APIs, with Swift Testing for the tooling's own tests. There are no
third-party Swift packages or Python runtime requirements for these commands.
The `QualitySupport` and `quality-gate` targets use Swift 6 language mode and
are not dependencies of the shipping Jarvis executable.

```sh
swift run quality-gate test
swift run quality-gate mutations
```

The native full gate passed **99 tests**: the same 92 application tests plus
seven tooling tests. Checks cover full inventory, malformed/oversized/empty
reports, skips, nonzero exit/signal, timeout and descendant cleanup, redacted
diagnostics, and a green XML file accompanying a failed process. The former
Python stdio fixture was replaced with a synthetic Swift server compiled using
the installed toolchain, preserving literal-text and close/cancellation checks.

The Swift mutation command separately reproduced all three original → defective
assertion failure → restored-green sequences in a disposable source copy, with
exactly one matching test per invocation. The record under “Local synthetic
evidence” describes the original implementation and remains historical evidence;
its six scripting self-tests have been replaced by the seven Swift tests.

The required GitHub check name and branch-protection policy are unchanged.
The native revision runs through that same required check; consult the latest
PR-head result. The earlier failed-merge proof below establishes GitHub's merge
policy, rather than a dependency on a particular test-runner implementation.

## Local synthetic evidence

Base: `526106396c63dbb20197212b6c623c063330f0dd`; initial implementation:
`b80ed8f973626c16a7b94ef8f9182e251c9c42f0`.

A separate clean worktree containing only this ticket's changes passed the full
gate: **92 Swift tests, zero skips/failures**, exit 0. Its release `build.sh`
passed and produced an ad-hoc signed app. Local toolchain: Apple Swift 6.4.2
(`swiftlang-6.4.2.1.9`), arm64 macOS 27.2 Command Line Tools, with the local
testing-plugin path supplied through `--swift-arg`. Full Xcode is not installed
locally; GitHub uses Xcode 16.4 on `macos-15-intel`.

The runner self-tests passed (six after the final process-failure regression was
added). They exercise empty/missing/malformed results, skips, failures, partial
selection, missing critical tests, process errors, signal termination, timeout,
bounded/redacted output, and rejection of otherwise-green XML after exit 7.

The explicit disposable mutation diagnostic produced these assertion outcomes:

| Seeded defect | Selected assertion | Original | Defective | Restored |
| --- | --- | --- | --- | --- |
| Accept valid non-object JSON | `validJSONThatIsNotAnObjectIsRejected` | exit 0 | exit 1, assertion failure | exit 0 |
| Remove refresh-revision protection | `historyStartedBeforeSendCannotEraseTheQueuedMessage` | exit 0 | exit 1, assertion failure | exit 0 |
| Expire at `>= 1800` instead of `> 1800` seconds | `startMarkerExpiresOnlyAfterThirtyMinutes` | exit 0 | exit 1, assertion failure | exit 0 |

Each invocation matched exactly the intended test, with no skips. Compiler
errors were not counted as mutation detections. No production files were
mutated. The subsequent helper cleanup shares the same process-group timeout
code between the normal gate and diagnostic; runner self-tests were rerun.

## Repository enforcement and safe negative probe

Initial audit found **no branch protection and no rulesets**. The repository
administrator credential was available. Within #44's required-check scope,
`main` now has:

- Required context `macOS build and tests`, pinned to GitHub Actions app ID
  **15368**, with up-to-date branches required.
- Enforcement for administrators enabled; force pushes and branch deletion
  disabled; changes must come through pull requests.
- Zero required approving reviews, deliberately retaining the solo owner's
  ability to merge their own passing PR. This is an explicit review-policy
  choice, not evidence of independent human review.

No `continue-on-error`, quarantined tests, skipped-test allowances or bypass
actors were added. These branch settings are external GitHub configuration;
future changes to them can invalidate this evidence.

[Disposable PR #59](https://github.com/ivangergo3/jarvis/pull/59) was a ready
(not draft) PR with one intentionally failing synthetic Swift assertion at head
`159c282272bf275390e058a99170c53d8b9f6971`.
[Its required check failed](https://github.com/ivangergo3/jarvis/actions/runs/43944611514):
93 tests executed with exactly one issue from the deliberate assertion, process
exit 1; bounded `summary.json` / `failure.log` artifacts uploaded successfully.
The build and bundle verification steps were correctly skipped after failure.

After rechecking enforced administrator protection and the failed check's exact
app/head SHA, an ordinary squash-merge API request with that expected SHA was
rejected:

```text
HTTP 405
Required status check "macOS build and tests" is failing.
```

`main` was `526106396c63dbb20197212b6c623c063330f0dd` both before and after.
The probe was then closed **without merging**, and its temporary remote branch
deleted. This proves the failed required check blocked that ordinary merge path
with an administrator credential; it does not prove no administrator could
later edit protection settings.

The GraphQL `repository.mergeQueue(branch: "main")` query returned `null`, and
there are no queue rulesets: **no merge queue is configured**. A queued merge
was not exercised. The workflow retains `merge_group` support; enabling a queue
later requires a separate actual queue verification.

## Scope and remaining limits

The implementation PR is [#58](https://github.com/ivangergo3/jarvis/pull/58).
Its workflow runs the full gate, a release build and bundle verification. Check
the latest PR-head result before merging; a result on an earlier head is not
approval for later changes. The first run used upload-artifact v4 successfully;
the final workflow pins v7 (Node 24) with the same verified artifact inputs.

No live Codex messages, private conversation data, microphones, paid services
or native UI automation were used. Destination/approval tests assert protocol
contracts through fakes; they do not certify compatibility with every live
Codex version. No whole-app readiness or performance claim follows from this
ticket. PR #58 is left open for review, not merged automatically.
