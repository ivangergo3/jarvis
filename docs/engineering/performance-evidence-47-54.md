# Performance evidence audit and prospective traceability pilot

Baseline: `bf13fa1c3940ab054a4507eecb79d6471b9ef7f0`, 17 November 2026.
Intent: the owner's request to implement the remaining requirements of #47 and
#54. Issue bodies were read before implementation; #54 was last updated
2026-11-17T10:11:39Z. REQUIREMENTS.md remains authoritative (CON-01–05, QA-03/05
and the initial performance targets in section 4). This is the one feature
mapping for this change, not a separate issue/status backlog.

## Bounded feature

Add an offline native Swift performance-evidence audit to the existing quality
CLI. It must refuse to call incomplete, throttled, different-fixture or
different-environment runs comparable. Preserve every measurement and explain
exclusions. Numeric resource targets are investigation warnings, not portable
CI merge gates. Existing deterministic hover gates remain enforced.

## Criteria and checks recorded before coding

| Source/criterion | Existing evidence or remaining task | Planned check | Observed result |
| --- | --- | --- | --- |
| #47 AC1: representative workloads | PR #64 supplies launch/body proxies, switching, parsing, graph scale and hover/soak fixtures. Audit both UI and computation reports. | Typed fixture reports; run existing Release workloads. | Two eight-series computation runs × seven repetitions captured; all thirteen phases qualified in the owner-assisted UI run. Earlier excluded runs are retained (see linked evidence below). |
| #47 AC2: reproducibility/provenance | Stamp source identity at build time; report actual executable digest, build/OS/toolchain/data/window and raw samples. | A stale prepared bundle cannot acquire the current checkout's revision; malformed/missing/dirty identity is unverified. | Clean built identity `bbc38db` and executable digest present. After checkout advanced to `f400c26`, requesting that new revision from the old bundle failed with exit 1. Legacy report classified inconclusive. |
| #47 AC3: agreed budgets | Owner decision below. Keep section-4 launch/input targets distinct from narrower body-evaluation proxies. | Unapproved policy cannot become a timing pass/fail gate. Environment-scoped warnings retain values and policy identity. | Owner accepted 5% / 12% / 20% warning budgets in chat on 17 November 2026; versioned policy and machine-scope test added. |
| #47 AC4: correctness, cancellation, growth | Preserve existing dropped/stale/cancellation tests; qualify report phases by delivered work, selection, visibility and stable power state. Retain soak memory series. | Invalid work counts/selection fail evidence checks; slow input delivery never masquerades as lower CPU. | 164-case gate passed; report regression cases reject changed selection/missing counters. Owner-assisted run preserved all qualified work, within CPU warnings; 30-second soak grew 65,536 resident bytes. Excluded runs retain all counter/cadence/visibility evidence. Longer memory ceiling remains unagreed. |
| #47 AC5: stable regressions/noise | PR #64 already enforces root/card/style and real-pointer contracts with seeded faults. Add report/comparison regression cases. | Reject debug/release, hardware/fixture/window mismatches; keep dirty, occluded, failed and low-rate phases visible but ineligible. | Six audit tests passed at `f400c26`; all nine existing seeded hover stages passed. Exact-head macOS/native CI remains a separate check. |
| #47 AC6: synthetic/private-data boundary | Read explicitly selected bounded report files only; no live chat, network or model calls. | Oversized/malformed reports fail with bounded diagnostics; output contains metrics, not paths/transcripts. | Malformed/oversized and input-overwrite tests passed. Retained JSON contains synthetic numeric data/build metadata; scanned for private paths/credential fields before inclusion. |
| #54 AC1–7 | Accepted guidance/evaluations in PR #66; preserve them. | Inspect scope/source consistency, not install Spec Kit or manufacture another rules system. | Read before coding. |
| #54 AC8: prospective pilot | This report-audit feature is newly authorized after guidance acceptance. Record this mapping before code, discrepancies now, observed evidence afterward, then owner feedback. | Versioned before/after mapping and honest pilot review; distinguish implementer findings from human review usefulness. | Mapping committed before code, findings and execution retained. On 17 November the owner answered “Yes, this level of detail helps” about PR #68's summary. This is workflow feedback, not merge approval. |

## Pre-implementation consistency findings

1. Preparing a fixture currently stamps `git rev-parse HEAD` even if its binary
   was built earlier. A source revision alone can therefore misidentify the
   artifact. Repair build provenance instead of treating preparation as a build.
2. `foregroundThroughout` does not describe occlusion or changing power state.
   Capture those separately; absence in legacy reports is unknown, not success.
3. A slower delivered hover rate produced lower CPU in earlier captures.
   Record actual iterations and target cadence. Qualify the expected workload
   before checking resource warnings; comparison also checks achieved rates.
4. Main-entry-to-body and scheduling lateness do not measure OS launch time or
   input-to-photon latency. Preserve those limits rather than relabel proxies.
5. #54 asks for a prospective pilot and human review feedback. The earlier
   retrospective or an author-written success note cannot satisfy that alone.

These are accepted-criterion gaps repaired within the authorized scope. No
requirement, existing test or threshold is being relaxed.

## Accepted owner-scoped investigation budgets

Owner explicitly accepted these warning budgets in chat on 17 November 2026,
before new measurements. Based on the observed post-fix Mac15,13 baseline:
Release/instrumented build, 1500×940 window, 2× backing, 60 Hz, synthetic 125-chat
fixture, animations enabled, visible/foreground with stable power state.

- Idle 20-chat phase: mean own-process CPU at most 5% of one logical core.
- Continuous scripted hover: mean CPU at most 12% at 20 chats, 20% at 100 chats.
- These are warning/investigation budgets, not universal CI CPU limits.
- Keep the existing 1 s shell / 5 s useful snapshot / <100 ms ordinary-input
  targets in REQUIREMENTS.md. Body-evaluation proxies and cadence are reported
  separately and cannot certify those user-visible targets.
- Do not invent an absolute memory ceiling from the short historical soak.
  Report warm-state resident samples and growth, and retain lifecycle tests;
  agree a ceiling only after comparable longer-run evidence.

Measurement qualification is defined before new collection: a scripted phase
must deliver at least 80% of its requested cadence, preserve its selection,
remain visible/foreground and keep its power state stable. Paired phases must
match configuration and delivered rates within 10%. These rules classify
evidence; they are not frame-time or product-performance pass thresholds.

## Pilot outcome

The mapping above was committed in `b5a2fe2` before implementation in `bbc38db`.
The audit's unknown-workload check was tightened in `f400c26`. Upstream Spec Kit
quickstart/analyze/converge references from the accepted #54 note were rechecked
as text only; no upstream tools, hooks or installers were run.

Observed checks so far:

- `scripts/check.sh` at `bbc38db`: 164 ordinary test cases passed, including six
  performance-audit cases; formatter, workspace/native architecture negative
  probes, skill discovery, eight authority scenarios/five isolation checks,
  and Swift 6 Release build passed. Local CLT needs the documented Swift Testing
  plugin path. Full Xcode/native XCUITest is unavailable locally; PR CI runs it.
- All nine existing hover-fault stages passed: dashboard forwarding, card
  fanout and all-line style writes each gave good/assertion failure/restored
  good. These test forbidden work, rather than machine-dependent CPU limits.
- All six audit cases passed again after `f400c26`. They exercise unknown and
  changed workloads, lost visibility/selection/work, dirty/legacy/failed
  provenance, invalid measurements, changed computation units, raw-sample
  statistics, oversized/malformed input and stale-success invalidation.
- The full local `scripts/check.sh` gate passed again at `9481bd6`: 164 tests,
  formatter, architecture probes, skill discovery, authority checks and Release
  build. Final validation also rejects invalid UI geometry and duplicate phases.
- Fresh eight-series computation capture from the clean `bbc38db` bundle has
  valid identity. The audit reports it without an applicable CPU budget, as
  intended. The older UI recording is inconclusive because its provenance and
  workload-delivery metadata are incomplete, rather than being upgraded to a
  clean v2 result.
- The owner-assisted foreground run qualified all thirteen phases: idle
  2.33–2.55%, hover at 20 chats 8.56–8.94%, hover at 100 chats 12.60–12.64%,
  within the accepted warnings. The [retained execution report](../../evaluations/performance-evidence-2026-11-17/REPORT.md)
  includes raw compressed UI runs, computation samples, audit outputs,
  exclusions and remaining direct-latency/longer-memory evidence gaps.

Author assessment: preflight exposed three consequential omitted contracts
(artifact identity, visibility/power state and achieved workload). Implementation
review also exposed stale output after a failed audit, missing work-unit checks
and unknown workload acceptance; regressions now cover these. Selection is
sampled throughout the phase. This is evidence that the consistency step found
work; it does not demonstrate human review usefulness. The one mapping and one
outcome note were sufficient. No per-function paperwork or duplicated status
backlog was added.

On 17 November 2026, the owner reviewed the question about the concrete PR #68
summary linking requirements, problems found, tests and measured results, and
answered **“Yes, this level of detail helps.”** This is actual feedback that the
summary aids review; it is not inferred from passing checks or merge approval.
The owner did not enumerate specific links opened, so no link-use claim is made.
No reduction in detail was requested. The prospective pilot and its owner
feedback are now recorded; #54 can be assessed for closure when this work lands.

## Running the audit

```sh
swift run quality-gate performance --report /path/to/raw.json --output test-results/performance
swift run quality-gate performance --report /path/to/candidate.json --baseline /path/to/baseline.json --output test-results/performance
```

The default policy is `Tools/performance-budgets.json`; an explicit `--policy`
selects a different policy without changing repository acceptance. Exit 1 means
invalid evidence/arguments; exit 2 means inconclusive or incomparable evidence.
An exceeded warning is advisory (exit 0, `investigate`), never a CPU CI gate.
The JSON retains every listed phase and exclusion reason. Eligibility applies
only to listed workloads: a partial report cannot certify all of #47. Inputs
are bounded at 8 MiB; output cannot overwrite an input, and a failed run cannot
leave an earlier successful output in place.
