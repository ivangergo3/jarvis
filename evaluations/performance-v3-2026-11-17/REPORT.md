# Performance baseline v3 and R1/R2 resolution

Observed 17 November 2026 for [PR #71](https://github.com/ivangergo3/jarvis/pull/71), following the [prospective protocol](../../docs/engineering/performance-47.md). All data are synthetic. This is a baseline and evidence-qualification correction, not a before/after speedup claim.

## Identity and conditions

Source `9cfffeac4e2b702c9c0b1c4e60e6abeb6ab25473`; Release executable SHA-256 `f525a3c5eb5fbaa6108d0a00ec350f1804f666df32213e53c45a2b639d66b529`; tracked tree clean and no untracked app sources. Mac15,13 ARM64, eight logical cores, macOS 27.2.1 (26B131), Swift 6.4.2 (full compiler identity retained in the reports). Provenance schema 2, UI protocol `ui-v3`, computation protocol `computation-v2`.

The owner brought the disposable fixture forward and left it foreground for the recording. All thirteen phases qualified: foreground/visible, stable power and configuration, preserved selection/work, completed requested exposure and at least 80% delivered cadence. Every phase recorded 1500×940 points, backing scale 2, maximum display refresh 60 Hz, display ID 1, animations requested, Reduce Motion off and thermal state 0. No compilation overlapped capture. Other system load and OS caches were uncontrolled. This is scripted hover through the displayed state path; it does not measure physical pointer dispatch. CPU 100% means one logical core; GPU/WindowServer costs are excluded.

Fixture: five projects, 125 chats, 1,002 events per chat, 9,521,801 log bytes. Three warm repetitions per idle/hover workload followed by the prospectively extended 120-second 100-card soak. The fixture was closed after recording; no live app, chats or production workload were modified.

## Observations

| Workload | Mean CPU by repetition | Accepted advisory mean budget | Result |
| --- | --- | --- | --- |
| Idle, 20 chats | 2.89%, 3.02%, 2.92% | ≤5% | Within |
| Hover, 4 chats | 6.64%, 6.38%, 6.82% | None | Descriptive |
| Hover, 20 chats | 7.46%, 7.61%, 7.53% | ≤12% | Within |
| Hover, 100 chats | 11.28%, 11.11%, 11.03% | ≤20% | Within |

Delivered idle cadence was 19.02–19.07 Hz against 20 requested; hover was 53.75–53.79 Hz at 20 chats and 51.68–51.82 Hz at 100 against 60 requested. The audit reports `within-warning-budgets`, with all thirteen phases eligible. No forbidden dashboard/conversation/layout/card rebuilding was recorded.

The soak completed 120.008 seconds: mean CPU 11.21%, main-thread CPU 8.72%, delivered hover 51.84 Hz. Resident memory went from 174,735,360 to 174,342,144 bytes (−384 KiB); 119 samples ranged from 174,243,840 to 174,768,128 bytes. This bounded observation does not prove absence of long-session leaks or establish an absolute RAM ceiling.

Process-main to first native draw was 281.82 ms; to populated body was 379.20 ms. Twenty-two project-switch body samples had median 2.48 ms, p95 5.46 ms, minimum 1.10 ms and maximum 5.94 ms. These are explicitly bounded proxies, not OS-launch or input-to-photon measurements.

Two computation captures each retained seven measured samples after warm-up per series. Their comparison qualified as comparable; no numeric budget applies. Latest repeat, milliseconds:

| Series | Median | Min | Max |
| --- | ---: | ---: | ---: |
| Graph 0 nodes, 200 layouts | 0.0073 | 0.0061 | 0.0158 |
| Graph 1 node, 200 layouts | 0.0365 | 0.0356 | 0.0370 |
| Graph 4 nodes, 200 layouts | 0.0990 | 0.0977 | 0.1004 |
| Graph 20 nodes, 200 layouts | 0.9377 | 0.9159 | 0.9725 |
| Graph 100 nodes, 200 layouts | 7.4059 | 7.0365 | 7.9932 |
| Framing 2,000 records, eight batches | 72.4640 | 71.9895 | 76.2475 |
| Fresh-adapter workspace read | 75.2572 | 73.1516 | 82.2329 |
| Cached unchanged workspace read | 25.4988 | 25.0199 | 35.9727 |

## Findings and regression evidence

- **R1:** phase configuration now comes from the producer at phase start and is sampled throughout/end. A change followed by restoration remains disqualifying. Auditor tests deliberately contradict obsolete final settings, cover mixed per-phase budget scopes, and reject missing display/settings evidence. A producer test varies each setting and round-trips its actual JSON through the auditor DTO. No physical display/motion-setting toggle reproduction was performed.
- **R2:** requested windows must match, actual exposure must complete the request and paired achieved exposure must agree within the predeclared 10%. Regression tests cover shorter declared windows, incomplete requested windows and longer actual exposure at unchanged rate.
- The three initial regression cases failed against the old implementation with six failed expectations; see `red-regressions.txt`. Eleven audit cases plus the producer case passed after correction. The complete local gate passed **170 tests**, formatting, architecture/authority/skill checks and Swift 6 Release build. Native XCUITest runs in the required GitHub check because this machine has CLT only, without full Xcode/Instruments.
- `shortened.json.gz` is a deliberately mutated copy, not a measured run: divide requested/elapsed seconds and loop counters by four, preserve rate and consistent native-update counters. Current CLI returns exit 2: the phases can qualify alone, but pairing with the baseline is **incomparable**, explicitly citing observation-window mismatch. This demonstrates the actual CLI rejects the R2 shape with otherwise valid v3 metadata.
- The retained original #51 quarter-duration counterexample now returns exit 2, **inconclusive / incomparable**, because legacy v2 lacks phase metadata. That legacy rejection alone is not evidence of the duration fix; the v3 probe and nominal positive controls provide it. Historical raw data/classifications remain unchanged.

## Criteria and limits

| #47 criterion | Evidence |
| --- | --- |
| Representative applicable workloads | Synthetic startup/switch proxies, graph 0/1/4/20/100, parser, fresh/cached reads and displayed hover |
| Reproducible identity and spread | Clean revision/digest and per-phase configuration; repeated raw samples; CPU/main-thread/resident counters |
| Prospective budgets | Owner-agreed 5/12/20% CPU warnings unchanged; matching rules declared before capture; machine-variable values informational |
| Correctness and retention | Existing selection/work, cancellation/stale-state and weak-lifecycle gates; 120-second soak |
| Regression and noise policy | Required work-count/pointer/native-layer gates and disposable slowdown probes retained; R1/R2 red/green and actual CLI counterexamples added |
| Privacy boundary | Synthetic fixture only; owned-process counters, no private conversations or production load |

[Release qualification #72](https://github.com/ivangergo3/jarvis/issues/72) explicitly retains the direct presentation-latency and longer memory work previously recorded under #47. REQUIREMENTS.md's initial 1 s / 5 s / 100 ms targets are not certified by these proxy measurements. No new memory ceiling or hard CPU CI threshold has been invented. The accepted baseline/regression scope is ready for review; required CI status is authoritative in PR #71.

## Retained artifacts and reproduction

`ui.json.gz` contains full raw UI observations; `ui-audit.json` all eligibility decisions. `computation.json`, `computation-repeat.json` and `computation-comparison.json` retain both computation runs and comparison. `shortened.json.gz` / `shortened-audit.json` retain the controlled v3 duration counterexample. `legacy-counterexample-audit.json` retains the current auditor's legacy disposition.

Decompress UI/probe JSON into a disposable directory, then run the current native Swift CLI:

```sh
swift run quality-gate performance --report /tmp/ui.json --output /tmp/ui-audit
swift run quality-gate performance --report /tmp/shortened.json --baseline /tmp/ui.json --output /tmp/shortened-audit
```

The second command must return 2 for incomparable evidence. For new collection use `bash scripts/workspace-journey.sh prepare --performance`, build Release, launch the generated app and leave it foreground with the pointer outside the graph. Preserve failures and exclusions; do not pool v2/v3 UI protocols or compare different observation windows as speed results.
