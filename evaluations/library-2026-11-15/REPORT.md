# Full skill-library evaluation

15 November 2026. The public library now contains **68 focused skills**: 19 P0, 25 P1 and 24 P2. The existing 19 later-stage family tickets group the 49 new definitions. One agent can combine multiple skills; no lasting team, provider topology, global installation or app implementation was configured.

## Results

| Exercise set | Answers | Pass | Needs revision at that stage |
| --- | --- | --- | --- |
| [engineering](reviews/engineering/review.md) | 26 | 26 | 0 |
| [commercial](reviews/commercial/review.md) | 36 | 35 | 1 |
| [operations](reviews/operations/review.md) | 36 | 36 | 0 |
| [p0-safety](reviews/p0-safety/review.md) | 19 | 18 | 1 |
| [reruns](reviews/reruns/review.md) | 9 | 8 | 1 |
| [second-rerun](reviews/second-rerun/review.md) | 6 | 5 | 1 |
| [third-rerun](reviews/third-rerun/review.md) | 3 | 3 | 0 |
| [composition](reviews/composition/review.md) | 3 | 3 | 0 |

The 138 recorded answers include four failed answers across two source-fidelity issues and their repeated rechecks. The latest normal, boundary and held-out rechecks for every revised skill passed. The failed answers remain in the archive. Results are reviewed observations on a small synthetic set, not a reliability percentage or a safety certificate. A later passing recheck does not erase an earlier failure.

### Demonstrated corrections

- **Feedback synthesis:** the baseline counted two participants as losing the *latest* handout, although only one supplied that qualifier. Two successive corrections still failed the original task while passing their held-out cases. The third procedure change requires a source-to-claim mapping before any headline, then checks the entire counted statement against each contributing source. All versions and failed rechecks are preserved.
- **Customer segmentation:** a P0 output called an unspecified sample a convenience sample in its limitations. The revised skill separates known sample size, recruitment method and representativeness, including in caveats.
- **Prospect qualification:** a passing output used an ambiguous status for missing evidence. The clarified skill distinguishes incomplete qualification from a confirmed disqualifier.
- **Conversion journey review:** a passing output could imply directly observed behaviour from a supplied description. The clarified skill requires source-specific attribution. Both clarity improvements received normal, boundary and held-out rechecks.

## What actually ran

Fresh evaluator runs received only isolated skill text, prompts and minimal synthetic inputs. Expected answers and reviewer criteria were withheld, including linked evaluation references in the isolated packs. Those references exist in the shipped folders and archive snapshots; their intentional omission from a blind evaluation pack is not a packaging defect. Baseline runs covered 13 engineering, 18 commercial and 18 operations skills; a fourth run exercised all 19 updated P0 skills. Cases within each run shared context, so they are not independent single-task sessions. Independent reviewers assessed the resulting artifacts; the author inspected high-risk samples and the failures as well.

The implementation exercise created a disposable `parse_limit` patch and four unittest methods covering 26 subtest inputs. The automation exercise created six `normalize_tag` tests. Both suites passed and a separate reviewer reran them successfully. These are tiny synthetic exercises, not tests of the application. The remaining exercises produced actual drafts, analyses, plans or scoped decisions; they did not exercise real accounts or runtime enforcement.

Three composition tasks combine engineering design/testing/review, research/qualification/outreach/claims review, and campaign measurement/economics/experiment design. They demonstrate useful handoffs and a combined answer without prescribing separate agents for each skill. Review remains scoped to those exact tasks.

## Versioned evidence

- [New-skill tasks and baseline hashes](inputs/cases.json), [separate reviewer criteria](inputs/reviewer-criteria.json).
- [P0 current-version tasks](inputs/p0-safety.json), [first rechecks](inputs/reruns.json), [second rechecks](inputs/second-rerun.json), [third recheck](inputs/third-rerun.json), [composition tasks](inputs/composition.json).
- [Run metadata, counts, current hashes and limitations](run.json).
- [Structural validator results](structural-validation.json) and [publication redaction note](redactions.json).
- Actual outputs and independent verdicts are in the `outputs/` and `reviews/` directories below, keyed by exercise pack. Baseline snapshots are in `snapshots/`; the changed versions are in `reruns/`, `second-rerun/` and `third-rerun/`.

The exact model identifier was not exposed by the collaboration tools; all runs inherited the session model. There was no cross-provider comparison, no no-skill baseline and no live integration test. Synthetic refusal/decision examples do not prove that a runtime blocks unauthorized actions. Local use still requires appropriate runtime permissions, data handling and limits.

All 68 public skill folders passed the Skill Creator structural validator. Link, manifest, portability and publication checks are recorded separately in [publication-checks.json](publication-checks.json). Structural validity does not prove behavioural quality. The [historical P0 evaluation](../p0-2026-11-08/REPORT.md) remains evidence for its original versions; current P0 exercises test changed safety wording without claiming a full historical-suite rerun.

## Per-skill review index

“Pass” below means the listed bounded exercise was reviewed as passing. All definitions remain **In review**, pending owner acceptance and merge. No ticket is automatically closed.

| ID | Skill | Baseline/current P0 exercise | Later evidence |
| --- | --- | --- | --- |
| S01a | [mission-briefing](../../skills/mission-briefing/SKILL.md) | [Targeted: pass](reviews/p0-safety/review.json) | No revision needed in this sample |
| S01b | [acceptance-criteria](../../skills/acceptance-criteria/SKILL.md) | [Targeted: pass](reviews/p0-safety/review.json) | No revision needed in this sample |
| S02a | [option-analysis](../../skills/option-analysis/SKILL.md) | [Targeted: pass](reviews/p0-safety/review.json) | No revision needed in this sample |
| S02b | [work-prioritisation](../../skills/work-prioritisation/SKILL.md) | [Targeted: pass](reviews/p0-safety/review.json) | No revision needed in this sample |
| S03a | [task-decomposition](../../skills/task-decomposition/SKILL.md) | [Targeted: pass](reviews/p0-safety/review.json) | No revision needed in this sample |
| S03b | [dependency-planning](../../skills/dependency-planning/SKILL.md) | [Targeted: pass](reviews/p0-safety/review.json) | No revision needed in this sample |
| S03c | [work-handoffs](../../skills/work-handoffs/SKILL.md) | [Targeted: pass](reviews/p0-safety/review.json) | No revision needed in this sample |
| S04a | [source-assessment](../../skills/source-assessment/SKILL.md) | [Targeted: pass](reviews/p0-safety/review.json) | No revision needed in this sample |
| S04b | [evidence-synthesis](../../skills/evidence-synthesis/SKILL.md) | [Targeted: pass](reviews/p0-safety/review.json) | No revision needed in this sample |
| S05a | [project-context-curation](../../skills/project-context-curation/SKILL.md) | [Targeted: pass](reviews/p0-safety/review.json) | No revision needed in this sample |
| S05b | [decision-recording](../../skills/decision-recording/SKILL.md) | [Targeted: pass](reviews/p0-safety/review.json) | No revision needed in this sample |
| S06a | [delivery-risk-assessment](../../skills/delivery-risk-assessment/SKILL.md) | [Targeted: pass](reviews/p0-safety/review.json) | No revision needed in this sample |
| S06b | [verification-planning](../../skills/verification-planning/SKILL.md) | [Targeted: pass](reviews/p0-safety/review.json) | No revision needed in this sample |
| S07a | [metric-definition](../../skills/metric-definition/SKILL.md) | [Targeted: pass](reviews/p0-safety/review.json) | No revision needed in this sample |
| S07b | [unit-economics-analysis](../../skills/unit-economics-analysis/SKILL.md) | [Targeted: pass](reviews/p0-safety/review.json) | No revision needed in this sample |
| S07c | [concept-coaching](../../skills/concept-coaching/SKILL.md) | [Targeted: pass](reviews/p0-safety/review.json) | No revision needed in this sample |
| S08a | [customer-segmentation](../../skills/customer-segmentation/SKILL.md) | [Targeted: needs-revision](reviews/p0-safety/review.json) | [Second recheck: pass/pass/pass](reviews/second-rerun/review.json) |
| S08b | [customer-problem-validation](../../skills/customer-problem-validation/SKILL.md) | [Targeted: pass](reviews/p0-safety/review.json) | No revision needed in this sample |
| S08c | [product-positioning](../../skills/product-positioning/SKILL.md) | [Targeted: pass](reviews/p0-safety/review.json) | No revision needed in this sample |
| S09a | [technical-design](../../skills/technical-design/SKILL.md) | [pass / pass](reviews/engineering/review.json) | No revision needed in this sample |
| S09b | [architecture-assessment](../../skills/architecture-assessment/SKILL.md) | [pass / pass](reviews/engineering/review.json) | No revision needed in this sample |
| S10a | [software-implementation](../../skills/software-implementation/SKILL.md) | [pass / pass](reviews/engineering/review.json) | No revision needed in this sample |
| S10b | [defect-diagnosis](../../skills/defect-diagnosis/SKILL.md) | [pass / pass](reviews/engineering/review.json) | No revision needed in this sample |
| S11a | [test-design](../../skills/test-design/SKILL.md) | [pass / pass](reviews/engineering/review.json) | No revision needed in this sample |
| S11b | [test-automation](../../skills/test-automation/SKILL.md) | [pass / pass](reviews/engineering/review.json) | No revision needed in this sample |
| S11c | [test-maintenance](../../skills/test-maintenance/SKILL.md) | [pass / pass](reviews/engineering/review.json) | No revision needed in this sample |
| S12 | [code-review](../../skills/code-review/SKILL.md) | [pass / pass](reviews/engineering/review.json) | No revision needed in this sample |
| S13a | [exploratory-testing](../../skills/exploratory-testing/SKILL.md) | [pass / pass](reviews/engineering/review.json) | No revision needed in this sample |
| S13b | [defect-reproduction](../../skills/defect-reproduction/SKILL.md) | [pass / pass](reviews/engineering/review.json) | No revision needed in this sample |
| S13c | [acceptance-verification](../../skills/acceptance-verification/SKILL.md) | [pass / pass](reviews/engineering/review.json) | No revision needed in this sample |
| S14a | [pull-request-preparation](../../skills/pull-request-preparation/SKILL.md) | [pass / pass](reviews/engineering/review.json) | No revision needed in this sample |
| S14b | [delivery-reporting](../../skills/delivery-reporting/SKILL.md) | [pass / pass](reviews/engineering/review.json) | No revision needed in this sample |
| S15a | [offer-design](../../skills/offer-design/SKILL.md) | [pass / pass](reviews/commercial/review.json) | No revision needed in this sample |
| S15b | [landing-page-copy](../../skills/landing-page-copy/SKILL.md) | [pass / pass](reviews/commercial/review.json) | No revision needed in this sample |
| S15c | [lifecycle-email-writing](../../skills/lifecycle-email-writing/SKILL.md) | [pass / pass](reviews/commercial/review.json) | No revision needed in this sample |
| S16a | [personal-brand-strategy](../../skills/personal-brand-strategy/SKILL.md) | [pass / pass](reviews/commercial/review.json) | No revision needed in this sample |
| S16b | [content-ideation](../../skills/content-ideation/SKILL.md) | [pass / pass](reviews/commercial/review.json) | No revision needed in this sample |
| S16c | [personal-content-writing](../../skills/personal-content-writing/SKILL.md) | [pass / pass](reviews/commercial/review.json) | No revision needed in this sample |
| S17a | [account-research](../../skills/account-research/SKILL.md) | [pass / pass](reviews/commercial/review.json) | No revision needed in this sample |
| S17b | [prospect-qualification](../../skills/prospect-qualification/SKILL.md) | [pass / pass](reviews/commercial/review.json) | [First recheck: pass/pass/pass](reviews/reruns/review.json) |
| S18a | [cold-outreach-writing](../../skills/cold-outreach-writing/SKILL.md) | [pass / pass](reviews/commercial/review.json) | No revision needed in this sample |
| S18b | [follow-up-writing](../../skills/follow-up-writing/SKILL.md) | [pass / pass](reviews/commercial/review.json) | No revision needed in this sample |
| S19a | [marketing-claims-review](../../skills/marketing-claims-review/SKILL.md) | [pass / pass](reviews/commercial/review.json) | No revision needed in this sample |
| S19b | [conversion-journey-review](../../skills/conversion-journey-review/SKILL.md) | [pass / pass](reviews/commercial/review.json) | [First recheck: pass/pass/pass](reviews/reruns/review.json) |
| S20a | [customer-interview-planning](../../skills/customer-interview-planning/SKILL.md) | [pass / pass](reviews/commercial/review.json) | No revision needed in this sample |
| S20b | [research-evidence-capture](../../skills/research-evidence-capture/SKILL.md) | [pass / pass](reviews/commercial/review.json) | No revision needed in this sample |
| S20c | [feedback-synthesis](../../skills/feedback-synthesis/SKILL.md) | [needs-revision / pass](reviews/commercial/review.json) | [First recheck: needs-revision/pass/pass](reviews/reruns/review.json); [Second recheck: needs-revision/pass/pass](reviews/second-rerun/review.json); [Third recheck: pass/pass/pass](reviews/third-rerun/review.json) |
| S21a | [funnel-analysis](../../skills/funnel-analysis/SKILL.md) | [pass / pass](reviews/commercial/review.json) | No revision needed in this sample |
| S21b | [growth-experiment-design](../../skills/growth-experiment-design/SKILL.md) | [pass / pass](reviews/commercial/review.json) | No revision needed in this sample |
| S21c | [growth-experiment-analysis](../../skills/growth-experiment-analysis/SKILL.md) | [pass / pass](reviews/commercial/review.json) | No revision needed in this sample |
| S22a | [search-intent-research](../../skills/search-intent-research/SKILL.md) | [pass / pass](reviews/operations/review.json) | No revision needed in this sample |
| S22b | [seo-content-planning](../../skills/seo-content-planning/SKILL.md) | [pass / pass](reviews/operations/review.json) | No revision needed in this sample |
| S22c | [technical-seo-review](../../skills/technical-seo-review/SKILL.md) | [pass / pass](reviews/operations/review.json) | No revision needed in this sample |
| S23a | [paid-campaign-planning](../../skills/paid-campaign-planning/SKILL.md) | [pass / pass](reviews/operations/review.json) | No revision needed in this sample |
| S23b | [campaign-measurement-planning](../../skills/campaign-measurement-planning/SKILL.md) | [pass / pass](reviews/operations/review.json) | No revision needed in this sample |
| S23c | [paid-campaign-analysis](../../skills/paid-campaign-analysis/SKILL.md) | [pass / pass](reviews/operations/review.json) | No revision needed in this sample |
| S24a | [sales-call-preparation](../../skills/sales-call-preparation/SKILL.md) | [pass / pass](reviews/operations/review.json) | No revision needed in this sample |
| S24b | [objection-analysis](../../skills/objection-analysis/SKILL.md) | [pass / pass](reviews/operations/review.json) | No revision needed in this sample |
| S24c | [pipeline-hygiene](../../skills/pipeline-hygiene/SKILL.md) | [pass / pass](reviews/operations/review.json) | No revision needed in this sample |
| S25a | [onboarding-design](../../skills/onboarding-design/SKILL.md) | [pass / pass](reviews/operations/review.json) | No revision needed in this sample |
| S25b | [support-response-preparation](../../skills/support-response-preparation/SKILL.md) | [pass / pass](reviews/operations/review.json) | No revision needed in this sample |
| S25c | [retention-analysis](../../skills/retention-analysis/SKILL.md) | [pass / pass](reviews/operations/review.json) | No revision needed in this sample |
| S26a | [release-planning](../../skills/release-planning/SKILL.md) | [pass / pass](reviews/operations/review.json) | No revision needed in this sample |
| S26b | [deployed-verification](../../skills/deployed-verification/SKILL.md) | [pass / pass](reviews/operations/review.json) | No revision needed in this sample |
| S26c | [incident-diagnosis](../../skills/incident-diagnosis/SKILL.md) | [pass / pass](reviews/operations/review.json) | No revision needed in this sample |
| S26d | [recovery-planning](../../skills/recovery-planning/SKILL.md) | [pass / pass](reviews/operations/review.json) | No revision needed in this sample |
| S27a | [portable-skill-authoring](../../skills/portable-skill-authoring/SKILL.md) | [pass / pass](reviews/operations/review.json) | No revision needed in this sample |
| S27b | [skill-evaluation](../../skills/skill-evaluation/SKILL.md) | [pass / pass](reviews/operations/review.json) | No revision needed in this sample |
