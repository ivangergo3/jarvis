# Swift quality gates

Ticket #43 enables Swift 6 language mode for the package and release bundle, and
one pinned formatter for owned Swift sources. The minimum deployment target
remains macOS 14. The semantic changes address timestamp-parser state and
notification observer ownership; mechanical formatting is reviewed separately.

## Local and CI commands

```sh
./scripts/format.sh bootstrap  # explicit first-time download/build of the pinned tool
./scripts/format.sh check      # non-mutating; findings fail
./scripts/format.sh fix        # explicitly rewrite owned Swift files
./scripts/check.sh             # same gate invoked by CI
```

The complete check runs formatting, negative/positive gate probes, fixture-based
Swift tests through the native `quality-gate` with compiler warnings as errors,
and the release build. The test gate preserves discovery, required-test inventory,
skip/failure rejection and bounded diagnostics from #44. Existing CI
bundle/resource/signature checks still run afterwards. These commands do not
read live Codex records, send messages, start dictation, or run `--diagnose`.

Formatting covers `Package.swift` and every `.swift` file under `Sources/`,
`Tests/`, `Tools/QualityGate/` and `Tools/QualitySupport/`, including new local files.
Build products, downloaded formatter sources, personal demo folders and
historical Python evaluation fixtures are outside these owned-source roots.
No owned Swift file is excluded. Style is four spaces and a 100-column preferred
width; literals may exceed that width when splitting would change their content.

## Pinned tools

| Component | Selection |
| --- | --- |
| CI | Existing `macos-15-intel`, Xcode 16.4 (16F6), Swift 6.1.2 via `DEVELOPER_DIR` |
| Language | Swift 6 for SwiftPM and release build; includes full concurrency checking |
| Formatter | Official swiftlang/swift-format 601.0.0 at ffbb3225ffda37b62c7283c70e87e8bc7e8e202a |
| Formatter dependencies | Exact versions/revisions in `Tools/SwiftFormat/Package.resolved` |
| Local validation | Apple Swift 6.4.2 command-line tools; full Xcode 16.4 is unavailable locally |
| Deployment | macOS 14; a newer SDK does not establish minimum-OS runtime coverage |

For the exact CI compiler locally, select Xcode 16.4 with `DEVELOPER_DIR` before
running these commands. Bundled formatters vary between toolchains, so checks use
the separately pinned tool, never an arbitrary formatter found on PATH.

Bootstrap checks the source revision and rejects tracked source modifications.
It builds only the formatter executable with automatic dependency resolution
disabled, checks the unchanged lockfile and verifies the binary's version. Sources
and products stay in ignored `.build/tools`, outside app dependencies and global
installations. CI caches the build by OS, architecture, Xcode and checked-in pins.
Ordinary checks do not download or update anything.

Inspected dependency manifests: ArgumentParser 1.5.0, Markdown 0.6.0, CMark 0.6.0
and SwiftSyntax 601.0.1. Their tools versions support the existing CI compiler.
Upstream command plugins are not invoked. No remote installer or skill helper is
executed. Tool upgrades require reviewing the lockfile and formatting changes.

## Baseline and migration

On merged main `5261063`, Swift 5 mode plus `-strict-concurrency=complete` passed
85 tests but reported the following on local Swift 6.4.2:

| Diagnostic | Bounded fix |
| --- | --- |
| Two shared non-Sendable ISO8601DateFormatter instances | Immutable ISO8601FormatStyle values; retain whole/fractional parsing and test offsets, precision and concurrent callers. |
| Non-Sendable observer token read from LocalVoice.deinit | Selector registration and direct receiver removal; handling still hops to MainActor with a weak capture. |
| Non-Sendable Foundation link-attribute key path in a test | Typed attribute access, preserving the assertion that the URL survives rendering. |

This migration slice covers these diagnostics and the compiler settings. It was
small enough to enable Swift 6 for the owned targets. No unsafe Sendable
conformance, blanket preconcurrency import, isolation bypass, removed assertion
or suppressed compiler warning was added. Keep semantic migration and mechanical
formatting in separate commits.

No temporary concurrency exception is introduced. Any future exception must name
the exact declaration/diagnostic, reason, responsible owner, compensating check
and review/removal condition here. Do not globally weaken the language mode.
Formatting is style enforcement; compiler type/isolation checks cover correctness.
No second formatter or Swift linter is added without a demonstrated gap.

## Verification contract

| Risk | Required evidence |
| --- | --- |
| Formatting gate accepts malformed code | Bad disposable fixture exits nonzero with spacing findings; formatted counterpart passes. |
| Concurrency gate is ineffective | Shared non-Sendable mutable class fails with the expected concurrency diagnostic; actor counterpart passes. |
| Parser semantics change | Existing observation tests plus offset, precision and concurrent-caller checks. |
| Existing app regresses | Fixture suite, optimized release bundle, plist/signature/resources checks; macOS 14 target unchanged. |

Probe fixtures live in a temporary `.build` directory and are removed on exit.
An arbitrary compiler error does not count: the expected diagnostic is checked,
and a positive control must compile.

Local verification on 16 November 2026 passed the complete check: formatting,
both gate probes, 87 tests across 17 suites, and the optimized release build.
Separate bundle checks passed plist validation, signature verification and all
required resource checks; the executable records a macOS 14.0 minimum target.
Four animation `forEach` calls were converted to equivalent `for` loops and one
comment was moved to satisfy formatter findings that are not automatically fixed.

After rebasing onto #58 (`8f1ce53`), the combined local check passed 101 tests
through the native test gate, formatting of app/tests/quality tools, both
concurrency/format probes and the release build. Bundle validation also passed.
The injected clock, critical-test inventory, diagnostic upload and required CI
check from #44 are retained. This supersedes the earlier 87-test count.

Local CLT emits linker search-path warnings about absent full-Xcode directories.
Those are environment diagnostics, not compiler concurrency warnings; they are
not suppressed or presented as a clean full-Xcode build. The pinned-Xcode CI run
and minimum-OS runtime validation remain distinct from local checks. The fixture
suite does not exercise actual sleep/wake, microphone hardware or native UI.

References: [official formatter](https://github.com/swiftlang/swift-format),
[pinned manifest](https://github.com/swiftlang/swift-format/blob/601.0.0/Package.swift),
[Swift migration guide](https://www.swift.org/migration/documentation/migrationguide/),
[GitHub runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md).
