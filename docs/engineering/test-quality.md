# Test quality and merge gate

Implements #44 / QA-02, QA-03 and QA-05. These are fixture and protocol checks,
not evidence that the native UI or a live Codex integration is production-ready.
The separate [native UI gate](native-ui.md) covers bounded synthetic journeys (QA-04).

## Run locally

```sh
./scripts/format.sh bootstrap  # once, to build the pinned formatter
./scripts/check.sh             # formatter, concurrency probes, full test gate, release build
```

The native Swift executable uses Foundation for processes, XML, files and JSON.
`swift run quality-gate test` remains available to run only the test gate;
the shared check command also treats compiler warnings as errors.
Its own tests use Swift Testing alongside the app tests; there are no external
package dependencies or additional runtime requirements. The gate executes the
whole Swift Testing suite, then independently
discovers tests with `swift test list --skip-build`. Every discovered test must
appear in the fresh xUnit results. `Tools/critical-tests.json` additionally
guards against accidentally removing consequential tests from both discovery
and results. Update this reviewed list when deliberately renaming those tests.
It is a contract list, not a target for coverage percentages.

The wrapper fails on nonzero process exits (including crashes), missing or
malformed results, zero discovery/execution, omitted tests, failures/errors and
skips. It never converts a process failure into success because XML looks green.
Execution is bounded to ten minutes and discovery to one; timeout kills the
command's process group. Fresh temporary reports prevent a previous green run
from satisfying a failed run. SwiftPM variants that emit a separate
`*-swift-testing.xml` report are supported alongside empty XCTest reports.

On Macs using the Command Line Tools testing plugin, optional `--swift-arg=...`
arguments can supply that toolchain's plugin path. CI uses pinned Xcode 16.4
without machine-specific paths or such overrides. Filtering the full gate to a
subset will fail the inventory comparison; use ordinary `swift test --filter`
for focused development and the full gate before review.

## Consequential behaviours and independent oracles

| Behaviour | Assertion / independent expectation | Tests |
| --- | --- | --- |
| Untrusted framed input | Valid JSON scalars/arrays are rejected; exactly 1,048,576 bytes accepted and one more rejected; 64 deterministic chunk seeds reproduce literal known objects in order | `ProtocolBoundaryTests`, existing `ProtocolTests` |
| Stale lifecycle state | A start marker is working at exactly thirty minutes, unknown one second later; a supplied clock also defines snapshot time | `LifecycleBoundaryTests`, existing reader/log tests |
| Destination identity | Two identically named chats produce queue requests for distinct saved IDs, with no start/resume or interrupt side effects | `LinkedConversationTests.sameNamesUseDifferentIDsWithoutCreatingOrResumingThreads` |
| Late replies / cancellation | An explicitly held response from a closed old chat cannot replace the newly selected chat; pre-send history cannot erase a subsequently queued message | `ConversationRegressionTests` |
| Uncertain send | Same words with another client ID leave the outcome unknown, draft retained and sending blocked; matching receipt resolves it with exactly one outbound submission | `ConversationRegressionTests.identicalTextWithWrongReceiptCannotResolveAnUncertainSend`, existing lost-acknowledgement test |
| Approval and state transitions | No action before an explicit allowed decision; foreign/stale events cannot become replies/actions; unsupported approval fails closed | Existing `CompanionTests` |
| Resource cancellation | Closing the fixture process resolves a pending request and finishes its stream; late recognition after cancellation/restart is ignored | Existing `ProcessConnectionTests`, `VoiceTests` |

New asynchronous regressions use explicit continuation latches to create the
ordering, not sleeps or retries, with a one-minute suite limit. All accounts,
messages, databases and processes are synthetic. Ordinary CI uses no real chat,
microphone, account, paid turn or external message/network side effect.

## Check that assertions detect defects

```sh
swift run quality-gate mutations
```

This explicit diagnostic copies Sources, Tests, Tools and Package.swift to a temporary
directory. For each of three faults it requires green → assertion failure →
restored green: accepting non-object JSON, accepting stale refresh revisions,
and expiring a start marker at the wrong boundary. A compiler failure, skipped
test or zero matching tests is not a successful mutation detection. It writes
`test-results/fault-probes.json`. The diagnostic does not modify the working
tree or launch Jarvis. It is not repeated on every PR: the extra builds cost
more than the incremental detection benefit after these assertions are proven.

## Diagnostics and quarantine

CI uploads only `summary.json` and bounded diagnostic tails (128 KiB per command)
from the gate, retained for seven days. Home/temp paths and credential-shaped
fields are redacted. Raw XML and complete logs remain disposable. Redaction is
defence in depth, not permission to run private records in CI. Mutations use
synthetic assertion output too. Inspect failure output before sharing it.

There are **no quarantined tests or skip exceptions**. CI has no
`continue-on-error`. If a test becomes flaky, first preserve the failure and
reproduce the condition; correct the product, fixture or wait at its cause.
Any proposed quarantine needs a reviewed issue naming the repository maintainer
as owner, a dated expiry (at most seven days), review/removal criteria, the exact
lost behaviour and an independently running replacement signal. Expiry must
trigger review, not automatic renewal. This gate continues to reject skips:
an exception would require an explicit reviewed policy/code change. A critical
release assertion cannot be hidden by quarantine; a weaker replacement is a
release-risk decision, not a passing test result. Do not weaken expectations
merely to make a build green.

## Actual GitHub enforcement

The stable job context is `macOS build and tests` from the GitHub Actions app.
The workflow verifies pull requests and merge groups before integration. A manual
run can check an existing revision. Merging a green PR does not start the suite again.
The Swift matrix runs static checks, the full unit suite, the hover regression
probes and release packaging concurrently. Every selected job must pass.
Workflow YAML alone cannot enforce required checks. Repository branch rules and
a disposable failed-PR probe must be inspected separately; see the dated
[verification record](verification-44.md) for the actual result and any
platform/permission limits.

References: [required checks and branch protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches),
[merge queue checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue).
