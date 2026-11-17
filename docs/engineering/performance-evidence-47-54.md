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
| #47 AC1: representative workloads | PR #64 supplies launch/body proxies, switching, parsing, graph scale and hover/soak fixtures. Audit both UI and computation reports. | Typed fixture reports; run existing Release workloads. | Not run for this feature. |
| #47 AC2: reproducibility/provenance | Stamp source identity at build time; report actual executable digest, build/OS/toolchain/data/window and raw samples. | A stale prepared bundle cannot acquire the current checkout's revision; malformed/missing/dirty identity is unverified. | Not run. |
| #47 AC3: agreed budgets | Owner decision below. Keep section-4 launch/input targets distinct from narrower body-evaluation proxies. | Unapproved policy cannot become a timing pass/fail gate. Environment-scoped warnings retain values and policy identity. | Decision pending. |
| #47 AC4: correctness, cancellation, growth | Preserve existing dropped/stale/cancellation tests; qualify report phases by delivered work, selection, visibility and stable power state. Retain soak memory series. | Invalid work counts/selection fail evidence checks; slow input delivery never masquerades as lower CPU. | Not run. |
| #47 AC5: stable regressions/noise | PR #64 already enforces root/card/style and real-pointer contracts with seeded faults. Add report/comparison regression cases. | Reject debug/release, hardware/fixture/window mismatches; keep dirty, occluded, failed and low-rate phases visible but ineligible. | Not run. |
| #47 AC6: synthetic/private-data boundary | Read explicitly selected bounded report files only; no live chat, network or model calls. | Oversized/malformed reports fail with bounded diagnostics; output contains metrics, not paths/transcripts. | Not run. |
| #54 AC1–7 | Accepted guidance/evaluations in PR #66; preserve them. | Inspect scope/source consistency, not install Spec Kit or manufacture another rules system. | Read before coding. |
| #54 AC8: prospective pilot | This report-audit feature is newly authorized after guidance acceptance. Record this mapping before code, discrepancies now, observed evidence afterward, then owner feedback. | Versioned before/after mapping and honest pilot review; distinguish implementer findings from human review usefulness. | Owner feedback remains pending until a concrete result is reviewed. |

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

Implementation, execution, evidence links and owner feedback will be recorded
here after they exist. No planned command in the table is a passing result.
