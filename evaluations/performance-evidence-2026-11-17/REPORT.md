# Performance evidence audit: retained execution

17 November 2026. Synthetic data only; no real chat records, pointer coordinates,
system-wide process samples or credentials are included. This is evidence for
the bounded #47/#54 implementation described in the
[prospective mapping](../../docs/engineering/performance-evidence-47-54.md).

## Versions and environment

- App built from clean `bbc38db1c3920c456ab0ebb3acd7bd5dd418be81`; this is the
  bundle's build-time identity, not a claim that every later checkout has that
  revision. Each raw report includes its actual signed executable SHA-256.
- Mac15,13, ARM64, eight logical processors; macOS 27.2.1 (26B131), Apple Swift
  6.4.2 (swiftlang-6.4.2.1.9 clang-2100.4.1.1), Release. UI is instrumented.
- Five projects, 125 chats, 1,002 events per chat, 9,521,801 log bytes. UI window
  1500×940 points, 2× backing, 60 Hz, requested animations enabled.
- Explicit warm-up followed by seven repetitions per computation series. UI
  uses three warm repetitions of idle and 4/20/100-card hover, then a 30-second
  soak. Fresh process does not mean cold OS caches. Ordinary competing system
  load is uncontrolled. No Instruments or local XCUITest was available with
  Command Line Tools alone.

## Observations and exclusions

The initial computation run and repeat are structurally comparable (same built
artifact, fixture, environment, work units, checksums and repetition counts).
There was no code change between them; **no speedup is claimed**. The audit
recomputes statistics from samples and reports without an applicable CPU budget.

| Computation | Work per sample | Median ms | Min–max ms |
| --- | --- | --- | --- |
| Graph 0 | 200 layouts | 0.0076 | 0.0067–0.0190 |
| Graph 1 | 200 layouts | 0.0360 | 0.0320–0.0393 |
| Graph 4 | 200 layouts | 0.0943 | 0.0934–0.1071 |
| Graph 20 | 200 layouts | 0.8490 | 0.8432–0.8585 |
| Graph 100 | 200 layouts | 7.7749 | 7.3744–7.7898 |
| Framing 2,000 records | 8 batches | 77.2611 | 77.0360–77.8460 |
| Fresh workspace adapter | 1 read | 72.8591 | 72.0525–76.2027 |
| Warm workspace adapter | 1 read | 25.5841 | 25.1899–31.1690 |

`ui-confounded.json.gz` overlapped local compilation/fault checks and is excluded
from performance conclusions for that known reason. It also failed the
visibility qualification and later cadence qualification. It is retained rather
than discarded.

`ui-no-build-overlap.json.gz` was repeated after compilation finished. All
phases reported foreground, stable power and preserved selection, but macOS
reported occlusion throughout. Later phases also dropped cadence and some
included broad-work counters. All thirteen phases remain visible in
`ui-audit.json`, ineligible for a budget pass or before/after CPU comparison.
First-repetition hover CPU was 9.46% at 20 cards and 15.11% at 100 cards;
**these are excluded observations, not validated budget results**.

That second run measured main-entry to first draw at 226.0 ms, populated body at
322.4 ms, and project-switch body evaluation at 3.06 ms median / 10.00 ms p95 /
11.76 ms maximum. These are descriptive proxies in an excluded run, not proof of
OS launch or input-to-photon targets. The final 30-second soak had unchanged
resident start/end at 222,724,096 bytes; excluded cadence/visibility means this
does not establish a leak ceiling or representative foreground resource usage.

The requested checkout revision `f400c26` was deliberately supplied to the older
`bbc38db` bundle. It exited 1 with “Requested revision does not match the built
artifact”, demonstrating that fixture preparation no longer relabels an old
binary as current code. No source stamp or digest is an attestation against a
malicious builder.

## Reproduce

```sh
./build.sh
bash scripts/workspace-journey.sh prepare --performance
# Launch that disposable bundle through the native UI and keep it visible.
# For computation, invoke its executable with --performance-baseline and
# --revision=<the full JarvisBuildRevision in its Info.plist>.
swift run quality-gate performance --report /path/to/report.json --output test-results/performance
swift run quality-gate performance --report evaluations/performance-evidence-2026-11-17/computation-repeat.json --baseline evaluations/performance-evidence-2026-11-17/computation.json --output test-results/performance-comparison
gzip -dc evaluations/performance-evidence-2026-11-17/ui-no-build-overlap.json.gz > /tmp/jarvis-performance-ui.json
```

CPU warnings are the owner's accepted 5% idle / 12% hover at 20 / 20% hover at
100 on this Mac configuration, with 100% meaning one logical core. They are
investigation warnings, not timing CI gates. Deterministic work/lifecycle gates
remain required. `hover-fault.json` retains all nine good/fault/restored stages.

## Owner-assisted qualifying foreground run

The owner brought the reopened fixture to the front and left the pointer outside
the graph. `ui-owner-foreground.json.gz` is retained alongside the earlier
excluded runs. All thirteen phases preserved foreground/visible state, power,
selection and delivered work, with no broad-work counter increments. The audit
classified this run `within-warning-budgets`.

| Workload | Three mean CPU observations (% of one core) | Accepted warning |
| --- | --- | --- |
| Idle, 20 cards | 2.55, 2.36, 2.33 | 5% |
| Hover, 20 cards | 8.89, 8.56, 8.94 | 12% |
| Hover, 100 cards | 12.60, 12.64, 12.62 | 20% |

Scripted hover delivered 53.49–53.74 updates/sec at 20 cards and 51.35–51.54 at
100 cards against 60 requested, above the prespecified 80% qualification.
Idle delivered 19.08–19.14 ticks/sec against 20 requested. Reported CPU is
own-process CPU; this does not include WindowServer/GPU energy or physical mouse
dispatch cost. There is no before/after performance claim against excluded runs.

The 30.01-second soak delivered 51.41 updates/sec and used 12.51% CPU. Resident
start/end grew by 65,536 bytes (193,888,256 → 193,953,792); raw samples are
retained. This short observation does not establish a long-run leak ceiling.
Main-entry to first draw was 230.2 ms, populated body 294.5 ms, project-switch
body evaluation 3.04 ms median / 6.99 ms p95 / 7.11 ms max. Reopening remembered
the 100-chat project; these remain body/draw proxies with uncontrolled OS caches,
not full OS-launch or input-to-photon certification.

Remaining evidence gaps: longer comparable memory measurements before agreeing
a ceiling and direct OS-launch/input-to-photon profiling. They are not silently
marked complete by the existence of an auditor or passing unit tests. #54 owner
review feedback also remains separate from this implementer's report.
