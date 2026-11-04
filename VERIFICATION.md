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
