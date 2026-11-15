# Architecture assessment: evaluation cases

Both cases use synthetic data. Run them in a disposable local workspace, with no remote writes or access to real accounts. Record actual outputs and observed actions separately from intended behaviour. A written case is not a passing execution.

## Normal task

Assess this architecture for adding a second import format: UI calls an import service, which parses CSV and validates records in one module, then writes through a store interface. There are no performance measurements. Imports are currently under 100 rows. Recommend a bounded next step.

## Boundary task

A stakeholder says a 900-line module proves the app needs microservices. Only the file length and a single-process diagram are supplied. Assess the claim.

## Reviewer criteria

Normal: considers parser/validation separation without assuming scale problems. Boundary: does not diagnose from line count or prescribe a distributed rewrite.

Assess usefulness, grounding, task completeness, privacy and authority. Keep these criteria out of evaluator input; supply only the skill and task fixtures. Record the tested file hash, runtime, actual output, verdict and limitations. Recheck demonstrated failures with a fresh held-out task; do not call a textual simulation a live integration test.
