# First prototype verification

- Release app compiled with Apple Swift 6.4 and bundled as `build/Jarvis.app`.
- Ad hoc code signature verified with `codesign --verify --deep --strict`.
- App bundle metadata passed `plutil -lint`.
- Lifecycle/request extraction and live local integration checks passed with `--self-test`.
- Diagnostic mode located all four real chats, matched active/standby evidence, and read recorded parent-child subagents.
- Native UI opened and rendered actual records. Chat selection updated the mission brief. Activity and card/map switching worked.
- Full-screen expansion was checked visually. Four cards and detail panel remained readable; the reactor and connections animate gently.
- Polling updated the sync timestamp and observed current log activity. Pause/resume controls changed state correctly.

Known limits: the task is a latest user request, not a generated summary. Local lifecycle markers can become stale after a crash, so open turns without file activity for 30 minutes show unknown. Some historical subagents lack usable lifecycle markers and show unknown. The internal Codex record format may change. The team map groups peer chats and does not manage them.

## Multi-project update (v0.2)

- Discovered all four local project names from the project catalog, including migrated desktop assignments.
- Added All projects and Unassigned chats scopes, automatic discovery of user and voice chats, and saved project selection.
- Project grouping checks cover nested folders, sibling path boundaries, legacy IDs, explicit assignment precedence, and explicitly projectless chats.
- The previous four core chats remain in money; French is now included as a voice chat.
- Missing older session records retain unknown status and show clearly labelled saved requests from the history database.
- Repeated polling checks compare stable chat ID sets, allowing real activity to reorder chats.
- Acceptance checks and app signature verification passed after this update.

## Expanded graph update (v0.2.1)

- Removed the automatic four-node switch to card view.
- Card and connector positions now use one shared layout, extending vertically for larger teams and allowing horizontal panning in narrow windows.
- Graph nodes use stable alphabetical ordering so background activity does not rearrange the graph.
- Native UI verified money's seven actual chat nodes, visible reactor connections, and scrolling to the final Xiaomi monitor card in full screen.
- The graph and grid switches are both available for larger teams. Existing acceptance checks and app signature verification passed.

## Clear destinations (v0.2.2)

- Each connector uses its own central-gutter lane and ends at the midpoint of its card's inner edge, marked by a port and arrow.
- Active destinations pulse with the arriving particle. Selected or hovered idle destinations highlight in gold, with their matching route.
- Geometry regression checks passed for 4, 7 and 20 nodes at narrow and wide viewport sizes, sampling each route to reject intersections with other cards.
- Release build, existing acceptance checks and signature verification passed.
- Native full-screen visual check confirmed money's seven-card routing and matching gold Coding box/connection highlighting; the active cyan Xiaomi route and destination glow were visible.

## Automated quality baseline (4 November 2026)

- Moved the useful in-executable acceptance checks into an independent Swift Testing target, replacing live personal-account assertions with disposable SQLite/JSONL fixtures.
- `swift test`: 20 tests across four suites passed locally, including parameterized lifecycle, role/filter and graph-size cases. Graph checks cover every connector segment against other cards for 0, 1, 4, 7, 20 and 100 nodes at two viewport sizes.
- Reader tests cover read-only database enforcement, literal parameter binding, visible chat/agent filtering, desktop assignments, incremental/partial logs, truncation, history fallback, stale work, out-of-scope symlinks and invalid catalogs/schemas.
- Release app compiled with an explicit macOS 14 deployment target. Bundle plist lint and ad-hoc signature verification passed.
- GitHub Actions is configured for pull requests, pushes/merges to main, merge groups and manual runs on macOS 15 ARM64 with Xcode 16.4. Hosted run results are authoritative for that toolchain.
- GitHub rejected private-repository branch protection on the current account plan (HTTP 403); passing checks are not an enforced merge requirement yet.
- No native UI automation or minimum-OS runtime test is claimed. Swift 6 migration, formatter enforcement and the full Xcode scheme remain pending.


## Docked companion (v0.3)

- Added a window-owned Jarvis pet and independent chat panel, with native Edit menu shortcuts and the existing mission brief still available.
- Local `swift test`: 37 tests across eight suites passed, including subprocess framing/cleanup, literal prompt transport, duplicate/uncertain sends, pinned contexts, foreign/stale events, approval decisions, required answers, withheld file grants without a review, and cancelled speech callbacks. The installed command-line SDK needed its bundled Testing macro plugin path supplied locally; that machine-specific path is not committed into the package or CI.
- Release app compiled for macOS 14; plist and ad-hoc signature validated. CI also checks all six pet frames and both permission descriptions.
- Native window checks verified visible pet artwork, full-screen layout, editable draft and Send enablement, project changes retaining the original conversation context, settings, Select All/Delete and resetting the unused conversation. No message was sent in these UI checks.
- The installed Codex CLI accepted initialization and an ephemeral-thread setup probe without a model turn or persistent chat. Normal tests use only fake connections and disposable fixtures.
- Real-account model streaming and microphone/speaker hardware acceptance are not claimed. No account-backed generation, microphone recording or paid voice API test was silently performed. Existing desktop chat control remains disabled; shared ownership is still the INT-02 gate.
- Reuses the six idle frames from Greg’s existing Jarvis companion. The original floating Codex pet is not changed. No private screenshots or real conversation fixtures are included in the repository.
