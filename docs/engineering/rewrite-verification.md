# Rewrite verification and local lifecycle acceptance

Date: 2026-11-17. Links: [master plan](cloud-harness-rewrite-plan.md), [Swift inventory](swift-feature-visual-inventory.md). No issues are created by this work.

## Agreed lifecycle contract

Local phase only: start NestJS on opening Jarvis; no automatic login start. Window close and Command-Q both confirm before stopping the service and its active tasks. Cancel leaves the interface/work unchanged. This supersedes the earlier background-on-close proposal. The current Swift app has not been changed to implement the new confirmation.

Proposed shutdown sequence: gate new dispatch -> request cancellation -> verify owned process-tree cleanup -> persist resolved/interrupted/uncertain state -> close. Confirmation does not prove a command stopped. A timeout or lost acknowledgement cannot become success, rollback or permission to resend. Stop only Jarvis-owned processes; local Supabase data must survive. Closing Jarvis does not authorize removing volumes or stopping unrelated containers/apps.

After crash/reboot, restore durable records, reconcile owned processes/provider receipts, then show actual state. Never automatically replay a command with an uncertain effect. Qualify the 60-awake-second cancellation interval, the five awake seconds after each observed TERM and actual packaged cleanup against the [local service contract](local-service-contract.md). Browser/mobile disconnect must not inherit local-machine shutdown semantics without an explicit later decision.

## Checks implemented against the current Swift baseline

| Check | Contract / defect detected | Evidence |
| --- | --- | --- |
| Mixed rich message | Heading/quote/list/table/code/image/final paragraph retain independent content; code cannot become an attachment/table. | `RewriteBaselineTests.richMessageKeepsTableCodeImageAndFollowingTextDistinct` |
| Graph edge geometry | 1/4/20/100 routes at narrow/wide viewports reach their own card edge, remain finite and orthogonal. | `RewriteBaselineTests.routesReachTheirOwnCardEdgesAtNarrowAndWideSizes` |
| Combined refresh/hover load | 20/100 chats, 251 reads and 10,000 pointer-state transitions: timestamps alone publish nothing, one actual task change arrives, hover does not publish dashboard state, final highlights clear. | `RewriteBaselineTests.refreshAndHoverLoadPreserveLocalUpdatesAndDeliverChangedTask` |
| Native control parity | Mode switches, global refresh setting and hide/reopen panel preserve an unsent draft/destination and submit nothing. | `JarvisUITests.testViewModesSettingsAndPanelVisibilityPreserveDraft` |

The Swift tests are in `Tests/JarvisTests/RewriteBaselineTests.swift`; their identities are required by `Tools/critical-tests.json`. The native journey is required by `UITests/required-tests.json`, so missing/skipped tests cannot silently count as full UI acceptance. The existing hover-fault probe, 100-card native load and physical-pointer journeys remain intact.

These checks exercise production Swift logic/UI through synthetic fixtures. The hover workload is a deterministic invalidation/load check, not an OS mouse simulation, CPU benchmark or proof of Electron performance. The native suite supplies the separate real-pointer path.

## Historical verification on November 17, 2026

These results cover the uncommitted November 17 baseline. It has no recorded commit ID. Subsequent changes strengthened the hover assertions and the native journey. See the reviewed PR checks for results against the published revision.

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

### Packaged Electron recording on the owner's Mac

Use the production bundle, an isolated profile and a fixed synthetic workspace. Record the revision, bundle SHA-256, architecture, OS build, device model, Electron/Chromium versions, screen resolution and scale, power source, thermal state, refresh interval, motion settings and fixture revision. Record whether the window has focus, is visible, and the session is unlocked over each interval. A local developer build or a locked-screen run can diagnose setup but cannot establish the foreground baseline.

Use the same 1440 × 900 logical viewport and default motion for each paired run when the display supports it. Record the actual viewport and declared input schedule. Warm up for 15 seconds after the project is populated. Run three measured repetitions per workload, alternating 20 then 100 chats and 100 then 20 between repetitions. Restore the same fixture state each time. Keep normal refresh enabled at three seconds. A separate reduced-motion run tests accessibility and is reported separately.

| Workload | Inputs and boundary | Observable outcome |
| --- | --- | --- |
| Idle | Select the graph, put the pointer outside the cards and make no input for 60 seconds. | Same selected project and chat, unchanged content between refreshes. |
| Card hover | Move the real rendered pointer between two visible cards at four transitions per second for 60 seconds. Record dispatched and observed transitions. | Only the entered/exited cards and their connectors change. Preserve the independent negative probe that dirties unrelated cards. |
| Refresh and task events | Across 60 seconds, deliver one fixture event per second to the same run, interleaving duplicates and unchanged snapshots; record the scheduled sequence. | Every distinct event appears once, in order, in its original conversation; unchanged snapshots preserve selection. |
| Long conversation | Seed 1,000 text, table and code messages in the selected chat. Alternate 20 wheel inputs of 240 logical pixels up and down while content is available. Repeat three cycles. | Measure actual scrolling and response to direction changes. The final visible message is reachable and the draft survives. |
| Project and panel switching | Alternate the 20- and 100-chat projects 30 times, opening a chat, hiding the panel and reopening it each time. Record click to target heading and latest message rendered. | Count all completed transitions, correct destinations, preserved drafts and stale headings. |
| Retention | Repeat the switching/scrolling sequence for five minutes. Return to the starting project and let it settle for 60 seconds. | Compare the same idle state before and after the soak. Count live windows, renderers and retained histories or subscriptions where measurable. |

Sample the app's owned main, renderer and helper processes once per second. Capture per-process identity, cumulative CPU and resident memory with a monotonic clock. Calculate CPU as the change in CPU seconds divided by elapsed seconds × 100 (one fully used core is 100%). Keep the record for a process that exits or starts during measurement. If the interval cannot be accounted for, mark it incomplete. Report per-process and aggregate memory with units and source; shared pages can be counted more than once. Keep backend/database costs separate. Record renderer event-to-next-frame time and event-loop delay as proxies with their actual start and end points. Neither measures presentation to the display.

Save individual samples, observed input counts, median/p95/max delays, incomplete repetitions and reasons for exclusion alongside the candidate. A lost focus interval, session lock, changed power mode or incomplete input sequence requires a separately recorded repeat. Keep outliers. Use the results and the existing Swift evidence to propose Electron investigation budgets to Greg. Continue to require the deterministic hover checks, rendered-pointer checks and negative probes. A missing or weaker required gate pauses qualification and cutover for Greg's explicit decision. [Open release measurement gaps](https://github.com/ivangergo3/jarvis/issues/72)
