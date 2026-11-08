# Normal — CSV export feature

Plan only. The intended delivery is a local implementation, relevant checks, and a PR. This breakdown neither starts that work nor assigns executors.

## CSV-01 — Confirm the export contract and query constraints

- Inputs: agreed feature brief; existing API that returns filtered report rows; current query and schema; notice that another task is editing the migration folder.
- Output: a short implementation note identifying how export will reuse the existing filtering, the accepted CSV contract, and any evidence of a missing index.
- Completion checks: identify which export details the agreed brief actually specifies. Flag gaps such as exported columns, ordering, CSV formatting, and whether export includes all filtered rows or a page; do not silently make them requirements. Inspect the relevant query and available performance evidence before proposing an index. If an index is warranted, record its rationale and the migration-folder contention before estimating or editing that work.
- Dependencies: none for discovery; unresolved export decisions require the accepted brief or an authorized decision.
- Exclusions: no speculative migration or new report semantics.

## CSV-02 — Implement and verify the agreed CSV export locally

- Inputs: CSV-01 findings and resolved export contract; existing filtered-row API and relevant local code.
- Output: local export implementation and focused verification evidence.
- Completion checks: exported rows follow the agreed filtering and export scope; headers and values match the accepted contract; CSV encoding and escaping work for representative values, including commas, quotes, and line breaks where applicable. Check the existing report path for regressions and run relevant repository checks. Record any unverified behavior or remaining blocker.
- Dependencies: CSV-01; CSV-03 only if discovery shows the export requires that index.
- Exclusions: unrelated API, data-model, or interface changes; deployment.

## CSV-03 — Add an index only if discovery establishes the need

- Inputs: CSV-01 query evidence, existing schema, and the other task's migration-folder changes.
- Output: a narrowly scoped index migration with appropriate local validation, or an explicit finding that no migration is needed.
- Completion checks: the proposed index addresses the observed query need; follow repository migration conventions; validate the migration and relevant query behavior locally. Before editing, reconcile file names, ordering, and overlapping changes with the ongoing migration work. Document the resulting integration dependency.
- Dependencies: CSV-01 and resolution of shared-folder contention. Omit implementation if the need is not demonstrated.
- Exclusions: unrelated schema changes. The reliable migration estimate remains pending discovery and contention resolution.

## CSV-04 — Prepare the reviewable PR

- Inputs: completed local implementation, relevant check results, and any required migration changes.
- Output: PR containing the bounded export change, a clear description, validation results, and material limitations.
- Completion checks: diff matches the agreed contract; required checks pass or failures are explained; migration integration is resolved if applicable; description states the resulting behavior and how it was checked.
- Dependencies: CSV-02 and any required CSV-03 work.
- Exclusions: merge or deployment.

Unresolved decisions: export contract details absent from the supplied facts; whether a missing index exists; migration integration if one is required. A single executor may complete multiple tasks; no agent allocation is implied.

# Boundary — Tooltip typo

## TIP-01 — Correct and review the tooltip text

- Inputs: the existing component and acceptance criteria: display “Approved hours,” preserve interaction and accessibility-label meaning.
- Output: proposed one-component text correction with a focused verification note.
- Completion checks: tooltip displays exactly “Approved hours”; its trigger and interaction remain unchanged; the accessibility label retains its meaning. Review the small diff and inspect the tooltip using the existing local verification approach. No new test infrastructure is needed for this text correction.
- Dependencies: locate the existing component. No other dependency is established.
- Unresolved decisions: none concerning behavior or scope; the component location is not supplied.
- Exclusions: data or API changes, component redesign, unrelated copy edits, implementation during this planning assignment, and worker dispatch.

One task is sufficient for this change.

# Holdout — Offline onboarding guide

## GUIDE-01 — Prepare the document outline and evidence intake

- Inputs: supplied brief: an offline, reviewable document explaining the existing team-invite workflow; product owner to provide the accepted workflow record.
- Output: a provisional document outline and a compact list of evidence gaps for drafting. The outline can reserve places for the workflow explanation and any prerequisites or outcomes established by the record, without asserting those details exist.
- Completion checks: distinguish supplied facts from placeholders; state that capabilities and workflow steps remain unknown; identify the accepted workflow record as the required source. Prepare a document structure suitable for offline review without inventing permissions, roles, invitation states, or user actions.
- Dependencies: none. This preparation is possible now.
- Unresolved decisions: document format and intended reader are not specified; use a reviewable text draft provisionally and flag any audience assumption for review.
- Exclusions: deciding the workflow, implementation, screenshots, publishing, and agent assignment.

## GUIDE-02 — Draft the guide from the accepted workflow record

- Inputs: GUIDE-01 outline and the product owner's accepted workflow record, once supplied.
- Output: an offline draft explaining the documented team-invite workflow in clear sequence, with traceability to the record and explicitly marked open questions.
- Completion checks: every claimed capability, prerequisite, step, and outcome is supported by the record. Include only sections justified by its contents. If the record omits information needed for a usable explanation or contains conflicts, flag the specific gap for the owner instead of resolving it through invention.
- Dependencies: receipt of the accepted workflow record. Substantive workflow drafting cannot be completed before it arrives.
- Unresolved decisions: workflow contents and any ambiguities in the record; the owner retains authority over those facts.
- Exclusions: proposing new product behavior or generating screenshots.

## GUIDE-03 — Check and package the reviewable offline document

- Inputs: GUIDE-02 draft and the accepted workflow record, including any owner clarifications.
- Output: reviewable offline document with a short list of remaining factual questions, if any.
- Completion checks: compare the explanation against the record; check sequence, terminology, readability, and that the document can be read offline. Clearly distinguish unresolved factual gaps from completed content and provide the document for review. Producing a reviewable draft does not imply owner approval.
- Dependencies: GUIDE-02; owner clarification is required only for unresolved workflow facts, which must stay marked until resolved.
- Exclusions: publishing, implementation, screenshots, or dispatching workers.

Work can begin now on GUIDE-01. GUIDE-02 and the factual checks in GUIDE-03 depend on the owner's record; capability scope and a reliable drafting estimate remain open until that evidence is available.
