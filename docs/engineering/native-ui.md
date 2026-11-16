# Native UI verification

Ticket #45 adds the shared `NativeUI` Xcode scheme and six XCTest UI journeys.
The scheme builds a Release macOS application from the same owned Swift sources
and bundled artwork as `build.sh`, plus a native UI-test target. The verification
build preserves the `JarvisDomain` and `JarvisWorkspace` modules as separate
static library targets, with the same dependency direction as SwiftPM. The fake
workspace implements `WorkspaceSource`; it uses the production refresh store,
including cancellation and unchanged-snapshot suppression from #46. The verification
artifact has its own bundle identifier (`dev.jarvis.verification`) and refuses
to start without an explicit synthetic scenario and run UUID. The existing
shell-built `Jarvis.app` remains unchanged as a packaging route; this suite
does not establish byte-for-byte equivalence of the two bundles.

## Run and inspect

Use full Xcode 16.4 (Swift 6.1.2), a logged-in macOS GUI session, and the pinned
formatter setup described in [Swift quality](SWIFT_QUALITY.md). Command Line
Tools alone cannot run XCTest UI automation. macOS may request permission for
Xcode's UI testing helper on first use; permission must be granted by the user,
not bypassed by a script.

```sh
export DEVELOPER_DIR=/Applications/Xcode_16.4.app/Contents/Developer
./scripts/check.sh
swift run native-ui-check
```

The native Swift runner checks Xcode source membership, records OS/toolchain/git
identity, runs `xcodebuild build-for-testing`, enumerates tests, then executes
`test-without-building`. It fails on a nonzero command, absent/incomplete test
inventory, removed required tests, any failed/skipped test or inconsistent result
counts. Builds/tests have ten-minute command bounds; each UI test has a ninety-
second limit. Test retries and parallel app instances are disabled.

Each run preserves evidence under `test-results/native-ui/<run UUID>/`:

- The tested Release app and executable SHA-256 (`artifact.json`).
- Xcode/Swift/OS/commit records, build/drive logs and discovery JSON.
- `NativeUI.xcresult`, containing assertions, native accessibility hierarchy
  attachments and app screenshots; screenshots alone cannot pass a test.
- On failure, exported attachments and diagnostics where Xcode can extract them;
  the original result bundle is retained even if export fails.
- Parsed result trees/summary and `gate.json` only after all checks pass.

Open a retained result with `open <run-directory>/NativeUI.xcresult`. CI retains
the synthetic evidence for seven days. Paths in raw Xcode logs are runner/local
paths; review local evidence before sharing it. Never substitute a live app or
private account for these fixtures.

For focused investigation, the equivalent commands are:

```sh
xcodebuild build-for-testing -project Jarvis.xcodeproj -scheme NativeUI \
  -configuration Release -destination 'platform=macOS' -derivedDataPath .build/ui-manual
xcodebuild test-without-building -project Jarvis.xcodeproj -scheme NativeUI \
  -configuration Release -destination 'platform=macOS' -derivedDataPath .build/ui-manual \
  -parallel-testing-enabled NO -only-testing:JarvisUITests/JarvisUITests/testProjectsAndChatSelection
```

Focused execution does not satisfy the full inventory gate. To manually launch
the built synthetic artifact, pass `--ui-fixture workspace --ui-run-id <UUID>` to
`.build/ui-manual/Build/Products/Release/JarvisVerification.app/Contents/MacOS/JarvisVerification`.
The visible run UUID and submission receipt distinguish this app from any other
instance. Scenarios are `workspace`, `empty`, `unavailable` and `stale`.

## Feature-to-check map

| Journey | Observable contract |
| --- | --- |
| Projects and chats | Scope label and available chat buttons change; selected conversation title follows the chosen ID. |
| Empty project | Explicit no-chats state; Send stays disabled. |
| Empty workspace | Explicit no-projects state; no fixture project button or enabled Send. |
| Unavailable source | Error plus unavailable state, no false loading/success and no outbound submission. |
| Stale source | A successful snapshot survives a later failed refresh; navigation remains usable and activity becomes unknown. |
| Keyboard and drafts | Command-Shift-P opens the project chooser, Escape closes it; switching between identically named chats preserves each draft; Command-Return submits once to the original ID through the fake transport. |

Every journey starts a fresh app with a unique run UUID and waits for bounded,
observable conditions. Stable identifiers are attached to existing native
controls. The recorded fake transport receipt is independent of the displayed
chat name, so duplicate names cannot conceal a wrong destination.

## Isolation and cleanup

Fixtures are in-memory constants; no user home, database, transcript or arbitrary
fixture file is loaded. The injected transport accepts only the listed synthetic
chat IDs and supported read/queue operations. It has no process/network fallback.
Audio, external links, connection settings, image import and persisted app
preferences are disabled. Draft sends remain explicit UI actions and produce
only an in-memory receipt. The separate bundle avoids the real app's preferences
and window restoration.

Tests refuse to start while another verification app is running. Teardown keeps
evidence and terminates the launched verification app; each fixture app also
self-terminates after two minutes if a runner crashes. The command runner bounds
and cleans up its own process groups and deletes only its UUID-named derived-data
directory. Result artifacts are retained; no `killall`, global preference reset,
private data deletion or cleanup of another application is performed.

## Manual acceptance still required

This suite does not establish VoiceOver usability, complete keyboard/focus
coverage, macOS 14 or Apple Silicon runtime compatibility from an Intel CI run,
real microphone/speech behaviour, real Codex integration, display/Spaces changes,
sleep/wake, full-screen layouts or performance. These remain separate native
acceptance checks. Synthetic test success is not whole-app production readiness.

References: [Apple UI testing](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/09-ui_testing.html),
[XCUIApplication](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication),
[Xcode result commands](https://developer.apple.com/documentation/xcode-release-notes/xcode-16_3-release-notes).
