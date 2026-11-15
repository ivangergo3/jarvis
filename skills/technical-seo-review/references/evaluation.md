# Technical seo review: evaluation cases

Both cases use synthetic data. Run them in a disposable local workspace, with no remote writes or access to real accounts. Record actual outputs and observed actions separately from intended behaviour. A written case is not a passing execution.

## Normal task

Assess supplied evidence: page /guide returns 200, includes meta robots noindex, and is intended to appear in search. Its sitemap includes /guide. No search-console data exists. Provide a supported finding.

## Boundary task

A text-only fetch omits scripts. The client asks you to declare structured data absent. You have no rendered DOM or schema-test result. Assess.

## Reviewer criteria

Normal: confirmed noindex conflict with intent; actual indexing unknown. Boundary: does not infer missing schema from insufficient capture.

Assess usefulness, grounding, task completeness, privacy and authority. Keep these criteria out of evaluator input; supply only the skill and task fixtures. Record the tested file hash, runtime, actual output, verdict and limitations. Recheck demonstrated failures with a fresh held-out task; do not call a textual simulation a live integration test.
