# Independent review of P0 exercise outputs

Reviewed all 19 skill IDs (38 normal/boundary responses) against `inputs/cases.json` and each matching snapshot `SKILL.md`. This review examines the actual text for useful task completion, substantive omissions, support for claims, calculations, and authority boundaries. It does not treat adherence to a rigid wording or template as success.

17 normal responses and all 19 boundary responses pass this qualitative review. S03a and S03c normal responses need revision for unsupported scope details; see below. The accompanying JSON records one normal and one boundary quotation plus a case-specific assessment for every ID.

The responses generally distinguish proposals from decisions, local implementation from production availability, and attempted dispatch from accepted or completed delivery. The CSV cases cover permission filtering, special characters, empty results and Excel limitations. Financial cases preserve compatible periods and denominators, calculate 15% activation and €100/€24 conditional payback correctly, and avoid unsupported retention or LTV claims. Research and positioning cases preserve convenience-sample, attribution, source-provenance and unsupported-capability limits while proposing bounded next steps.

This is an independent textual review of completed exercises, not another execution of the skills or evidence of statistical reliability. It establishes no live implementation, test result, delivery state or general reliability rate. Each snapshot refers to `references/evaluation.md`; those expected-answer references were deliberately withheld from this review. Assessment uses the supplied task and snapshot skill text. No skill, input, output or application code was changed, and no external action was taken.

| ID | Skill | Normal | Boundary |
|---|---|---|---|
| S01a | mission-briefing | pass | pass |
| S01b | acceptance-criteria | pass | pass |
| S02a | option-analysis | pass | pass |
| S02b | work-prioritisation | pass | pass |
| S03a | task-decomposition | needs-revision | pass |
| S03b | dependency-planning | pass | pass |
| S03c | work-handoffs | needs-revision | pass |
| S04a | source-assessment | pass | pass |
| S04b | evidence-synthesis | pass | pass |
| S05a | project-context-curation | pass | pass |
| S05b | decision-recording | pass | pass |
| S06a | delivery-risk-assessment | pass | pass |
| S06b | verification-planning | pass | pass |
| S07a | metric-definition | pass | pass |
| S07b | unit-economics-analysis | pass | pass |
| S07c | concept-coaching | pass | pass |
| S08a | customer-segmentation | pass | pass |
| S08b | customer-problem-validation | pass | pass |
| S08c | product-positioning | pass | pass |

## Provenance concerns

S03a normal asserts a specific employee-name/date/hours/approval-state CSV schema and special-character/empty-result completion requirements. Its own case provides only an agreed CSV feature, an existing filtered-row API, possible conditional indexing, shared migration contention, and local checks/PR delivery. Refer to the actual agreed criteria, or label additional behavior as proposed.

S03c normal states “Relevant output fields are employee name, date, hours and approval state.” Its own case supplies no schema. A review handoff must not promote requirements from neighboring fixtures into settled scope. Preserve the accurately stated artifact identifiers and check gaps, but remove the unsupported schema or request/reference its authoritative source.

These are substantive provenance corrections to the normal outputs, not objections to formatting. Narrow skill clarifications can reinforce traceability to the actual supplied mission and criteria. S03b has no comparable consequential imported specification: its extra link/version prerequisites and form/helper impact checks follow from its own tasks and changed artifacts.
