# Workspace architecture slice (#46)

The owner agreed the first slice on 16 November 2026: workspace loading and
refresh, including snapshot models, the read-only Codex adapter, UI state,
enforced dependency boundaries and a synthetic native journey. This note is
written before moving implementation files. #45's wider native UI baseline is
still open; this slice does not claim to complete it.

## Current path and bounded change

`Dashboard` currently creates `FleetStore`; `FleetStore` and `CodexReader` share
a file importing Combine and SQLite. The reader already owns blocking I/O in an
actor. `Models.swift` mixes snapshot values, membership rules and JSONL parsing.
Keep those useful behaviours, rather than replacing the adapter or its tests.

The selected path becomes:

```text
Main (composition) ──> CodexReader (JarvisWorkspace actor)
       │                         │
       v                         v
FleetStore ──> WorkspaceSource / FleetSnapshot (JarvisDomain)
       │
       v
Dashboard and project/chat views
```

- `JarvisDomain`: Sendable snapshot values, membership/navigation rules, task-text
  policy and the narrow async `WorkspaceSource` contract. Foundation value types
  are permitted; UI, storage, processes, networking and record decoding are not.
- `JarvisWorkspace`: read-only SQLite/session adapter and JSONL observation.
  Depends on domain; no UI/Combine import or UI state.
- `Jarvis`: Main constructs the adapter and owns the MainActor refresh store.
  Views observe that store; they cannot import/name the workspace adapter.
  Other integrations (conversation transport, voice, artwork, preferences) are
  outside this first slice and are not asserted to have been migrated.

Keep saved IDs, ordering, stale-state thresholds, partial/rotated log handling,
read-only access, errors and public visuals unchanged. Keep the last usable
snapshot on failure. Cancellation must not publish an obsolete response or
present an error; overlapping refreshes must not create competing readers.

## Enforcement and verification

Use SwiftPM targets for the owned dependency graph and a native Swift architecture
check for imports and direct adapter references. Check the actual package graph,
not folder names alone. Prove that a forbidden dependency in a disposable source
fixture fails the check and its corrected version passes. This is an explicit
source/graph policy, not a security sandbox or proof of arbitrary effect purity.

Retain and run existing membership, reader, parser, ordering and stale-state
regressions. Add controlled-source refresh tests for failure recovery,
cancellation, overlapping refreshes and unchanged-display suppression. Run the
configured formatter, Swift 6 checks, full gate and release bundle checks.

Provide an explicit synthetic workspace launch path with a disabled conversation
transport, separate app identity/preferences and disposable data. Check project
switching, chat selection and workspace refresh in the native app without live
Codex access. Record the exact observed journey and remaining QA-04 gaps.

The smaller alternative was to split files and retain one module. It would leave
the dependency direction implicit. A complete rewrite of conversation/voice and
all views would expand the regression surface unnecessarily. This slice adds no
network backend, framework dependency or global agent arrangement.

## Implemented checks and commands

`WorkspaceArchitecture` runs before tests in `quality-gate test`; its separate
`architecture` command supports the disposable probes. It checks the actual
`swift package dump-package` output for the protected targets' kinds, roots,
exclusions and dependency edges. Source checks reject UI imports and named
I/O/decoding APIs in domain, UI/Combine imports in the adapter, and adapter
imports/references outside app composition. Comments and string literals do
not count as dependencies. Canonical paths prevent temporary-directory symlinks
from misclassifying a source. This targeted check is not a Swift compiler,
interprocedural effect analysis or protection against an adversarial maintainer;
API aliases, new integrations and arbitrary Foundation effects still need review.

`scripts/verify-workspace-architecture.sh` invokes the executable against a
disposable package. It requires the expected forbidden-import diagnostic and a
nonzero exit, then a corrected pass. It repeats this for a reversed domain →
adapter edge. A generic compiler/launch failure cannot satisfy the probe.
`scripts/check.sh` includes these probes and preserves the existing formatter,
concurrency, complete-test-inventory and release gates.

The release launcher now builds the Jarvis product with SwiftPM so the module
boundaries apply to the shipping artifact too. It bundles the same artwork,
usage descriptions and ad-hoc signature. Quality tools are not dependencies of
the shipping executable; the adapter alone owns the SQLite linker dependency.

```sh
./scripts/check.sh
swift run quality-gate architecture
```

On the local Command Line Tools installation, Swift Testing requires its explicit
plugin location. `check.sh` forwards additional gate arguments for this documented
environment difference; the pinned-Xcode CI invocation stays unchanged:

```sh
./scripts/check.sh --swift-arg=-Xswiftc --swift-arg=-plugin-path \
  --swift-arg=-Xswiftc \
  --swift-arg=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

## Reproduce the focused native journey

After the release build, prepare an owned temporary workspace and separately
identified app. Preparation compiles a Swift fixture generator, creates two
synthetic projects/chats and copies the built app. It opens no UI itself.

```sh
run_dir=$(bash scripts/workspace-journey.sh prepare)
open "$run_dir/Jarvis Workspace Fixture.app"
```

Verify the `WORKSPACE FIXTURE` label and exactly `Fixture Alpha` and `Fixture
Beta`. Select Alpha and its `Plan a synthetic launch` chat; use the project
chooser to select Beta and `Review a synthetic report`. Expect Alpha working
and Beta standby. The conversation transport intentionally reports unavailable;
no actual Codex process, send, approval or microphone is needed for this journey.

Withhold only the owned fixture database and refresh:

```sh
mv "$run_dir/data/state_5.sqlite" "$run_dir/data/state_5.saved"
```

Expect the connection-unavailable banner, unknown status and unavailable counts,
while the last project's chat remains visible. Restore the file and refresh:

```sh
mv "$run_dir/data/state_5.saved" "$run_dir/data/state_5.sqlite"
```

Expect the banner to disappear and the Beta selection/standby status to remain.
Quit this fixture app, then remove only its temporary files and unique preference
domain. Cleanup refuses an app whose executable is still open:

```sh
bash scripts/workspace-journey.sh cleanup "$run_dir"
```

Fixture copies embed their data location in their own Info.plist and use a
unique `dev.jarvis.workspacefixture.*` bundle ID. Opening/reopening one without
arguments cannot fall back to live records: missing configuration exits 64.
The normal app cannot enter fixture UI mode with its normal preferences. Explicit
`--diagnose --workspace-fixture <directory>` remains a non-UI diagnostic option.

## Verification record — 16 November 2026

- Base `b6b2911`: #43 Swift 6/formatter and #44 native failure gates retained.
- Local complete check passed: **116 tests**, zero skips/failures; pinned format,
  concurrency positive/negative controls, both executable architecture rejection
  probes, and optimized modular release build. Initial ordinary CLT invocation
  correctly failed on missing TestingMacros; the explicit plugin invocation above
  passed without weakening warnings, assertions or discovery.
- Plist lint, strict ad-hoc signature verification and required bundle resources
  passed. The linked executable records macOS **14.0** as its minimum.
- Native journey on arm64 macOS 27.2, Apple Swift 6.4.2 CLT: an isolated copied
  release binary SHA-256
  `c10690dc4db4752e523f15291f36f8eecf710221e1b6514fce03cae3fc08d32d`
  was launched through native app control. Project/chat selection was observed
  through native accessibility controls; failure/unknown and restored/standby
  states were observed in the actual rendered app, not inferred from a unit test.
  The selected Beta chat survived failure/recovery. The app quit and its owned
  directory/preferences were removed.
- An initial argument-only fixture launch failed and was excluded from evidence.
  Reopening its copy could fall back to a normal workspace. That prompted the
  embedded, fail-closed launch policy and dedicated regressions above; no content
  from that failed run is included in public artifacts.

This is a focused, human-driven native journey, not an automated XCUI suite or
full accessibility certification. #45 still owns broader readiness/automation,
keyboard/VoiceOver, empty/stale UI matrices and diagnostics. Real microphone,
sleep/display behaviour and macOS 14 runtime remain unverified. Other integrations
remain in the app target; this ticket does not claim whole-app architectural
purity or production readiness. The PR's latest exact-head macOS CI result must
also pass before merge.
