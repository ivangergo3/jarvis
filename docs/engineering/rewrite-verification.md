# Rewrite verification and local lifecycle acceptance

Date: 2026-11-17. Links: [master plan](cloud-harness-rewrite-plan.md), [Swift inventory](swift-feature-visual-inventory.md). No issues are created by this work.

## Agreed lifecycle contract

Local phase only: start NestJS on opening Jarvis; no automatic login start. Window close and Command-Q both confirm before stopping the service and its active tasks. Cancel leaves the interface/work unchanged. This supersedes the earlier background-on-close proposal. The current Swift app has not been changed to implement the new confirmation.

Proposed shutdown sequence: gate new dispatch -> request cancellation -> verify owned process-tree cleanup -> persist resolved/interrupted/uncertain state -> close. Confirmation does not prove a command stopped. A timeout or lost acknowledgement cannot become success, rollback or permission to resend. Stop only Jarvis-owned processes; local Supabase data must survive. Closing Jarvis does not authorize removing volumes or stopping unrelated containers/apps.

After crash/reboot, restore durable records, reconcile owned processes/provider receipts, then show actual state. Never automatically replay a command with an uncertain effect. Define the exact supervision/cleanup timeout policy during lifecycle implementation; do not infer it from a mock test. Browser/mobile disconnect must not inherit local-machine shutdown semantics without an explicit later decision.

## Checks implemented against the current Swift baseline

| Check | Contract / defect detected | Evidence |
| --- | --- | --- |
| Mixed rich message | Heading/quote/list/table/code/image/final paragraph retain independent content; code cannot become an attachment/table. | `RewriteBaselineTests.richMessageKeepsTableCodeImageAndFollowingTextDistinct` |
| Graph edge geometry | 1/4/20/100 routes at narrow/wide viewports reach their own card edge, remain finite and orthogonal. | `RewriteBaselineTests.routesReachTheirOwnCardEdgesAtNarrowAndWideSizes` |
| Combined refresh/hover load | 20/100 chats, 251 reads and 10,000 pointer-state transitions: timestamps alone publish nothing, one actual task change arrives, hover does not publish dashboard state, final highlights clear. | `RewriteBaselineTests.refreshAndHoverLoadPreserveLocalUpdatesAndDeliverChangedTask` |
| Native control parity | Mode switches, global refresh setting and hide/reopen panel preserve an unsent draft/destination and submit nothing. | `JarvisUITests.testViewModesSettingsAndPanelVisibilityPreserveDraft` |

The Swift tests are in `Tests/JarvisTests/RewriteBaselineTests.swift`; their identities are required by `Tools/critical-tests.json`. The native journey is required by `UITests/required-tests.json`, so missing/skipped tests cannot silently count as full UI acceptance. The existing hover-fault probe, 100-card native load and physical-pointer journeys remain intact.

These checks exercise production Swift logic/UI through synthetic fixtures. The hover workload is a deterministic invalidation/load check, not an OS mouse simulation, CPU benchmark or proof of Electron performance. The native suite supplies the separate real-pointer path.

## Verification execution record

Focused command: `swift test --filter RewriteBaselineTests`. Result: three test definitions passed (seven parameter cases/scenarios), with both 20/100-chat combined workloads completing. The initial sandboxed attempt could not write compiler caches; the authorized cache-access rerun passed. This is not a hidden failing assertion or a paid integration exercise.

Full local gate passed: **190 test cases**, format/concurrency negative probes, workspace/app architecture checks, skill wiring, eight synthetic authority scenarios/five isolation checks, build/bundle verification and the three hover fault probes (good -> defective assertion failure -> restored good). No tests were skipped to obtain this result.

Toolchain: Command Line Tools Swift 6.4.2. Default gate compilation failed to locate `TestingMacros`; the alternate native engine also failed to locate `Testing`. Those failures were preserved. Explicitly loading the installed macro library resolved the default-engine compilation without disabling warnings-as-errors or changing repository settings. Passing invocation:

```sh
./scripts/check.sh --swift-arg=-Xswiftc --swift-arg=-load-plugin-library --swift-arg=-Xswiftc --swift-arg=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib
```

Native UI execution remains **pending**: `swift run native-ui-check` failed its Xcode preflight because only Command Line Tools are selected, before running any UI journey. The new journey passed Swift syntax parsing, which is not UI typechecking/runtime evidence. Full Xcode/required native CI must execute all nine journeys before UI acceptance. Local failed/preflight and passing logs are retained under `/private/tmp/jarvis-rewrite-*.log`; current structured results remain under ignored `test-results/`.

No fresh CPU/memory measurement or visual snapshot regeneration is claimed. Historical screenshots are references, not new test evidence. Replacement lifecycle acceptance remains pending implementation of the actual Electron/NestJS service.

## Replacement checks required when the runtime exists

These are explicit pending acceptance cases, not placeholder tests that pretend a nonexistent NestJS/Electron runtime works:

| Area | Required cases before replacement |
| --- | --- |
| Close/Quit | Idle and active confirmation; Cancel performs no shutdown; Confirm prevents dispatch, terminates only owned work and persists state; repeated close requests are idempotent; cleanup failure stays visible. |
| Recovery | Renderer/service crash, host restart, lost acknowledgement, stale PID/lease and partial external effect: reconcile without duplicate tasks or blind replay. |
| Local Supabase/Auth | Data persists across restart; failed migrations/login/service availability show failure; startup never resets data; unauthorized local API callers are rejected. |
| Codex CLI | Subscription mode verified, no API-key fallback, stable project/session routing, explicit correlated approvals, supported protocol errors, cancellation/descendant cleanup and no desktop-UI dependency. |
| Visual parity | UI-01–UI-34 with current synthetic same-build screenshots for graph/cards/settings/rich messages/images and minimum/full-screen layouts; approve explicit integration mappings. |
| Streaming/state | Ordered/deduped events, reconnect, failed sends, draft destinations, unchanged data and bounded history; no duplicate backend cache/context stores. |
| Audio/mobile/cloud | Phase-specific tests only when implemented; no implicit microphone/provider access or billing; Mobilewright qualification deferred with mobile. |

## Performance qualification

Retain deterministic hover publication/layer checks and negative probes as hard regressions. Before replacement, run packaged release builds with 20/100-chat fixtures and long histories under idle, continuous card hover, refresh/event bursts, scrolling and repeated project/panel switches. Collect CPU, memory, responsiveness and sustained retention with stable visibility/power/motion/input conditions; preserve exclusions and failures.

Use [the Swift protocol used for the baseline](https://github.com/ivangergo3/jarvis/blob/d61f5915a5bf85efe4272f1317c3c8f56ed49b9d/docs/engineering/performance-47.md) for Swift. Existing 5/12/20% scoped warnings are historical Mac baselines, not universal or new Electron gates. Establish paired Electron measurements and agree numeric budgets before enforcing them. Do not accept a faster sample that silently disables motion/accessibility or omits input work. Compare counters and real rendered/native interaction, not averages alone.

No full frontend rewrite, service implementation, new lifecycle UI, dependency installation, provider call, ticket creation or push is part of this verification addition.
