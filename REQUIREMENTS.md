# Jarvis macOS engineering requirements

Research date: **4 November 2026**. Status: **requirements baseline; automated tests/CI and a bounded docked companion implemented; wider phases pending**.

This is the engineering baseline for turning the personal dashboard into a maintainable Mac app with a docked Jarvis companion, typed and spoken interaction, and eventual Codex coordination. It does **not** authorize implementing those features or refactoring the prototype. The current app has not been audited for compliance with every requirement below.

**Must** means a release requirement for the applicable phase. **Should** means the default approach; a different approach needs a documented reason. Apple and Swift references establish platform guidance; architectural choices, formatting preferences, performance budgets and rollout gates below are **Jarvis project policy**, not claims that Apple mandates a particular architecture or code style.

## 1. Product and platform boundaries

| ID | Requirement | Acceptance evidence |
| --- | --- | --- |
| MAC-01 | Preserve the cyan-and-gold Jarvis identity while retaining familiar Mac controls, menus, text editing, keyboard commands, focus and window behaviour. Use SwiftUI by default and a small, documented AppKit bridge where needed. | Native UI review, keyboard walkthrough and accessibility checks. |
| MAC-02 | Full screen is a primary use case, but windowed use, resizing, multiple monitors, Spaces, sleep/wake and display disconnection must work. Restore the window to an available display; do not force full screen or move across Spaces without a user setting. | Manual matrix including an external display and display removal. |
| MAC-03 | Keep the declared macOS 14 minimum until an explicit compatibility decision changes it. Compile for the actual deployment target and guard newer APIs with availability checks and a fallback. Apple Silicon is the initial target; do not advertise Intel support without building and testing it. | Deployment-target check and a run on the minimum supported OS, or an explicit recorded test limitation. |
| MAC-04 | Render Jarvis's artwork inside our own app. Do not depend on reparenting another app's pet window or private UI. Decide separately whether a companion stays with its window or follows all Spaces. | Docked companion remains attached through window movement and desktop switching. |
| MAC-05 | Show loading, empty, disconnected, stale, permission-denied, interrupted and unknown states explicitly. A visual hierarchy must not imply that a real coordinator or project lead exists before it does. | Screens or UI tests for each state; status tied to evidence. |

Basis: [Apple's macOS design guidance](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos).

## 2. Swift language and code guardrails

| ID | Requirement | Acceptance evidence |
| --- | --- | --- |
| SW-01 | Target **Swift 6 language mode with full concurrency checking**. Record a staged migration from the current Swift 5 mode; do not quiet errors by weakening checking globally. Pin the supported Xcode/Swift toolchain and document the deployment target separately from the SDK version. | Clean build of owned targets in Swift 6 mode; any temporary migration exception is scoped and tracked. |
| SW-02 | Follow Swift API Design Guidelines: clear names at use sites, meaningful argument labels, narrow access control, and documentation for shared interfaces and non-obvious invariants. Prefer value types and enums for immutable domain data; use reference types when identity or ownership requires them. | Review representative call sites and domain interfaces. |
| SW-03 | Choose **swift-format**, with a pinned compatible version, as the single formatter. Project style: four spaces, no tabs, approximately 100-character lines, ordinary multiline declarations and no compressed semicolon chains. Formatter configuration and CI enforcement belong to the next implementation phase. No file-length or coverage quota should substitute for design review. | A future checked-in configuration and non-mutating formatting check. |
| SW-04 | Do not use `try!`, force casts or force unwraps for external input, optional resources, decoding or recoverable failures. An internal invariant exception must have a local explanation and coverage. Avoid `Any` and stringly typed state beyond the decoding boundary; translate into typed IDs, enums and `Codable` domain models. | Malformed data and absent resources produce controlled outcomes. |
| SW-05 | `unsafeBitCast`, unsafe pointers, `nonisolated(unsafe)`, `@unchecked Sendable`, `@preconcurrency` and detached tasks require a narrow interoperability or execution reason, documented ownership and a review. Do not add them just to make the compiler stop complaining. | Scoped boundary with rationale and a relevant test; no blanket bypass. |
| SW-06 | Recoverable errors must be typed and handled at the appropriate boundary. `try?` is acceptable only when absence is an intentional outcome, not when it conceals a broken connection, failed send or corrupt state. No empty catch blocks. | Failure path remains distinguishable from an empty success. |

Basis: [Swift 6 migration guide](https://www.swift.org/migration/documentation/migrationguide/), [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/), and [swift-format](https://github.com/swiftlang/swift-format). Formatting choices are project preferences; swift-format itself does not establish one universal Swift code style.

## 3. Architecture and ownership

Use a small, feature-oriented architecture with explicit boundaries. A large framework, dependency-injection container, plugin system or generic repository layer is not required.

| ID | Requirement | Acceptance evidence |
| --- | --- | --- |
| ARC-01 | Separate presentation, domain logic and integrations. Views render state and emit actions; they must not open SQLite databases, parse logs, run processes, read secrets or call the network. Keep graph geometry pure and independent of SwiftUI rendering. | Domain and geometry tests run without launching the UI. |
| ARC-02 | Split the dashboard into focused feature views and presentation state: project navigation, team graph, task details, chat composer, companion and voice. Keep business state separate from transient selection/hover state. Do not force MVVM, Observation or a third-party architecture solely for its name. | Each state has an identifiable owner; views can preview representative states. |
| ARC-03 | Define narrow injectable boundaries such as `WorkspaceSource`, `CodexGateway`, `SpeechInput`, `SpeechOutput` and a clock. Provide fixtures/fakes for tests. Add an abstraction when there is a real integration or testing boundary, not for every type. | Tests do not require Greg's live account or home directory. |
| ARC-04 | Use one source of truth for selection and typed project/chat/agent IDs. Freeze the destination of a drafted command; changing the visible project must not silently reroute it. Never identify a chat by title alone. | Duplicate-name and switch-project-during-draft scenarios pass. |
| ARC-05 | Own refresh/subscription work at the application/service level. Views subscribe to snapshots rather than starting independent scanners per card or window. Choose one app lifecycle owner; do not hold a Swift concurrency job indefinitely across a nested AppKit run loop. | Opening and closing views/windows does not duplicate readers or leak tasks. |

These are project architecture decisions, informed by the responsiveness and testing guidance below.

## 4. Concurrency, cancellation and responsiveness

Swift cancellation is cooperative; an `async` function or `Task` alone does not prove that expensive work runs off the main actor. Verify the execution and isolation model with the chosen Swift toolchain.

| ID | Requirement | Acceptance evidence |
| --- | --- | --- |
| CON-01 | Isolate UI-bound mutable state to `@MainActor`. Protect mutable integration state with actors or another justified isolation boundary; transfer immutable, appropriately `Sendable` values across boundaries. Account for actor reentrancy across `await`. | Strict concurrency checks and overlapping refresh/selection tests. |
| CON-02 | Database access, large-file reads, decoding, transcript processing and expensive layout calculations must not block the main actor. `Task {}` inherits context; put blocking I/O behind an explicit appropriate executor/queue boundary when necessary. | Instruments trace under large-history and active-animation workloads. |
| CON-03 | Prefer structured concurrency. Every long-lived task, stream, timer and process must have an owner and a stop path. Check cancellation in loops and release file handles, database statements, subscriptions and audio resources on all exits. | Repeated connect/disconnect, cancellation and window-close tests. |
| CON-04 | Prevent overlapping refreshes and late results overwriting newer scope/connection state. Cancel obsolete work, or reject results with generation/request IDs. Treat cancellation separately from a user-visible failure. | Deliberately reordered and delayed responses remain correct. |
| CON-05 | Bound buffers, histories, decoded record sizes and concurrent work. Stream large logs incrementally, handle partial records, truncation/rotation and backpressure. Never load an unbounded conversation history into memory. | Large and malformed fixture tests, with memory measured. |

Basis: [Swift concurrency](https://docs.swift.org/latest/documentation/the-swift-programming-language/concurrency/) and [Apple responsiveness guidance](https://developer.apple.com/documentation/xcode/improving-app-responsiveness).

Initial **project performance targets**, to benchmark during hardening rather than claim as achieved: show the shell within one second; show a first useful snapshot within five seconds on Greg's Mac with a documented fixture; keep ordinary input handling comfortably below 100 ms. Profile frame work against the actual display interval; Apple's guidance suggests aiming around 5 ms for continuous main-thread update work. Record fixture size, hardware, build mode and measurements. Set CPU/memory budgets from that baseline before release rather than inventing universal limits.

Pause decorative animation when hidden or inactive where appropriate, honour Reduce Motion and Low Power Mode, and throttle background observation without abandoning an explicitly running task. Compute routes and filtered snapshots when their inputs change, not repeatedly in each animation frame. Prefer a shared animation time source. Quitting Jarvis must stop its own readers/audio; it must not imply that independent Codex work has stopped.

## 5. UI, graph and accessibility

| ID | Requirement | Acceptance evidence |
| --- | --- | --- |
| UX-01 | Preserve graph and list/card alternatives for every team size. No hidden four-chat cap. Use stable node identities/order and shared geometry for card bounds, connector endpoints, routing and hit targets. Routes must avoid other boxes and terminate at a visible port. | Empty, 1, 4, 7, 20 and 100-node fixtures; narrow and full-screen review. |
| UX-02 | Status must have text or another non-colour cue. Selection, hover and actual work are distinct states; decorative pulses must never fabricate activity or completion. Keyboard focus must offer the same route tracing as hover. | Colour-independent and keyboard-only walkthrough. |
| UX-03 | Give actionable controls stable accessibility identifiers, useful labels, appropriate roles and logical focus order. Decorative reactor/ticks/lines must not flood VoiceOver. Do not put entire transcripts or injected metadata in control labels. | VoiceOver and Full Keyboard Access review plus a focused UI test. |
| UX-04 | Support readable text scaling, sufficient contrast, Increase Contrast and Reduce Motion. Test custom cyan/gold states against their real backgrounds, not merely colour swatches. Preserve contrast without requiring glow. Honour reduced transparency where used. | Accessibility settings matrix; contrast measurements and native inspection. |
| UX-05 | Provide familiar menus and shortcuts, selectable text, discoverable settings, Escape/cancel behaviour and predictable focus after project changes. Avoid hover-only commands and unexpected focus/Space stealing. | Complete main workflows with keyboard only. |
| UX-06 | Make animation optional and restrained. A static state must convey the same information. Small-screen layouts may scroll, pan or collapse a panel; they must not shrink content into illegibility. | Motion off and constrained-window scenarios remain usable. |

Basis: [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility), [motion guidance](https://developer.apple.com/design/human-interface-guidelines/motion), and [macOS design guidance](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos).

## 6. Codex connection and agent-control boundaries

These requirements apply **before enabling command sending**. The present read-only dashboard remains a useful fallback, not proof of a working control integration.

| ID | Requirement | Acceptance evidence |
| --- | --- | --- |
| INT-01 | Use documented Codex protocols for control. Put internal SQLite/JSONL inspection behind a versioned, read-only legacy adapter with capability/schema detection and a clear unavailable state. Never control Codex by editing its databases or session files. | Contract fixtures and unsupported-version behaviour. |
| INT-02 | First prove continuation of an existing chat through the intended backend, including simultaneous desktop ownership, credentials/provider compatibility, streamed replies, interruption and approvals. Do not assume a second app-server process transparently attaches to every desktop chat. | Recorded integration spike against a disposable chat before production chat control. |
| INT-03 | Separate observation, direct chat commands and autonomous coordination as capabilities. Show the selected project/chat and command text before the default Send action. Sending must arise from explicit user intent. A future direct-voice mode requires a clear opt-in; it must not silently enable general autonomy. | No background send in observation mode; destination-switch test. |
| INT-04 | Track drafted, sending, acknowledged, running and terminal outcomes separately. Correlate requests/events with stable IDs. After a disconnect or lost acknowledgement, show outcome unknown and reconcile before offering a retry. Never blindly replay a potentially accepted command; use idempotency only where the protocol guarantees it. | Lost-ack and reconnect tests demonstrate no duplicate dispatch. |
| INT-05 | Preserve Codex permissions, sandboxing and approval decisions. Present approval details with the correct chat and return the actual user decision. Jarvis must not auto-approve, broaden permissions or turn a routine instruction into authority over all chats. Do not add redundant confirmation dialogs for already-authorized routine commands. | Approval, denial, cancellation and disconnect-during-approval cases. |
| INT-06 | Treat chat text, tool output, retrieved pages and transcripts as untrusted data. Role-aware decoding must exclude injected environment/skill/tool records from task previews. Content cannot change the destination, grant authority, become shell code or issue coordinator instructions merely because it appears in a chat. | Fixtures with skill wrappers, instruction-like tool text and duplicate chat names. |
| INT-07 | Launch only the configured, validated local executable with an argument array, not shell-interpolated prompts. Document ownership and cleanup of child processes. Keep the local bridge private and authenticated as required by the transport; no default network-wide listener. | Argument-injection and process/connection cleanup review. |

Basis: [Codex App Server documentation](https://learn.chatgpt.com/docs/app-server), particularly lifecycle, transports, authentication and approvals. Version-specific protocol behaviour must be checked again during implementation.

## 7. Data, credentials, permissions and release security

| ID | Requirement | Acceptance evidence |
| --- | --- | --- |
| SEC-01 | Request only access required by an enabled feature, at first use. Keep workspace reads scoped. For sandboxed persistent file access use user-selected locations and security-scoped bookmarks, balancing access/release and handling revocation/stale bookmarks. No Full Disk Access as the default workaround. | Denied, revoked and relocated-folder scenarios. |
| SEC-02 | Store Jarvis-owned credentials in Keychain; keep ordinary preferences in UserDefaults and durable app state in the app's Application Support location. Do not scrape or copy Codex-managed credentials, put secrets in source/preferences/logs, or persist signed download URLs as identities. | Secret-handling review and redacted diagnostics. |
| SEC-03 | Logs must be bounded and redacted by default. Do not log raw prompts, complete histories, audio, tokens or signed URL queries. Diagnostic export must be explicit and reviewable. Collect no telemetry or crash uploads by default without an intentional product decision. | Inspect exported diagnostics and retention behaviour. |
| SEC-04 | Separate App Sandbox, Hardened Runtime and Codex's execution sandbox: they solve different problems. Decide distribution and helper architecture before choosing entitlements. App Sandbox is required for Mac App Store distribution; Developer ID distribution requires its own documented permission model. Hardened Runtime is a notarization requirement. | A documented distribution decision and entitlement review. |
| SEC-05 | Before external distribution, use appropriate Developer ID signing, Hardened Runtime and notarization; verify the installed artifact. Ad-hoc signing is a local-development convenience, not a shipping security claim. Never disable certificate verification or runtime protections to make an integration work. | Signed/notarized release validation on a clean machine. |

Basis: [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox), [sandbox file access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox), [Keychain services](https://developer.apple.com/documentation/security/keychain-services), and [Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime).

## 8. Voice and companion requirements

These requirements apply before adding microphone or spoken-command features; they do not select or purchase a provider now.

| ID | Requirement | Acceptance evidence |
| --- | --- | --- |
| VOI-01 | Typed chat must remain a complete alternative. Start with explicit push-to-talk, a visible recording state and a reliable stop action. No launch-time listening or wake-word background listener by default. | Permission denied, unavailable microphone and keyboard-only paths. |
| VOI-02 | Choose speech APIs against the supported macOS versions, language and hardware. Verify on-device capability; do not assume Apple's speech recognition is always offline. Disclose and obtain the appropriate consent before a cloud fallback. Add only the usage descriptions/entitlements required by the chosen API, including microphone access. | Permission and provider capability matrix; no silent cloud fallback. |
| VOI-03 | Keep listening, transcribing, thinking, speaking and error states distinct. Partial transcripts cannot dispatch commands. Allow correction/cancellation; freeze the command's destination and show where it will go. Handle interruptions, device changes and sleep/wake. | Partial/misheard speech and destination-switch tests. |
| VOI-04 | Stop capture and release resources on cancellation, logout and quit. Do not retain raw audio by default. Spoken replies must be optional, interruptible and avoid automatically reading confidential content aloud without a user preference. | Audio lifecycle tests and visible mute/stop controls. |
| VOI-05 | Separate Codex/model usage from voice-provider usage in the design. Do not promise an API voice service is included in the Codex subscription; show its applicable usage/cost mode before enabling it. No paid API calls in ordinary tests. | Provider settings and a stubbed voice test run. |

Basis: [Apple Speech permission guidance](https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition). That guidance explicitly distinguishes `SFSpeechRecognizer` and newer transcriber modules; the implementation must verify API availability rather than generalise one API's permission/network behaviour to all speech features.

## 9. Build, tests and completion gates

| ID | Requirement | Acceptance evidence |
| --- | --- | --- |
| QA-01 | Establish a reproducible macOS app target with owned resources, deployment/signing settings and a shared scheme. SwiftPM can host testable core modules. Keep the existing launcher usable until a replacement is verified. Record SDK/toolchain versions and keep release assets bundled, not loaded from Greg-specific absolute paths. | Fresh-checkout build and launch with resources present. |
| QA-02 | Use Swift Testing for appropriate unit/integration tests and XCTest/XCUIAutomation for native UI/performance tests. Keep test targets separate from the shipping executable; migrate useful `--self-test` checks rather than discarding them. | Independent test commands and meaningful failure output. |
| QA-03 | Test behaviours that can fail: project membership, stale/unknown lifecycle state, partial/rotated logs, injected records, cancellation, graph routing/hit targets, missing resources, disconnects and duplicate sends. Use synthetic or sanitized fixtures. Do not depend on live chat counts, local file paths, an account, microphone, network or paid services for ordinary CI. | Deterministic suite runnable on another machine. |
| QA-04 | Add focused UI coverage for project switching, selecting a chat, tracing connections, full screen, composer destination and keyboard access. Use stable accessibility IDs and condition-based waits. Verify visual geometry and accessibility separately from business logic; screenshots alone do not prove behaviour. | Automated workflows plus native manual checks where automation is insufficient. |
| QA-05 | Before declaring a code change complete: clean build, applicable tests, formatter/concurrency checks once configured, and relevant native UI verification. Profile meaningful performance changes. Report exactly what passed and what remains untested; never label the whole app production-ready from a compile or ad-hoc signature alone. | Concise verification record tied to the change. |

Basis: [Apple testing overview](https://developer.apple.com/documentation/xcode/testing), [swift-format](https://github.com/swiftlang/swift-format), and [Apple responsiveness guidance](https://developer.apple.com/documentation/xcode/improving-app-responsiveness). Test depth follows risk; trivial styling changes do not need tests that merely repeat their implementation.

## 10. Current gaps and implementation order

This is a preliminary source-based gap list, **not** a full audit or a claim that other requirements pass.

| Order | Phase / gap | Completion gate |
| --- | --- | --- |
| 1 | **Foundation hardening.** The package and shell build currently select Swift 5 language mode. The app is manually bundled; resources and deployment compatibility need a proper build/test contract. A separate fixture-based Swift Testing target and GitHub Actions build/tests now exist. The legacy in-executable tests have been migrated; a full Xcode app scheme, Swift 6 migration and formatter enforcement remain pending. | Reproducible app target, fixtures/test targets, staged Swift 6 migration and a recorded baseline. |
| 2 | **UI and data separation.** `Dashboard.swift` combines navigation, feature UI and derived state. State parsing still relies on internal Codex files. Accessibility, graph scale and task-preview filtering require systematic coverage. | Clear boundaries, role-aware decoding, native keyboard/VoiceOver checks and bounded work. |
| 3 | **Typed Codex connection spike.** The dedicated Jarvis connection has handshake/ephemeral setup verification; shared access to existing desktop chats and ownership remain unverified. | One disposable existing chat can receive a typed command, return streamed output and preserve approvals without duplicate dispatch. |
| 4 | **Docked companion and voice.** The docked companion, typed chat, on-device dictation drafts and optional macOS spoken replies are implemented. First-party live voice remains unimplemented; real microphone acceptance is pending. | Implement only after the typed command path works; satisfy VOI requirements and preserve typed operation. |
| 5 | **Coordinator and distribution.** Global view is currently observation-only, and builds are ad-hoc signed. | Explicit authority model, reliable lifecycle/cost reporting, and a separately approved distribution route before sharing. |

Do not perform these phases automatically. The next user-authorized implementation should pick a bounded phase, state its acceptance criteria, preserve the working prototype and record any deviation with the affected requirement IDs, reason, owner and follow-up. Requirements may be revised when evidence changes; they must not be silently weakened to make a build pass.

## Research notes

Primary sources only: Apple's Human Interface Guidelines and developer documentation, Swift's language/migration/API guidance, the swiftlang formatter repository, and official OpenAI App Server documentation. Apple Markdown versions were retrieved where the normal web pages required JavaScript. No third-party blog architecture was treated as a platform requirement. Source links are placed by the requirements they informed. Recheck version-sensitive APIs and protocol capabilities when implementation begins.


## v0.3 implementation scope and remaining gates

The docked companion renders our own bundled artwork (MAC-04). A dedicated new Jarvis conversation uses the documented stdio App Server protocol; existing desktop chats remain read-only. The installed CLI passed initialization and an ephemeral-thread setup probe without any model turn. Model streaming, approval and failure behaviour are tested with fixtures; no paid turn is silently sent as a test. **INT-02 is not marked passed:** continuing existing desktop chats, shared ownership and cross-chat coordination remain disabled/pending.

Voice is an editable, on-device dictation draft plus optional macOS spoken replies, with no cloud audio fallback or first-party pet embedding. Full-duplex Codex Voice is not implemented. Microphone permission, real speech recognition/synthesis and minimum-OS runtime behaviour still need human acceptance on the intended Mac; ordinary CI never requests those permissions.

The current package still uses Swift 5 language mode (SW-01 migration remains pending); new connection state is actor-owned and UI state is main-actor isolated. Formatter enforcement and an Xcode UI-test scheme remain pending, not waived. The native checks cover visible artwork, full-screen layout, draft/send enablement, context locking across a project change, settings and keyboard text editing. Synthetic tests cover the protocol, replies/approvals, stale/foreign events, duplicate/uncertain sends, child-process boundaries and dictation generations. No screenshot of personal chat contents is included in the public repository.
