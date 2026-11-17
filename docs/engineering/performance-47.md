# Reproducible performance protocol (#47)

This protocol is recorded before collecting timing results. The first concern
is the prior hover regression: pointer-driven decoration must not republish the
dashboard/conversation or rebuild unchanged connector geometry. Existing
publisher/layer-identity assertions remain hard correctness gates. Variable
CPU, memory and timing results remain informational until repeatability and
owner-agreed budgets support a gate. Profiling and any optimization are separate
reviewable changes; no broad optimization is presumed necessary.

## Evidence audit and accepted warning policy

### R1/R2 completion plan, 17 November 2026

Source baseline: `9ae566d48f18b6304a30b80bfbdb2af2f28a67ee`. The owner authorized
finishing #47 after the #51 fresh review. Before implementation: reproduce R1
with phase settings that disagree with final settings and a changed-then-restored
configuration; reproduce R2 with shorter observation windows at unchanged input
rate. Then require UI protocol v3 per-phase configuration and requested seconds,
with sticky configuration-change detection. Missing legacy fields stay unknown.
Paired requested windows must match; completed elapsed exposure must reach the
requested window and paired elapsed windows must remain within 10%, alongside
the existing rate/configuration qualification. These are evidence-matching
rules, not new CPU performance thresholds. The 5/12/20% warnings stay unchanged.

Planned evidence: red/green audit regressions, producer/decoder wire check,
configuration round-trip/sticky-change checks, existing retained counterexample,
full local gate and required CI. Collect a fresh synthetic v3 baseline after a
clean build, keeping all prior reports and exclusions. Observed results will be
recorded separately; this plan is not a passing result.

The new v3 capture extends the final bounded soak to 120 seconds, with the same
100-card hover workload and one-second resident samples. It is a new baseline,
not a speed comparison with the prior 30-second soak. No absolute RAM ceiling is
invented from it. The existing weak-reference/lifecycle and stale/cancellation
tests remain the deterministic retention/correctness gates.

The owner accepted scoped investigation warnings on 17 November 2026: idle CPU
≤5%, continuous hover ≤12% at 20 chats and ≤20% at 100 chats, on the measured
Mac15,13 configuration. CPU 100% means one logical core. These are not universal
numeric CI gates. See the [prospective criteria, implementation and command](performance-evidence-47-54.md)
and [retained execution evidence](../../evaluations/performance-evidence-2026-11-17/REPORT.md).

The provenance envelope remains schema v2, with build-time source identity and
an executable digest. UI measurement protocol `ui-v3` adds each phase's initial
window geometry, backing scale, maximum refresh, numeric display ID, motion and
Reduce Motion settings, thermal state, requested seconds and a sticky change
flag. The collector samples those conditions throughout the phase and at its
end; the auditor uses the phase's configuration rather than end-of-run settings.
It also preserves delivered iterations, visibility and power stability.

The auditor preserves excluded phases and refuses comparisons across incompatible
environments, configurations, observation windows, work units or input rates.
Legacy `ui-v2` evidence and its historical classifications remain retained, but
missing per-phase configuration/duration is unknown under the current auditor.
It cannot acquire a v3 pass simply by relabelling the protocol. Computation
protocol `computation-v2` is unchanged. Missing or failed measurements are
inconclusive; an exceeded accepted warning requests investigation.

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

Card-local observation alone was insufficient: a foreground release follow-up
still consumed roughly 45% of one core for the 20-card scripted workload. A
separate three-second `sample` of the owned synthetic process found main-thread
SwiftUI layout and `AccessibilityNode.updateFocus`/focus-responder traversal.
That sampled run is diagnostic, not pooled into unprofiled timing baselines.
The final decoration boundary therefore subscribes inside native coordinators
and writes retained layers directly. Hover changes evaluate neither the SwiftUI
destination modifier nor the topology wrapper. Buttons, labels, keyboard access
and selected state remain in SwiftUI; no accessibility feature is disabled.
Tests cover latest-value delivery, colors/geometry, cancellation and rebinding
to a new source without responding to the old source. Dismantling releases the
coordinators' subscriptions and state references.

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
card factory or connector geometry work, and zero SwiftUI hover modifier/topology
evaluations. Native destination updates are bounded to twice per move plus
clearing; native topology updates must occur but at most once per move plus
clearing. Native line-style writes are bounded to the two
affected connections as well. Zero recorded rendering is not accepted as a pass.
This detects accidentally reconnecting the rendered modifier to shared hover
state, which publisher-only tests cannot prove. The existing native UI runner
checks the required journey inventory and captures results/screenshots on PR,
main push and merge-queue runs. Motion is disabled in this deterministic native
journey; release animation/CPU measurements remain separate.

`testPhysicalPointerLoadDoesNotInvalidateGraph` additionally moves XCTest's
actual pointer between a visible card in a mounted 100-card graph and a control
outside the graph. It verifies at least twenty real `.onHover` callbacks, zero
root/layout/SwiftUI decoration updates and bounded nonzero native updates. This
covers AppKit dispatch/hit testing that scripted model transitions alone omit.
It uses Apple's documented [hover operation](https://developer.apple.com/documentation/xcuiautomation/xcuielement/hover()).

Run `./scripts/check.sh`, `swift run quality-gate hover-fault`, and, with full
Xcode, `swift run native-ui-check`. The local CLT-only machine cannot execute
XCUITest or Instruments; the native journey must pass on the configured Xcode
CI runner before merging. The release fixture still supports animation-enabled
three-repetition measurements with `bash scripts/workspace-journey.sh prepare
--performance`; launch its generated app, keep it foreground and leave the mouse
outside the graph during automatic phases. Keep contaminated idle samples and
label them; do not silently average pointer activity into idle CPU.

## Observed v3 completion

[The retained v3 report](../../evaluations/performance-v3-2026-11-17/REPORT.md)
records the clean Release revision, thirteen qualified phases, all three accepted
CPU warning scopes within budget, a 120-second soak and repeated computation
captures. R1/R2 have red/green regressions, producer/decoder coverage and a
retained v3 shortened-window CLI rejection. Historical v2 reports remain intact
and are descriptive under the current auditor. Required CI is tracked in
[PR #71](https://github.com/ivangergo3/jarvis/pull/71).

The direct presentation-latency and longer-session memory gaps remain explicit
in [release qualification #72](https://github.com/ivangergo3/jarvis/issues/72).
This completes the bounded baseline/regression evidence scope; it does not
certify the separate release latency targets or an absolute RAM ceiling.
