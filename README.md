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

Requires the installed Apple command-line tools; no third-party packages or API keys.

## Automated quality checks

GitHub Actions runs **macOS build and tests** on every pull request, push/merge to `main`, merge-queue group and manual dispatch. It uses the `macos-15` ARM64 runner with Xcode 16.4 selected explicitly and builds with a macOS 14 deployment target.

`swift test` runs a separate Swift Testing target. It checks lifecycle/task parsing, project assignments, graph routes and pulse movement, plus the read-only adapter against temporary SQLite databases and JSONL files. Fixtures cover incremental and partial writes, truncation, missing logs/history fallback, stale activity, invalid schemas, and rejected paths. Tests never need your Codex account, live chats, network or credentials. The old `--self-test` option now prints the replacement command and exits; `--diagnose` remains an explicit, local-only diagnostic that reads real records and is not run in CI.

CI also builds the release bundle, validates its plist and ad-hoc signature, and checks required bundled artwork. These checks do not yet exercise native UI, VoiceOver or a macOS 14 runtime. Swift 6 migration, formatting enforcement and a full Xcode app/test scheme remain later foundation work; see [REQUIREMENTS.md](REQUIREMENTS.md).

**Merge enforcement:** GitHub currently rejects branch protection for this private repository on the account's plan. Checks run and report failures, but GitHub does not block merging on them. Once the account supports private-repository protection, make **macOS build and tests** required for `main`. Do not change repository visibility to work around this.

## Data and meaning

The project selector discovers local Codex projects and remembers your selection. **All projects** shows Jarvis above project cards; selecting a project shows every non-archived user or voice chat in it, including newly created chats. The team graph supports more than four chats: cards extend in two columns around a central reactor lane, with vertical scrolling for larger teams and horizontal panning in narrow windows. Each card has a separate elbow-routed connector that stays in the central gutter and ends at a port on its inner edge. Active destinations glow as their travelling pulse arrives. Hovering or selecting a box highlights the matching route, including idle boxes. Card-grid view remains an optional alternative. **Unassigned chats** is available separately. Project grouping uses native project IDs, migrated desktop assignments, and a folder-root fallback (the most specific path wins). Explicitly projectless chats stay unassigned.

Jarvis reads `~/.codex/state_5.sqlite` with SQLite read-only flags, selected project metadata from `~/.codex/.codex-global-state.json`, and local JSONL session records. The first read searches backward for lifecycle markers and the latest meaningful user request; subsequent refreshes read only appended bytes. Delegated agents come from recorded parent-child relationships, excluding approval reviewers. Polling runs every three seconds on an actor away from the UI.

- **In progress:** the latest observed lifecycle marker is `task_started`.
- **Standby:** the latest marker is `task_complete`; the chat may have unfinished broader goals, but its current turn finished.
- **Interrupted:** the latest marker records an aborted turn.
- **Unknown:** no usable marker exists, the record is unavailable, or an open turn has had no file activity for 30 minutes. When a session file is missing, saved user requests can be recovered from the local history database and are explicitly labelled saved history; their activity remains unknown. Long quiet tools can also become unknown; this is deliberately cautious.
- **Latest request:** the actual latest user message, not an AI-generated task summary. Approval replies, heartbeat messages, and injected environment context are filtered out. A short follow-up can therefore appear as the latest request.

The root Jarvis view is an organisational workspace view. It shows the intended hierarchy of you → Jarvis → projects → chats, while clearly marking the coordinator as observation-only. It does not create a boss agent, send instructions, or imply delegation between peer chats. Actual subagents appear under their recorded parent. Historical subagents can remain listed after finishing; the top counter counts only active ones.

Everything stays on this Mac. The app does not read credentials, make model calls, modify Codex records, start chats, send messages, or spend API tokens. This is an experimental adapter to Codex's internal local record format, not an officially supported live monitoring API. An update to Codex can require an adapter update. Errors keep the last snapshot visible and show a disconnected banner.

## Source

- `Sources/Jarvis/CodexReader.swift`: local read-only adapter and incremental polling.
- `Sources/Jarvis/Models.swift`: lifecycle and request extraction.
- `Sources/Jarvis/Dashboard.swift`: full-screen dashboard and interactions.
- `Sources/Jarvis/Theme.swift`: animated HUD, reactor and connections.
- `Sources/Jarvis/Main.swift`: app lifecycle and acceptance checks.

No login item, background service or external infrastructure is installed. Quitting the app stops polling.
