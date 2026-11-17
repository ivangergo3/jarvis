# Reproducible performance protocol (#47)

This protocol is recorded before collecting timing results. The first concern
is the prior hover regression: pointer-driven decoration must not republish the
dashboard/conversation or rebuild unchanged connector geometry. Existing
publisher/layer-identity assertions remain hard correctness gates. Variable
CPU, memory and timing results remain informational until repeatability and
owner-agreed budgets support a gate. Profiling and any optimization are separate
reviewable changes; no broad optimization is presumed necessary.

## Workloads and measurement boundaries

- Release builds only, same compiler/settings/fixture before comparison.
- Synthetic workspace with projects containing 1, 4, 20 and 100 chats, plus an
  empty project; fixed generated log content and known lifecycle outcomes.
- Seven measured repetitions after an explicit warm-up for parser framing,
  graph routing (0/1/4/20/100 nodes), fresh-adapter workspace reads and cached
  unchanged reads. Record all samples, not only the fastest.
- Native-control launches are background-only; retain their startup proxies
  separately. For active interaction, collect three warm phase repetitions in
  one explicitly activated fixture process. This avoids pretending background
  launches measure foreground behaviour. Measure process-main entry
  to first native draw and first populated workspace body evaluation. These exclude work
  before main/LaunchServices and are not cold-disk launch claims.
  Project-switch timings stop at the target SwiftUI body evaluation, not GPU
  presentation. The initial draw-callback readiness protocol failed on a real
  layer-backed update (revision d9f36a6); that failed run is retained and excluded
  from successful baselines. The revised boundary is explicit, not a fabricated
  substitute for an unobserved draw.
  A background-only run at 0e584df is retained separately: its foreground flag
  was false throughout, so its different animation policy is not silently pooled
  with the foreground baseline. Measured phases now wait for explicit activation.
- Exercise the real displayed hover state at a fixed cadence, then a bounded
  soak. Record root/conversation/card/topology work and connector rebuilds,
  own-process user+system CPU, resident memory, and main-actor heartbeat delay.
  Heartbeat delay is scheduling evidence, not input-to-photon latency.
- Programmatic hover state is the same path used by `.onHover`; it does not
  include physical pointer/event-dispatch/hit-testing overhead. A manual cursor
  recording is a separately labelled supplement, never silently pooled with it.
  Physical hover callback counts distinguish pointer activity from scripted
  state changes; coordinates and text are never recorded. The human segment is
  sixty seconds; automatic warm repetitions/soak continue afterward without
  requiring further pointer activity. Offscreen nodes remain mounted in the
  graph workload. These are different workloads, not interchangeable input rates.

Fresh processes/adapters are distinguished from warm caches. OS filesystem and
graphics caches are uncontrolled: do not call them truly cold, flush global
caches or compare debug and release. CPU 100% means one logical core; GPU and
WindowServer cost are outside own-process counters. Record revision, binary,
architecture/hardware model, OS, toolchain, fixture sizes, repetitions, window
size, animation state and observed spread. No private chats or system-wide
telemetry are inputs. Instruments availability is reported honestly.

## Correctness and noise policy

Check IDs/counts, parser order, finite routes, unchanged display content,
cancellation and stale work alongside timings. A disposable seeded regression
must demonstrate the stable hover gate fails for an actual forbidden effect,
then passes on restoration; compiler errors or zero tests are not detections.

Report median, p95, min/max and raw samples. Keep machine-dependent numbers out
of ordinary required-check pass/fail decisions. Investigate an apparent change
using the same release build/fixture, repeated paired runs and main-thread/CPU
evidence before attributing it to code. Do not retune a threshold after a failed
run, discard a slow sample without a recorded external cause, or hide a skipped
measurement as a pass. Agree user-visible resource/latency budgets from the
baseline before enforcing them. The requirements' initial 1 s/5 s/100 ms targets
remain proposals, not claims that the measured boundaries establish all three.

## Hover regression gates and fix

The physical foreground recording captured 1,121 hover callbacks in 60 seconds:
22.82% mean own-process CPU (28.75% maximum one-second sample), stable resident
memory near 120 MiB, zero root/conversation/layout/card/connector rebuilds, but
22,420 destination-modifier evaluations. This isolated the remaining fanout:
every mounted destination observed the same hover object. The report's revision
field predates uncommitted instrumentation changes; the local evidence retains
the source patch and binary digest rather than presenting that field as a clean
revision. The following morning's missing temporary log files are a fixture
failure, not an app performance result. Fixture clocks now use creation time
instead of assigning ancient mtimes to temporary files.

The fix keeps the connection overlay's shared hover observation but gives each
mounted card its own highlight state. A transition publishes only to the old
and new destination, and duplicate enters/stale exits remain no-ops. The registry
holds weak references and prunes dead entries when registering another card;
navigation does not retain old card state. Selected/active highlighting and
the existing retained Core Animation layers remain separate.

The next measured slice exposed another fanout: the overlay retained geometry
but reassigned every line's Core Animation properties on every move. Applied
line styles are now cached; only a changed visible style writes layer properties.
Active styling continues to win over hover, and moving the view to a window or
rebuilding routes invalidates the cache. A native layer workload exercises 1,000
moves at 4 and 100 lines, verifies exactly two style writes per move including
final clearing, and checks layer identity and restored colors. Its deliberate
fault removes the cache guard and must fail the `writes` assertion.

Required ordinary tests run 10,000 transitions for each of 1/4/20/100/1,000
mounted destination states. They require exactly two destination notifications
per genuine move (including final clearing), no root publication, correct final
highlighting, state reuse, and release after unmount. These are work/ownership
contracts, not timing thresholds. `quality-gate hover-fault` seeds both parent
publisher forwarding and all-card notification fanout in disposable copies. It
requires the named assertions to fail and the restored implementation to pass;
compilation errors, missing cases and skipped tests fail the probe.

The required native UI journey `testHoverLoadKeepsRenderedUpdatesLocal` mounts
the actual 100-card dashboard using the closed in-memory verification source,
warms it, then performs 200 paced transitions and clears the highlight. It
requires zero dashboard/conversation body or publisher updates, graph layout,
card factory or connector geometry work. Destination modifiers may evaluate at
most twice per move plus once for clearing; topology must evaluate but at most
once per move plus clearing. Native line-style writes are bounded to the two
affected connections as well. Zero recorded rendering is not accepted as a pass.
This detects accidentally reconnecting the rendered modifier to shared hover
state, which publisher-only tests cannot prove. The existing native UI runner
checks the required journey inventory and captures results/screenshots on PR,
main push and merge-queue runs. Motion is disabled in this deterministic native
journey; release animation/CPU measurements remain separate.

Run `./scripts/check.sh`, `swift run quality-gate hover-fault`, and, with full
Xcode, `swift run native-ui-check`. The local CLT-only machine cannot execute
XCUITest or Instruments; the native journey must pass on the configured Xcode
CI runner before merging. The release fixture still supports animation-enabled
three-repetition measurements with `bash scripts/workspace-journey.sh prepare
--performance`; launch its generated app, keep it foreground and leave the mouse
outside the graph during automatic phases. Keep contaminated idle samples and
label them; do not silently average pointer activity into idle CPU.
