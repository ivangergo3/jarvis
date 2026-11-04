# Jarvis — Mission Control

A personal native SwiftUI macOS dashboard for Greg. Designed for full screen, with a cyan and gold reactor interface inspired by the Jarvis companion.

## Engineering requirements

[REQUIREMENTS.md](REQUIREMENTS.md) records the researched macOS and Swift guardrails, future Codex/voice boundaries, acceptance criteria and proposed hardening order. These are target requirements, not a claim of current compliance. [AGENTS.md](AGENTS.md) points future coding work to that baseline. This documentation update does not implement the requirements or change the running app.

## Open

Open `build/Jarvis.app`. Use **Control–Command–F** or the top-right expand button for full screen. **Command–R** refreshes; the pause button stops ambient animation. Choose a chat to read its latest request. Team map, card view, and Activity are working views of the same local data.

## Build and verify

```sh
./build.sh
swift test
./build/Jarvis.app/Contents/MacOS/Jarvis --diagnose
```

Building requires the installed Apple command-line tools; there are no third-party Swift packages. The chat feature requires an installed, signed-in Codex CLI/App Server. Jarvis itself has no API-key entry or credential store.

## Automated quality checks

GitHub Actions runs **macOS build and tests** on every pull request, push/merge to `main`, merge-queue group and manual dispatch. It uses the `macos-15` ARM64 runner with Xcode 16.4 selected explicitly and builds with a macOS 14 deployment target.

`swift test` runs a separate Swift Testing target. It checks lifecycle/task parsing, project assignments, graph routes and pulse movement, plus the read-only adapter against temporary SQLite databases and JSONL files. Fixtures cover incremental and partial writes, truncation, missing logs/history fallback, stale activity, invalid schemas, and rejected paths. Tests never need your Codex account, live chats, network or credentials. The old `--self-test` option now prints the replacement command and exits; `--diagnose` remains an explicit, local-only diagnostic that reads real records and is not run in CI.

CI also builds the release bundle, validates its plist and ad-hoc signature, and checks required bundled artwork. These checks do not yet exercise native UI, VoiceOver or a macOS 14 runtime. Swift 6 migration, formatting enforcement and a full Xcode app/test scheme remain later foundation work; see [REQUIREMENTS.md](REQUIREMENTS.md).

**Merge enforcement:** Checks run and report failures, but are not yet enforced as a merge requirement. Private-repository protection was unavailable on the account's plan when CI was added. The project is now public for building in public and open-source collaboration; branch protection can be configured separately to require **macOS build and tests** for `main`.

## Data and meaning

The project selector discovers local Codex projects and remembers your selection. **All projects** shows Jarvis above project cards; selecting a project shows every non-archived user or voice chat in it, including newly created chats. The team graph supports more than four chats: cards extend in two columns around a central reactor lane, with vertical scrolling for larger teams and horizontal panning in narrow windows. Each card has a separate elbow-routed connector that stays in the central gutter and ends at a port on its inner edge. Active destinations glow as their travelling pulse arrives. Hovering or selecting a box highlights the matching route, including idle boxes. Card-grid view remains an optional alternative. **Unassigned chats** is available separately. Project grouping uses native project IDs, migrated desktop assignments, and a folder-root fallback (the most specific path wins). Explicitly projectless chats stay unassigned.

Jarvis reads `~/.codex/state_5.sqlite` with SQLite read-only flags, selected project metadata from `~/.codex/.codex-global-state.json`, and local JSONL session records. The first read searches backward for lifecycle markers and the latest meaningful user request; subsequent refreshes read only appended bytes. Delegated agents come from recorded parent-child relationships, excluding approval reviewers. Polling runs every three seconds on an actor away from the UI.

- **In progress:** the latest observed lifecycle marker is `task_started`.
- **Standby:** the latest marker is `task_complete`; the chat may have unfinished broader goals, but its current turn finished.
- **Interrupted:** the latest marker records an aborted turn.
- **Unknown:** no usable marker exists, the record is unavailable, or an open turn has had no file activity for 30 minutes. When a session file is missing, saved user requests can be recovered from the local history database and are explicitly labelled saved history; their activity remains unknown. Long quiet tools can also become unknown; this is deliberately cautious.
- **Latest request:** the actual latest user message, not an AI-generated task summary. Approval replies, heartbeat messages, and injected environment context are filtered out. A short follow-up can therefore appear as the latest request.

The root Jarvis view is an organisational workspace view. It shows the intended hierarchy of you → Jarvis → projects → chats, while clearly marking the coordinator as observation-only. It does not create a boss agent, send instructions, or imply delegation between peer chats. Actual subagents appear under their recorded parent. Historical subagents can remain listed after finishing; the top counter counts only active ones.

The team-observation adapter stays read-only and local. It never edits Codex databases or starts work in existing desktop chats. The separate Jarvis chat connects to the installed Codex App Server over stdio and can start real Codex turns only when you choose Send. This is still an experimental adapter to Codex's internal monitoring records; an update may require an adapter update. Observation errors keep the last snapshot visible and show a disconnected banner.

## Docked Jarvis chat and voice (v0.3)

The right panel now contains our Jarvis artwork, rendered inside this app so it stays with the window and its Space. **Task details** switches back to the mission brief. The original floating Codex pet and its settings are untouched; no foreign window is embedded or moved.

- Type in **Jarvis chat** and choose **Send** or **Command–Return**. The first draft or dictation locks the project folder context, shown above the conversation. Switching the dashboard project cannot reroute that draft. **New chat** explicitly clears the panel/context and disconnects its old connection; it does not delete the saved Codex chat.
- This version creates a dedicated Jarvis conversation through `thread/start`. It does **not** resume, control or impersonate your existing desktop chats; shared ownership remains the INT-02 gate. Existing team cards are observation-only.
- The connection settings detect common Codex installations or let you choose the executable. Jarvis launches it with an argument array, never a shell prompt. Codex handles its own sign-in, provider configuration and permissions. No credentials are copied into Jarvis, no network listener is opened, and no model request is made on launch.
- Chat uses your configured Codex account/provider limits; it is not a free or independently bundled model service. A closed or timed-out send is not replayed. An uncertain outcome disables sending in that conversation; inspect it in Codex before starting a new one.
- Supported command/network and file approvals wait for an explicit decision. File grants are unavailable if complete change details were not received. Questions support option selection and typed answers. Unsupported approval methods return an error without granting access. Existing Codex policies are not broadened or changed.
- The microphone starts **on-device dictation**, not ChatGPT Live Voice. It asks for microphone/speech permissions at first use. Choose a supported language in connection settings. There is no cloud audio fallback. Stop to get an editable transcript, then choose Send yourself. Cancelled/old callbacks cannot fill a later draft. Recording stops on cancel, hiding the chat panel, sleep or quit, and has a 45-second limit. Raw audio is not saved.
- **Read replies** is off by default and uses macOS speech synthesis when enabled. The adjacent speaker button stops speech. This is not the built-in Codex pet's voice or a natural full-duplex voice session.

The app owns one chat connection and cleans up its child app-server/audio resources on exit. Closing Jarvis can interrupt work in its own conversation; independent Codex desktop chats are not stopped. Chat history shown in the panel is bounded and kept only in memory; Codex owns its persisted conversation. No prompt/audio logging or telemetry is added.

## Source

- `Sources/Jarvis/CodexReader.swift`: local read-only adapter and incremental polling.
- `Sources/Jarvis/Models.swift`: lifecycle and request extraction.
- `Sources/Jarvis/Dashboard.swift`: full-screen dashboard and interactions.
- `Sources/Jarvis/Theme.swift`: animated HUD, reactor and connections.
- `Sources/Jarvis/Main.swift`: app lifecycle and acceptance checks.

No login item, background service or external infrastructure is installed. Quitting the app stops polling, audio and its owned App Server connection.

## License

Open source under the [MIT License](LICENSE).
