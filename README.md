# Jarvis — Mission Control

A personal native SwiftUI macOS dashboard for Greg. Designed for full screen, with a cyan and gold reactor interface inspired by the Jarvis companion.

## Engineering requirements

[REQUIREMENTS.md](REQUIREMENTS.md) records the macOS and Swift guardrails, future Codex/voice boundaries, acceptance criteria and hardening order. These are target requirements, not a claim of current compliance. [AGENTS.md](AGENTS.md) points coding work to that baseline; linked engineering records describe implemented checks and remaining gaps.

## Capability and skill planning

The [capability map](docs/planning/CAPABILITY_MAP.md) and [68-skill catalogue](docs/planning/SKILL_CATALOG.md) cover foundations, engineering, testing, marketing, sales, customer work and operations. The [dashboard](https://github.com/users/ivangergo3/projects/3/views/1) tracks current work; historical backlog documents are not another live status source. One agent can combine several focused skills; the [boundaries](docs/planning/SKILL_BOUNDARIES.md) prescribe no team or provider.

The skill definitions have merged. Use the [review guide](docs/planning/SKILL_REVIEW_GUIDE.md), [local-use safety](docs/planning/SKILL_SAFETY.md), [research notes](docs/planning/SKILL_RESEARCH.md) and [evaluation index](docs/planning/SKILL_EVALUATION.md) to inspect their evidence and limitations. Historical results apply only to their tested versions.

The [project discovery manifest](Tools/project-skills.json) exposes 14 existing engineering/workflow skills to Codex and Claude Code through relative links to `skills/`; the other library skills remain available for explicit task-relevant use. Nothing is installed globally. See [skill discovery and operating workflow](docs/engineering/agent-workflow-51.md) for the observed Codex result, deferred Claude runtime check, focused task handoffs and completed fresh-review pilot. Skill availability is not proof of model compliance or permission to perform live actions.

## Open

Open `build/Jarvis.app`. Use **Control–Command–F** or the top-right expand button for full screen. **Command–R** refreshes. Choose a chat to read its latest request; switch between team map and card view in the main pane.

## Build and verify

```sh
./build.sh
swift test
./build/Jarvis.app/Contents/MacOS/Jarvis --diagnose
```

Building requires the installed Apple command-line tools; there are no third-party Swift packages. The chat feature requires an installed, signed-in Codex CLI/App Server. Jarvis itself has no API-key entry or credential store.

## TypeScript workspace fixture

From a fresh checkout, use Node 24.19.0 (run `nvm use` if you manage Node with
nvm) and pnpm 10.7.1 on your PATH. Run these commands at the repository root:

```sh
pnpm install --frozen-lockfile
pnpm build
pnpm typecheck
pnpm fixture
```

The first install downloads the pinned dependencies into a repository-local store.
The build compiles the private fixture library with TypeScript 6.0.3. Turborepo
2.11.13 caches its `dist/` output locally. Each build clears the fixture output
before compilation or cache restoration so removed modules cannot survive a
source change. The fixture imports its compiled
ES module by package name, checks the greeting and prints
`Hello from the Jarvis workspace.` on success. The Swift app uses the build
and verification commands above.

## Automated quality checks

GitHub Actions runs **macOS build and tests** on every pull request, push/merge to `main`, merge-queue group and manual dispatch. It uses the standard `macos-15-intel` runner with Xcode 16.4 selected explicitly and builds with a macOS 14 deployment target.

Run `./scripts/format.sh bootstrap` once to build the pinned official formatter, then `./scripts/check.sh` for the same formatting, Swift 6 concurrency probes, fixture tests and release build used in CI. `./scripts/format.sh check` checks without edits; `./scripts/format.sh fix` applies formatting explicitly. See [Swift quality gates](docs/engineering/SWIFT_QUALITY.md) for exact tool pins, the diagnostic baseline and validation limits. App targets and the release script use Swift 6; compiler warnings fail the check command. No additional correctness linter is installed.

`swift test` runs a separate Swift Testing target. It checks lifecycle/task parsing, project assignments, graph routes and pulse movement, plus the read-only adapter against temporary SQLite databases and JSONL files. Fixtures cover incremental and partial writes, truncation, missing logs/history fallback, stale activity, invalid schemas, and rejected paths. Tests never need your Codex account, live chats, network or credentials. The old `--self-test` option now prints the replacement command and exits; `--diagnose` remains an explicit, local-only diagnostic that reads real records and is not run in CI.

CI also builds the release bundle, validates its plist and ad-hoc signature, and checks required bundled artwork. The shared `NativeUI` Xcode scheme adds six synthetic native UI journeys. Run `swift run native-ui-check` with full Xcode 16.4 to build the Release verification app, discover/drive the tests and retain the app, hash, screenshots and result bundle. See [native UI verification](docs/engineering/native-ui.md) for isolation, commands and the feature-to-check map. VoiceOver, macOS 14 runtime, hardware and live Codex acceptance remain manual gaps.

**Merge enforcement:** `main` requires the GitHub Actions **macOS build and tests** check and an up-to-date PR branch, including for administrators. The native test gate rejects failed processes, skipped or missing tests, and missing critical tests; CI retains bounded diagnostics. See [test quality](docs/engineering/test-quality.md) and its [verification record](docs/engineering/verification-44.md) for the policy and failed-merge probe. Repository settings are external to this workflow and must remain enabled.

## Data and meaning

The project selector discovers local Codex projects and remembers your selection. **All projects** shows Jarvis above project cards; selecting a project shows every non-archived user or voice chat in it, including newly created chats. The team graph supports more than four chats: cards extend in two columns around a central reactor lane, with vertical scrolling for larger teams and horizontal panning in narrow windows. Each card has a separate elbow-routed connector that stays in the central gutter and ends at a port on its inner edge. Active destinations glow as their travelling pulse arrives. Hovering or selecting a box highlights the matching route, including idle boxes. Card-grid view remains an optional alternative. **Unassigned chats** is available separately. Project grouping uses native project IDs, migrated desktop assignments, and a folder-root fallback (the most specific path wins). Explicitly projectless chats stay unassigned.

Jarvis reads `~/.codex/state_5.sqlite` with SQLite read-only flags, selected project metadata from `~/.codex/.codex-global-state.json`, and local JSONL session records. The first read searches backward for lifecycle markers and the latest meaningful user request; subsequent refreshes read only appended bytes. Delegated agents come from recorded parent-child relationships, excluding approval reviewers. Polling uses the configured foreground interval on an actor away from the UI, with slower background observation.

- **In progress:** the latest observed lifecycle marker is `task_started`.
- **Standby:** the latest marker is `task_complete`; the chat may have unfinished broader goals, but its current turn finished.
- **Interrupted:** the latest marker records an aborted turn.
- **Unknown:** no usable marker exists, the record is unavailable, or an open turn has had no file activity for 30 minutes. When a session file is missing, saved user requests can be recovered from the local history database and are explicitly labelled saved history; their activity remains unknown. Long quiet tools can also become unknown; this is deliberately cautious.
- **Latest request:** the actual latest user message, not an AI-generated task summary. Approval replies, heartbeat messages, and injected environment context are filtered out. A short follow-up can therefore appear as the latest request.

The root Jarvis view is an organisational workspace view. It shows the intended hierarchy of you → Jarvis → projects → chats, while clearly marking the coordinator as observation-only. It does not create a boss agent, send instructions, or imply delegation between peer chats. Actual subagents appear under their recorded parent. Historical subagents can remain listed after finishing; the top counter counts only active ones.

The team-observation adapter stays local and read-only. It never edits Codex databases. The conversation panel links to the selected existing chat through Codex's App Server queue APIs and reads recent saved history through the protocol. Sending is an explicit user action; it does not start a second agent runtime or create a new chat. Monitoring still depends on Codex's internal local record format, so updates may require an adapter update.

## Linked Jarvis conversations (v0.4)

The pet lives inside this window. Choose an existing chat in the sidebar or graph: **Send to: [chat name]** identifies the actual destination. The app remembers the selected chat by its unique ID, not by its title. Renames preserve that link and duplicate titles remain separate destinations.

- The panel shows recent saved conversation summaries (12 turns) plus up to 100 queued messages. It refreshes at the configured interval, with background backoff. History may lag while Codex is writing a turn; this is not a full transcript export or a second live owner.
- **Send** / **Command–Return** submits to that existing chat's shared Codex queue. A **YOU · QUEUED** bubble means Codex has queued the message, not that a reply is complete. Busy chats process their queue as work permits. If the chat is not loaded, use **Open in Codex** to continue it. Approvals and work controls stay in the owning Codex app.
- Selecting another card retains each unsent draft under its original chat ID and restores it when you return (in memory, up to 100 chats). Drafts never move between destinations. Dictation, in-flight sends and uncertain acknowledgements still prevent an unsafe switch. The reconnect button asks before discarding a draft.
- The queue uses a distinct client message ID. After a lost acknowledgement, sending is disabled until a read-only queue/history lookup confirms that same submission or you explicitly leave the conversation. Requests are never automatically replayed. A known rejection retains the draft. Delivered messages and queued entries deduplicate by client ID, not matching text.
- The installed Codex App Server supplies `thread/queue/add`, `thread/queue/list`, and `thread/turns/list`. Queue methods currently require the per-connection `experimentalApi` capability. This opts in to protocol fields only; no sandbox or permission settings are changed. Unsupported versions show an error and disable sending; they never fall back to a newly created chat. The equivalent CLI operation is `codex queue --thread <ID> --message <TEXT>`; see [official developer commands](https://learn.chatgpt.com/docs/developer-commands) and [App Server documentation](https://learn.chatgpt.com/docs/app-server).
- Jarvis launches the installed Codex executable with fixed arguments over private stdio. Codex manages its own sign-in/provider configuration. Jarvis copies no credentials and opens no network listener. Background refreshes are read-only; they do not send model prompts.
- Dictation remains on-device, with no cloud audio fallback. Microphone and speech permission prompts occur at first use. Stop to review the transcript, then choose Send yourself. Cancelled callbacks cannot fill a later draft. Capture ends on cancel, hiding the panel, sleep or quit, with a 45-second limit. Raw audio is not saved.
- **Completion chime** plays the bundled two-note sound for new completed replies, including while the conversation panel is hidden. **Read reply** separately enables optional macOS read-aloud. With both enabled, speech follows the chime. Both preferences are remembered; connecting to saved history does not replay either notification. Dictation remains separate.
- The top-right **Global settings** cog's **Update every** setting controls activity/history refresh (1, 3, 5, 10 or 30 seconds); the clock remains independent. Working chat headers have one glowing segment travelling around the complete rounded border, with a static alternative for Reduce Motion.

The original floating Codex pet and the earlier v0.3 standalone Jarvis conversation are untouched. Old messages are not migrated, copied into another chat or deleted. Closing this window cleans up Jarvis's read/queue child connection and audio; it does not stop the linked desktop agent. No private chat IDs, prompts, real history fixtures or screenshots are committed to this public repository.

## Source

Authority verification for future coordinator actions is available through `swift run quality-gate authority`. It uses scoped grants, no-op tools and OS isolation probes; see [authority boundaries and remaining production gates](docs/engineering/authority-boundaries-49.md). It does not enable autonomous actions in the app.

- `Sources/JarvisDomain/`: workspace contracts and lifecycle rules (independent Swift module).
- `Sources/JarvisAuthority/`: scoped action grants and outcome tracking, currently used only by verification tooling.
- `Sources/JarvisWorkspace/`: read-only local adapter and incremental polling (independent Swift module).
- `Sources/Jarvis/Presentation/`: screens, reusable visual components and native UI bridges.
- `Sources/Jarvis/Application/`: observable state, refresh ownership and conversation workflows.
- `Sources/Jarvis/Integrations/`: process transport, image storage/preview loading, speech and desktop actions.
- `Sources/Jarvis/Shared/`: pure app contracts, parsing and geometry used across these layers.
- `Sources/Jarvis/Main.swift` and `Composition/`: lifecycle, capability wiring and synthetic UI fixtures.

The app folders share one executable module; [native boundary checks](docs/engineering/native-boundaries-48.md) enforce source policy alongside the existing compiler-separated workspace modules.

No login item, background service or external infrastructure is installed. Quitting the app stops polling, audio and its owned App Server connection.

## License

Open source under the [MIT License](LICENSE).

Chat messages render Markdown tables with inline formatting, wrapped cells and horizontal scrolling for wide tables. The dashboard footer is removed; the bottom-left local connection details remain. Duplicate Overview/Activity sidebar navigation is removed; graph/card controls remain in the main pane.

The bordered composer accepts ⌘V images (PNG/TIFF clipboard or a copied image file), previews them before sending, and supports removing an attachment. Up to six images per draft; 20 MB/40 megapixel input cap, downsampled to 4096 pixels. Images are copied into the app-owned `~/Library/Application Support/Jarvis/Attachments` directory and retained for queued delivery and history previews. Image drafts stay with their original chat ID; uncertain sends retain attachments and never replay automatically.

The sidebar project switcher opens a Jarvis-styled chooser with the current project marked. The global settings cog beside Refresh opens a full preferences dialog matching the chat settings, with the persisted update interval.

Continuous rings, border sweeps and route dots use compositor-owned Core Animation layers rather than per-frame SwiftUI timers. The reactor stays fixed; cursor tracking and tilt have been removed entirely. Decorative motion pauses when inactive, hidden, in Low Power Mode, or under Reduce Motion. Foreground polling keeps the chosen interval; inactive/Low Power Mode uses at least 15 seconds, hidden uses at least 30. Unchanged snapshots and chat histories do not republish. See `PERFORMANCE.md` for local measurements and their limits.

Project-team navigation follows Codex's saved manual sidebar order, including migrated project IDs. Chats without a saved position use a deterministic alphabetical order; activity updates do not move them. Project names have dedicated space in the selector and a clearer header label.
