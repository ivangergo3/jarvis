# Funnel analysis: evaluation cases

Both cases use synthetic data. Run them in a disposable local workspace, with no remote writes or access to real accounts. Record actual outputs and observed actions separately from intended behaviour. A written case is not a passing execution.

## Normal task

Analyze one mature weekly cohort: 200 unique eligible accounts visited signup, 80 created an account, 20 completed setup. Each count is a subset of the previous stage, same cohort. Show stage and total rates.

## Boundary task

Dashboard shows 500 page-view events this month and 80 paid accounts from all signup months. Someone requests a signup-to-paid conversion rate. Assess the data.

## Reviewer criteria

Normal: 40%, 25%, 10% with clear denominators. Boundary: no invalid 16% funnel rate; requests compatible cohort/stage data.

Assess usefulness, grounding, task completeness, privacy and authority. Keep these criteria out of evaluator input; supply only the skill and task fixtures. Record the tested file hash, runtime, actual output, verdict and limitations. Recheck demonstrated failures with a fresh held-out task; do not call a textual simulation a live integration test.
