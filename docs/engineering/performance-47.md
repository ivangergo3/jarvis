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
- Three separately identified fixture app launches. Measure process-main entry
  to first native draw and first populated workspace body evaluation. These exclude work
  before main/LaunchServices and are not cold-disk launch claims.
  Project-switch timings stop at the target SwiftUI body evaluation, not GPU
  presentation. The initial draw-callback readiness protocol failed on a real
  layer-backed update (revision d9f36a6); that failed run is retained and excluded
  from successful baselines. The revised boundary is explicit, not a fabricated
  substitute for an unobserved draw.
- Exercise the real displayed hover state at a fixed cadence, then a bounded
  soak. Record root/conversation/card/topology work and connector rebuilds,
  own-process user+system CPU, resident memory, and main-actor heartbeat delay.
  Heartbeat delay is scheduling evidence, not input-to-photon latency.
- Programmatic hover state is the same path used by `.onHover`; it does not
  include physical pointer/event-dispatch/hit-testing overhead. A manual cursor
  recording is a separately labelled supplement, never silently pooled with it.

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
