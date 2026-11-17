# Native app boundaries

Ticket #48 separates responsibilities in the Swift app. “Frontend/backend/shared” described code organization, not a web target. This change introduces no web framework, runtime, service or new permission.

## Where code belongs

| Location | Responsibility | Dependencies |
| --- | --- | --- |
| `JarvisDomain` module | Workspace values, lifecycle rules and `WorkspaceSource` contract | Foundation |
| `JarvisWorkspace` module | Read-only SQLite/log adapter | Domain, Foundation, SQLite3 |
| `Jarvis/Shared` | App contracts and values, protocol framing, Markdown/attachment parsing, dictation transitions, graph geometry | Foundation; no UI or I/O |
| `Jarvis/Application` | Conversation/draft state, destination and approval handling, refresh ownership, dashboard/preview state | Shared, Domain, Foundation, Combine |
| `Jarvis/Integrations` | Codex process and executable validation, file storage/previews, speech, external desktop actions | Shared and required native libraries; no Application or Presentation types |
| `Jarvis/Presentation/Views` | Dashboard, companion and settings screens | Application, Shared, Domain and injected native capabilities |
| `Jarvis/Presentation/Components` | Reusable visual controls and rendering | Same as Views |
| `Jarvis/Presentation/Platform` | AppKit editing/clipboard/window and Core Animation bridges | Same as Views; native UI libraries |
| `Jarvis/Main.swift`, `Jarvis/Composition` | Lifecycle, live capability construction and isolated fixture wiring | All layers; only Main imports the workspace adapter |

Views emit actions to their state or injected capabilities. Application code uses the `CodexConnection` and `ComposerImageSaving` contracts, not concrete process/file implementations. Preview state receives an asynchronous loader closure. Main owns the live transport factory, image store, preview loader, desktop actions and voice object. Tests supply in-memory fakes or explicit temporary file stores. There is no hidden live process factory in `CompanionModel`.

`LocalVoice`, `DesktopActions` and the existing `CompanionArtwork` observable integration are explicit presentation-facing capabilities. Views may observe/call injected instances, but may not construct them. Internal integration helpers remain owned by their integration. This keeps the existing native speech lifecycle intact without adding an abstract service for every type.

Two bounded native responsibilities stay close to UI state: `DashboardState` stores ordinary display/refresh preferences through an injectable `UserDefaults?`, and the animation bridge loads bundled reactor artwork. Clipboard conversion and first-responder/window operations are UI bridges. These are not authority to add arbitrary file/process/network work to views. Secrets never belong in preferences. Future growth of these responsibilities should introduce a narrow capability at the actual integration boundary.

## Enforcement and its limits

The existing SwiftPM/Xcode `JarvisDomain` and `JarvisWorkspace` modules retain compiler-enforced dependency separation. The four folders inside Jarvis remain one executable module, so they are **source-policy boundaries, not compiler access control or a security sandbox**.

`quality-gate test` now also runs `AppArchitecture` over every app Swift file. It rejects uncategorized sources, disallowed imports, reverse references to top-level layer-owned types, selected privileged APIs in pure/application/presentation layers, and construction of presentation-facing integrations in views. Source root escapes and missing/empty roots fail. The existing workspace manifest/source checks still run.

The scanner ignores comments and string literals, including interpolation; it is not a Swift compiler/effect analyser. It cannot prove the effects of arbitrary functions, dynamically dispatched calls, aliases or code hidden in interpolated strings. Locally declared type names are excluded from cross-file reference checks; name collisions and shadowing still need review. Review the diff and runtime boundaries as well as the gate. If stronger isolation becomes necessary, move a cohesive layer into a compiler module instead of growing a purported security parser.

`scripts/verify-app-architecture.sh` injects forbidden imports, concrete cross-layer references, process construction and uncategorized files into disposable source-policy fixtures. It requires the expected failure diagnostic, corrects each fixture and requires success. These probe snippets exercise the source gate, not Swift compilation. Unit tests additionally cover allowed contract-based directions, native bridge injection, comment/literal handling and absent roots. The full app then compiles and runs its separate behaviour tests.

## Review and verification

Most app changes are moves and extractions. Review the new wiring in Main, the removal of the default live transport, injected image storage/previews and `DesktopActions` first. Then review the policy and its deliberate failing fixtures. SwiftPM discovers nested files; the Xcode project explicitly lists the same owned sources and the native UI runner verifies that membership before launching.

Run `./scripts/check.sh` for pinned formatting, Swift 6/concurrency probes, both architecture policies/probes, complete discovered/critical test inventory and the Release bundle. Existing framing, malformed-data, destination, approval, uncertain-send, cancellation, image and voice tests remain. New image capability tests verify queue routing through injected storage, no storage call in disabled fixtures, and explicit unavailable behaviour when storage is absent.

With full Xcode, run `swift run -Xswiftc -warnings-as-errors native-ui-check` for all six synthetic native journeys. Native UI fixture mode disables image loading and desktop actions as well as live transport/audio; it does not read attachments from transcript paths. Native UI evidence does not establish minimum-OS, VoiceOver, real microphone, multiple-display or production Codex compatibility. Those manual gaps remain documented in [native UI verification](native-ui.md).
