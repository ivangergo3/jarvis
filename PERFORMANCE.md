# Local performance check — 5 November 2026

Hardware: Apple M3, 8 CPU cores, 24 GiB RAM. Native ARM64 release build (`swiftc -O`), macOS 27.2. The existing build already targeted Apple Silicon; no machine-specific CPU affinity or unsafe compiler flags were introduced.

CPU was measured as the change in the Jarvis process's accumulated CPU time divided by elapsed wall time. 100% means one fully occupied core. Samples used the live six-chat project with two active chats and the conversation pane open. These are short local observations, not a controlled fixture benchmark or guaranteed usage ceilings. Other chats were active, window geometry changed during UI verification, and transient layout/history work can cause peaks. The measurements exclude Codex helper processes, WindowServer and GPU/energy consumption.

| State | Wall time | Jarvis CPU time | Average CPU |
| --- | ---: | ---: | ---: |
| Previous renderer, visible map | 12.01 s | 1.47 s | 12.24% |
| Compositor renderer, visible map | 12.01 s | 0.18 s | 1.50% |
| Compositor renderer, card view | 12.01 s | 0.16 s | 1.33% |
| First hidden-window sample, including transient work | 12.01 s | 0.89 s | 7.41% |
| Settled background sample | 20.01 s | 0.10 s | 0.50% |

The map samples show about an 88% reduction in the app process. The initially higher hidden sample is retained here rather than treating the best sample as a ceiling. The settled background profile was predominantly waiting in the main run loop. The final small follow-up also suspends the one-second clock timer while hidden; the numbers above precede that clock-only refinement.

Changes:

- Replaced per-frame SwiftUI timelines for reactor orbits, route dots and moving activity borders with compositor-owned Core Animation layers. Geometry and artwork are reused rather than rebuilt each frame. Layer animations are removed when their views detach.
- Follow-up on 5 November: cursor tracking and tilt were removed entirely after a user-reported freeze during vigorous cursor movement. The samples above preceded that removal and did not test that interaction workload. The reactor now stays fixed, with no cursor-driven update path.
- Decoration pauses when the app is inactive, its window is occluded/hidden, Low Power Mode is enabled, or Reduce Motion is enabled. Active status remains visible as a static indicator.
- Foreground polling retains the selected interval. Inactive/Low Power Mode polling uses at least 15 seconds; hidden polling uses at least 30 seconds. This does not stop independent Codex work or dispatch any messages.
- Unchanged history and workspace snapshots no longer publish updates that rebuild the dashboard and conversation. Markdown views are equatable by their text.

Validation: release build; 78 fixture tests including compositor shutdown, history publication suppression, background cadence and existing routing/approval safeguards; native map/card switching and visual inspection. Full-device energy profiling, minimum-OS acceptance and long-duration/high-agent-count benchmarking remain future measurements. No private transcripts, screenshots or raw stack profiles are committed.

## Card-hover follow-up

The earlier short, quiet samples did not represent vigorous hovering. A later 60.012-second recording with the user moving across graph/cards measured **18.38% mean CPU**, **29.91% maximum one-second CPU**. A second 60.005-second recording, including idle periods and two automatically triggered stack samples, measured **5.93% mean**, **27.08% maximum**. These are different workloads, not interchangeable benchmarks. Sampled busy stacks included SwiftUI/AttributeGraph updates, but the profiles are not a complete attribution of CPU costs.

Source inspection found that card enter/exit published dashboard-wide state and recreated all connector layers/animations. Hover state now belongs to a separate observable object subscribed to only by route/destination decorations. Repeated enters and stale exits are ignored. Connector geometry/layers are retained across hover changes; running signals keep their animations. Border/reactor configuration also skips unchanged values.

The reactor's requested centre pulse uses one small, fixed Core Animation opacity layer with a cached shadow path. It follows the existing inactive/hidden/Low Power/Reduce Motion policy. The artwork remains stationary with no mouse tracking.

Validation: native ARM64 release build and **81 tests in 17 suites** passed, including hover publication isolation, stable connector layer identity, pulse shutdown and fixed artwork. Native app relaunched with the existing typed draft restored, without sending it. Post-change user-driven minute measurement: **60.005 seconds**, **9.10% mean CPU**, **20.91% maximum one-second CPU**. Compared with the first hover recording, the observed mean fell about 50% and the peak about 30%. Cursor movement was performed manually and not replayed identically, so this is evidence of improvement in this session, not a controlled causal benchmark or a guarantee that hover costs are eliminated. No raw private profiles or screenshots are stored in the repository.

Pulse adjustment: the fixed centre overlay now dims the original artwork from opacity 0.60 to 0.08 over 0.65 seconds each way (1.3-second cycle), with no added shadow glow. Static/reduced-motion state uses opacity 0.28. This retains the same one-layer compositor implementation.

Core-only visual correction: the previous 18%-diameter dark disc overlapped the cyan rim and dimmed too strongly. Replaced it with one radial gradient confined to the central 9.5% of artwork diameter, feathered to zero at its edge. Attenuation ranges from 0.02 to 0.22 (static 0.10); the original white centre remains luminous and surrounding cyan pixels are untouched. Cycle remains 1.3 seconds, compositor-owned with existing pause policy and no pointer tracking.

Invisible-pulse regression: the radial gradient's previous end point `(1, 0.5)` shared the start point's Y coordinate, collapsing its vertical radius. A focused geometry plus bitmap-render test failed on the previous implementation (zero vertical radius and zero centre alpha). Correcting the end point to `(1, 1)` restores a circular visible gradient while keeping the same core coverage, subtle intensity and animation cost. No brightness increase or cursor tracking added.
