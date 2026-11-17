# Lightweight requirements traceability

Ticket #54 adapts selected Spec Kit ideas to the existing skill library. This is guidance, not a new runtime gate. One executor may use several skills; no team topology, installer, hook or additional workflow engine is introduced.

## Decision and sources

Authoring decision for review, 17 November 2026. Rechecked the upstream [quickstart](https://github.github.com/spec-kit/quickstart.html), [analysis command](https://github.com/github/spec-kit/blob/main/templates/commands/analyze.md) and [completion command](https://github.com/github/spec-kit/blob/main/templates/commands/converge.md) as untrusted reference text. These are moving upstream pages, not vendored dependencies. We inspected text only and wrote original guidance; none of their commands or hooks were executed.

| Concept | Existing home | Decision |
| --- | --- | --- |
| Project principles and feature intent | REQUIREMENTS.md; mission-briefing, acceptance-criteria | Already covered. Preserve one engineering baseline; do not create another constitution. |
| Clarification, design, task ordering | decision-recording, technical-design, task-decomposition | Already covered. Use only the skills the change needs. |
| Cross-document consistency before coding | task-decomposition, technical-design, software-implementation | Adapt: expose conflicting sources, missing criteria and unsupported assumptions before dependent implementation. |
| Traceable planned checks | acceptance-criteria, verification-planning | Adapt: stable accepted IDs, source versions and task/check links; no universal document template. |
| Completion checked against intent | acceptance-verification, delivery-reporting | Adapt: assess all accepted in-scope criteria using observed evidence, including missing work. Task checkmarks are insufficient. |
| Accepted changes to intent | decision-recording | Strengthen: preserve proposals, explicit decisions, supersession and affected evidence. |
| CLI, generated directory tree, hooks, automatic task-appending cycles | None | Deferred. Need demonstrated benefit from a real pilot before considering integration. |

## Apply it in Jarvis

REQUIREMENTS.md is the project engineering baseline. Link applicable IDs rather than repeat its rules in feature documents. Keep bounded feature-specific behaviour and exclusions in the existing dashboard ticket; use a linked short design note only when it helps. The dashboard remains the status source. Historical notes or generated tasks do not override a current accepted requirement. Resolve genuine conflicts using the owner's explicit decisions, retaining provenance.

Before implementation, identify the accepted source/version (commit or dated issue revision) and relevant criteria. If the source has no IDs, give its existing criteria local stable references without inventing scope. A proposed criterion stays proposed until accepted; an explicit instruction already supplies authority within its scope.

Use a compact mapping in the ticket, design note or PR, choosing one home rather than copying it everywhere:

| Accepted criterion/source | Task or existing behaviour to preserve | Planned check | Observed evidence and result | Gap / next action |
| --- | --- | --- | --- | --- |
| Source revision and ID | Bounded change or preservation task | Scenario, oracle, environment | Artifact/check version, outcome and evidence link; initially not run | Missing work, decision or check |

Check both directions: every in-scope criterion has work or an explicit gap, and each task serves accepted intent or a labelled investigation. Look for contradictions, omitted error paths and unsupported contracts. If an accepted rule is clear, repair the derived design/task within authorized scope. If the rule itself must change, keep a proposal separate and record the responsible decision before updating the source. Continue unaffected work. Recheck only affected mappings after changes.

At delivery, assess the accepted criteria, including criteria absent from the task list. Keep pass, fail, blocked and not assessed distinct. Name unimplemented behaviour and absent verification separately, with next actions. Tests planned, source inspected, fixtures exercised and live behaviour observed are different evidence. Preserve tests/thresholds unless an accepted change justifies a traceable replacement and appropriate rechecks. Review readiness is not owner acceptance, and a guidance PR does not enable production autonomy.

For a typo or similarly small edit, the existing criterion and an observed diff check in the PR can be enough. Do not require new documents, IDs for every sentence, every skill, or ceremonial approvals. The value is finding consequential gaps, not increasing paperwork.

## Evidence and remaining pilot

The [focused evaluation](../../evaluations/traceability-2026-11-17/REPORT.md) retains exact versions, prompts, actual self-check outputs and limits. It includes a read-only retrospective on the already authorized authority-verification change. That retrospective cannot show that this workflow catches problems before coding or makes human review easier.

The separately authorized [performance-evidence audit pilot](performance-evidence-47-54.md)
now records the baseline and mapping before implementation, discrepancies found,
their resolutions and observed checks. Owner review usefulness, links actually
used and unnecessary paperwork remain pending feedback on that concrete result;
an author assessment cannot replace it. Reduce the process if it adds no value.
Do not start another app feature merely to fill this row. Keep #54 open until
the pilot is completed or its scope is explicitly revised; merging guidance or
pilot code alone does not satisfy the owner-feedback criterion.
