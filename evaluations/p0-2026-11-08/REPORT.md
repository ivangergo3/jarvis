# P0 skill evaluation results

Evaluation date: 8 November 2026. All 19 P0 skills have reviewed behavioural exercise results. They are **evaluated for an initial bounded use**, with source changes and evidence awaiting review in [PR 42](https://github.com/ivangergo3/jarvis/pull/42). No app implementation, team setup, or global installation is included.

## Results

- Baseline: 38 task outputs across 19 skills; 36 passed qualitative review and two needed revision.
- Revisions: task decomposition and work handoffs needed stronger provenance of requirements. Both were clarified narrowly.
- Rechecks: six normal, boundary, and held-out task outputs using the two revised skills passed.
- Composition: two additional tasks combining four skills and three skills respectively passed.

The baseline failures remain in the record; successful reruns do not overwrite them. A pass means the recorded answer met this exercise’s criteria, not guaranteed future reliability.

## What improved

The task-decomposition and handoff outputs imported a specific CSV schema from neighbouring exercises, although their own inputs did not supply it. The skills now require concrete requirements to come from the current brief or explicitly linked accepted artifacts. Missing details must remain gaps or clearly labelled proposals. Separate fresh reruns removed the unsupported schema, and offline onboarding-guide tasks checked that the correction transfers beyond CSV exports.

## Per skill results

| ID | Skill | Baseline normal | Baseline boundary | Follow up | Final evaluation state |
| --- | --- | --- | --- | --- | --- |
| S01a | [mission-briefing](../../skills/mission-briefing/SKILL.md) | pass | pass | No skill change required | Evaluated; in review |
| S01b | [acceptance-criteria](../../skills/acceptance-criteria/SKILL.md) | pass | pass | No skill change required | Evaluated; in review |
| S02a | [option-analysis](../../skills/option-analysis/SKILL.md) | pass | pass | No skill change required | Evaluated; in review |
| S02b | [work-prioritisation](../../skills/work-prioritisation/SKILL.md) | pass | pass | No skill change required | Evaluated; in review |
| S03a | [task-decomposition](../../skills/task-decomposition/SKILL.md) | needs-revision | pass | [3 passing rerun tasks](reruns/S03a/outputs.md) | Evaluated; in review |
| S03b | [dependency-planning](../../skills/dependency-planning/SKILL.md) | pass | pass | No skill change required | Evaluated; in review |
| S03c | [work-handoffs](../../skills/work-handoffs/SKILL.md) | needs-revision | pass | [3 passing rerun tasks](reruns/S03c/outputs.md) | Evaluated; in review |
| S04a | [source-assessment](../../skills/source-assessment/SKILL.md) | pass | pass | No skill change required | Evaluated; in review |
| S04b | [evidence-synthesis](../../skills/evidence-synthesis/SKILL.md) | pass | pass | No skill change required | Evaluated; in review |
| S05a | [project-context-curation](../../skills/project-context-curation/SKILL.md) | pass | pass | No skill change required | Evaluated; in review |
| S05b | [decision-recording](../../skills/decision-recording/SKILL.md) | pass | pass | No skill change required | Evaluated; in review |
| S06a | [delivery-risk-assessment](../../skills/delivery-risk-assessment/SKILL.md) | pass | pass | No skill change required | Evaluated; in review |
| S06b | [verification-planning](../../skills/verification-planning/SKILL.md) | pass | pass | No skill change required | Evaluated; in review |
| S07a | [metric-definition](../../skills/metric-definition/SKILL.md) | pass | pass | No skill change required | Evaluated; in review |
| S07b | [unit-economics-analysis](../../skills/unit-economics-analysis/SKILL.md) | pass | pass | No skill change required | Evaluated; in review |
| S07c | [concept-coaching](../../skills/concept-coaching/SKILL.md) | pass | pass | No skill change required | Evaluated; in review |
| S08a | [customer-segmentation](../../skills/customer-segmentation/SKILL.md) | pass | pass | No skill change required | Evaluated; in review |
| S08b | [customer-problem-validation](../../skills/customer-problem-validation/SKILL.md) | pass | pass | No skill change required | Evaluated; in review |
| S08c | [product-positioning](../../skills/product-positioning/SKILL.md) | pass | pass | No skill change required | Evaluated; in review |

## Evidence and execution method

[Raw prompts](inputs/cases.json), [baseline skill snapshots](snapshots/mission-briefing/SKILL.md), actual [outputs](outputs/S01a.md), [baseline review](reviews/independent-review.md), [rerun review](reviews/rerun-review.md), and [composition review](reviews/composition-review.md) are preserved. [run.json](run.json) records skill hashes, the fixture hash, runtime identity and temporary execution groups. Each baseline output is in outputs/<skill ID>.md.

Evaluators used supplied synthetic artifacts and skill instructions without expected answers. The grouped baseline runs could see neighbouring tasks; the provenance failures show why that context can matter. The two affected skills were rechecked in separate fresh contexts with normal, boundary and held-out assignments. A separate reviewer assessed outputs against their prompts, and the coordinator reviewed the material conclusions. The initial independent review missed the two provenance defects; coordinator challenge prompted their inclusion in the final baseline review.

The exact model identifier was not exposed by the collaboration tool. All runs inherited the session model; this is not evidence of model diversity. Expected-answer references were withheld during execution/review and archived with snapshots afterwards. No statistical reliability estimate or causal improvement over a no-skill baseline is claimed.

## Composition results

C01 combines mission briefing, acceptance criteria, delivery risk assessment, and verification planning for uncertain queued-message recovery. It preserves unknown outcomes, runtime ownership, contract-dependent retries, and the distinction between fixture checks and real server guarantees. See [output](composition/C01.md).

C02 combines metric definition, unit economics analysis, and concept coaching for hypothetical acquisition economics. It correctly derives €100 cash CAC, €30 monthly gross profit per account, and 3.33 conditional full paying months of payback, while retaining missing retention and unvalued founder time. See [output](composition/C02.md).

## Remaining acceptance

The definitions and evaluation evidence are ready for review. P0 tickets remain open in In review while PR 42 is unmerged. Merge and any user-selected technical validation remain separate decisions. Later operational use should add real failures and regression scenarios; these exercises did not verify tool execution, production integrations, or autonomous coordination.
