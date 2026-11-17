# Fresh-reviewer pilot (#51 AC8)

17 November 2026. PR #68 was approved by the owner and merged as `45f5f2b`
before this review, following the owner's requested ordering. This is a real
post-merge fresh-review pilot, not a claim that review prevented these defects
from landing. [Supplied context](HANDOFF.md) records the immutable base/head and
the rationale/history that was withheld. The reviewer made no source edits.

## Actual reviewer result

The fresh reviewer returned two P2 findings on candidate `8818c8f`:

1. **End-of-run settings can mislabel earlier measurements.**
   [PerformanceSession.swift:296](https://github.com/ivangergo3/jarvis/blob/8818c8f970e149f053a001b5bdddcc27586b87a4/Sources/Jarvis/Composition/PerformanceSession.swift#L296)
   records motion after all phases; lines 309–312 similarly read final geometry,
   backing scale and refresh rate. The auditor applies those final settings to
   every phase. Run earlier phases with another window/display configuration or
   Reduce Motion setting, then restore the accepted settings between phases:
   earlier measurements can qualify under the final settings. Record and
   validate configuration per phase, including changes during measurement.
   This is source-supported; no native setting-change scenario was executed.

2. **Paired UI comparisons ignore measurement duration.**
   [PerformanceAudit.swift:332](https://github.com/ivangergo3/jarvis/blob/8818c8f970e149f053a001b5bdddcc27586b87a4/Tools/QualitySupport/PerformanceAudit.swift#L332)
   compares workload identity and achieved cadence without comparing duration.
   The reviewer quartered each owner-foreground phase duration and scaled
   loop/work counters to retain cadence and work invariants. Approximately
   1-second idle, 2-second hover and 7.5-second soak were accepted as
   `within-warning-budgets; comparable` against the original 4/8/30-second run.
   Materially different observation and soak windows can count as matched
   evidence. This was reproduced by compiling the candidate's actual audit
   source, not by reimplementing the classifier.

The reviewer explicitly found no evidence that the checked-in owner capture
was contaminated. The second input is a synthetic counterexample, not a new
performance measurement or a claim about actual CPU savings.

## Checks and limits reported by the reviewer

- Read the exact executable diff, callers/error paths, scripts, policy/CLI,
  tests and raw numeric evidence; confirmed reviewed source matches candidate.
- Excluded author explanations and the specified PR/report rationale.
- The source-compiled offline harness reproduced owner-foreground qualification,
  computation comparability and rejection of both excluded UI captures.
- Inspected supplied evidence of 164 tests, nine fault stages and eight passing
  native journeys on the unchanged retry. The first native failure's cause was
  not proved by the retry's success.
- Focused SwiftPM tests were blocked by local sandbox/cache restrictions.
  No new CPU profiling, full native suite or live integration ran. These are
  limits, not passing results.

## Coordinator validation and dispositions

| Finding | Assessment | Disposition |
| --- | --- | --- |
| R1: final settings applied to earlier phases | Valid source-supported P2. Per-phase configuration is absent; the audit uses final report configuration. Native reproduction not performed. | Keep open under #47. Capture start/throughout configuration and use it for phase qualification/comparison; add a changing-configuration regression. |
| R2: changed phase duration accepted | Valid, reproduced through the ordinary `quality-gate performance` CLI as well as the reviewer's source-compiled harness. | Keep open under #47. Record requested duration/work exposure and reject incompatible windows without turning noisy CPU timings into CI gates. |

This pilot reports findings; it does not implement those performance changes or
silently mark #47 complete. Owner acceptance remains separate from reviewer
agreement. No requirement, assertion, threshold, runtime or permission changed.

The [counterexample input](quarter-duration-input.json.gz) and
[actual observed output](quarter-duration-observed.json) retain R2. From a
checkout of the reviewed source (all paths below are disposable synthetic data):

```sh
mkdir -p /tmp/jarvis-review-51-repro
gzip -dc evaluations/performance-evidence-2026-11-17/ui-owner-foreground.json.gz > /tmp/jarvis-review-51-repro/owner.json
gzip -dc evaluations/fresh-review-51-2026-11-17/quarter-duration-input.json.gz > /tmp/jarvis-review-51-repro/quarter.json
swift run quality-gate performance --report /tmp/jarvis-review-51-repro/quarter.json --baseline /tmp/jarvis-review-51-repro/owner.json --output /tmp/jarvis-review-51-repro/output
```

Observed: `within-warning-budgets; comparable` (exit 0). That output reproduces
the defect; it is **not** the expected correct classification. Exact example
durations were 1.008874 / 2.002831 / 7.503161 seconds. The original capture and
numeric resource values remain retained; no original evidence was overwritten.

## Delivery observations

Two actionable evidence-qualification gaps were found after acceptance in this
one post-merge review on 17 November. This demonstrates a useful result for the
pilot, not a general defect-detection rate or productivity improvement. Reviewer
time, comparative delivery time, provider tokens/cost and owner review effort
for these findings were not measured. The earlier #54 feedback about summary
detail is not relabelled as acceptance of these new findings.

AC1–7's setup was accepted in PR #67. AC8's fresh-review exercise now has actual
findings, validation and dispositions. Claude remains unavailable on PATH;
runtime verification stays deferred under the already accepted conditional AC3,
without installation or a claimed Claude pass. The accepted #51 pilot scope is
complete; remaining performance work is tracked by #47.
