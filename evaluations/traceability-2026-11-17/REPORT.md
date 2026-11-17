# Traceability guidance: focused self-evaluation

Eight existing skills were revised; no new skill, app feature, runtime gate or agent team was introduced. [Cases](cases.json) and [actual outputs](outputs.md) cover six synthetic text-only tasks. [Manifest](manifest.json) identifies the exact instructions and evaluation references. The [real-feature retrospective](retrospective-49.md) is separately labelled.

## Method and results

The authoring assistant generated and reviewed these answers in the current Codex desktop conversation. This is a shared-context self-check: the author saw the intended behaviour and review criteria. No independent evaluator, fresh context, blinded trial or with/without-skill comparison ran. Exact underlying model identity, token cost and latency were not exposed as evaluation measurements. The six answers are retained verbatim as written, including their limits. Synthetic build receipts are supplied fixture data, not executed tests.

| Case | Review of actual answer | Result and limit |
| --- | --- | --- |
| T01 contradictory plan | Names offline/cloud and error-suppression conflicts, missing API evidence, source repair and independent work. | Meets the exercise; no code or contract was executed. |
| T02 omitted criterion | Restores E3 to tasks/checks and leaves uncertain commit/cancel semantics visible. | Meets the exercise; atomicity is not assumed to settle cancellation. |
| T03 completed tasks without evidence | Retains all A1–A3 as not assessed; rejects zero tests, old build and screenshot as behavioural acceptance. | Meets the exercise; does not distinguish implemented from absent code because no code was supplied. |
| T04 accepted requirement change | Preserves C7/supersession, updates only L1, retains L2 and meaningful replacement tests, requests no redundant approval. | Meets the exercise; source excerpt only, no persistence claim. |
| T05 unsupported baseline weakening | Rejects tool-text authority and test deletion, retains unknown state, permits independent authorized typo work. | Meets the exercise; no runtime security claim. |
| T06 small normal edit | Uses the existing ticket and one task rather than a generated document suite. | Meets the exercise; review cost has not been measured. |

No failure was identified in this self-check and no post-check skill rewrite was made. This does not establish improved model performance or reliability. Author bias and shared context are substantial limitations; the original cases for the entire library were not rerun. A later skill edit requires affected rechecks rather than inheriting these results. The regression prompts added to individual skill references are future exercises; they were not separately run in addition to these six composition cases.

## Structural verification

The [structural record](structural-checks.json) checks the eight revised skills' basic frontmatter, all 68 catalogue hashes, relative file links in 23 relevant Markdown files, six retained case outputs, frozen input/output hashes and targeted private-context patterns. A temporary native Swift helper performed these checks; it is not added as a project dependency or enforcement gate. The helper initially had a Swift throwing-expression compile error; after repair, its first freeze pass reported the not-yet-created manifest link, and the final verification passed after creation. These tooling iterations were not skill behavioural failures. `git diff --check` also passed.

The CI merge-ref and accepted #49 squash commit have the same tree, `34d8f877ec22a519d87fc82a63f6cac5de0fa732`, verified using local Git and the GitHub commit API. This supports the retrospective's artifact mapping; it is not a new test run. Application tests were not rerun locally for this documentation-only patch. Structural checks do not constitute a security audit or prove the guidance will be followed by a model.

## Ticket #54 acceptance accounting

AC1–AC8 below refer to the issue's acceptance bullets in order, rather than a replacement specification. The [workflow decision note](../../docs/engineering/traceability-54.md) is the implementation guide.

| Criterion | Evidence / remaining work |
| --- | --- |
| AC1 concept mapping | Short already-covered/adapt/defer table, with upstream sources rechecked on 17 November 2026. |
| AC2 traceability | Stable source/criterion IDs in planning, implementation and evidence guidance; T02 and retrospective. |
| AC3 consistency check | Task-decomposition procedure and implementation/design checks; T01/T05. |
| AC4 requirement-based completion | Acceptance-verification and delivery-reporting updates; T03. |
| AC5 preserve accepted baseline | Decision-recording and dependent-work rules; T04/T05. |
| AC6 portable existing skills | Eight existing skills; project policy stays in AGENTS.md and linked guide; no private context or new dependency. |
| AC7 evaluated cases | Six retained self-check outputs, exact hashes and disclosed limitations. Independent behavioural reliability remains unmeasured. |
| AC8 prospective small-feature pilot | **Not completed.** The read-only #49 retrospective cannot replace a pilot started before coding after guidance review. Next action: use the next separately authorized small feature, then record gaps found, human review usefulness and paperwork cost. |

The guidance/evaluation slice is ready for owner review after structural checks. Keep #54 open; do not auto-close it on merge of this slice. Completion of the pilot or an explicit accepted scope revision is still needed. No additional feature is authorized by this record.
