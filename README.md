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

GitHub Actions runs **macOS build and tests** on every pull request, push/merge to `main`, merge-queue group and manual dispatch. It uses the standard `macos-15-intel` runner with Xcode 16.4 selected explicitly and builds with a macOS 14 deployment target.

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

The team-observation adapter stays local and read-only. It never edits Codex databases. The conversation panel links to the selected existing chat through Codex's App Server queue APIs and reads recent saved history through the protocol. Sending is an explicit user action; it does not start a second agent runtime or create a new chat. Monitoring still depends on Codex's internal local record format, so updates may require an adapter update.

## Linked Jarvis conversations (v0.4)

The pet lives inside this window. Choose an existing chat in the sidebar or graph: **Send to: [chat name]** identifies the actual destination. The app remembers the selected chat by its unique ID, not by its title. Renames preserve that link and duplicate titles remain separate destinations.

- The panel shows recent saved conversation summaries (12 turns) plus up to 100 queued messages. It refreshes every three seconds while the dashboard is open. History may lag while Codex is writing a turn; this is not a full transcript export or a second live owner.
- **Send** / **Command–Return** submits to that existing chat's shared Codex queue. A **YOU · QUEUED** bubble means Codex has queued the message, not that a reply is complete. Busy chats process their queue as work permits. If the chat is not loaded, use **Open in Codex** to continue it. Approvals and work controls stay in the owning Codex app.
- Selecting another card follows that chat only when it is safe. An unsent draft, dictation session, in-flight send or uncertain acknowledgement cannot be silently moved. A mismatch names both the retained destination and the newly selected card; the reconnect button explicitly switches/reconnects, with confirmation before discarding a draft.
- The queue uses a distinct client message ID. After a lost acknowledgement, sending is disabled until a read-only queue/history lookup confirms that same submission or you explicitly leave the conversation. Requests are never automatically replayed. A known rejection retains the draft. Delivered messages and queued entries deduplicate by client ID, not matching text.
- The installed Codex App Server supplies `thread/queue/add`, `thread/queue/list`, and `thread/turns/list`. Queue methods currently require the per-connection `experimentalApi` capability. This opts in to protocol fields only; no sandbox or permission settings are changed. Unsupported versions show an error and disable sending; they never fall back to a newly created chat. The equivalent CLI operation is `codex queue --thread <ID> --message <TEXT>`; see [official developer commands](https://learn.chatgpt.com/docs/developer-commands) and [App Server documentation](https://learn.chatgpt.com/docs/app-server).
- Jarvis launches the installed Codex executable with fixed arguments over private stdio. Codex manages its own sign-in/provider configuration. Jarvis copies no credentials and opens no network listener. Background refreshes are read-only; they do not send model prompts.
- Dictation remains on-device, with no cloud audio fallback. Microphone and speech permission prompts occur at first use. Stop to review the transcript, then choose Send yourself. Cancelled callbacks cannot fill a later draft. Capture ends on cancel, hiding the panel, sleep or quit, with a 45-second limit. Raw audio is not saved.
- **Read replies** uses optional macOS speech synthesis; old history is not spoken when first connecting. The speaker button stops playback. This is dictation plus spoken replies, not the first-party pet's full-duplex Live Voice.

The original floating Codex pet and the earlier v0.3 standalone Jarvis conversation are untouched. Old messages are not migrated, copied into another chat or deleted. Closing this window cleans up Jarvis's read/queue child connection and audio; it does not stop the linked desktop agent. No private chat IDs, prompts, real history fixtures or screenshots are committed to this public repository.

## Source

- `Sources/Jarvis/CodexReader.swift`: local read-only adapter and incremental polling.
- `Sources/Jarvis/Models.swift`: lifecycle and request extraction.
- `Sources/Jarvis/Dashboard.swift`: full-screen dashboard and interactions.
- `Sources/Jarvis/Theme.swift`: animated HUD, reactor and connections.
- `Sources/Jarvis/Main.swift`: app lifecycle and acceptance checks.

No login item, background service or external infrastructure is installed. Quitting the app stops polling, audio and its owned App Server connection.

## License

Open source under the [MIT License](LICENSE).
