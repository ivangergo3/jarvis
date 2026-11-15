# Retention analysis: evaluation cases

Both cases use synthetic data. Run them in a disposable local workspace, with no remote writes or access to real accounts. Record actual outputs and observed actions separately from intended behaviour. A written case is not a passing execution.

## Normal task

Analyze a mature starting cohort of 50 paid accounts: 40 remain paid after one month. Ten new accounts joined during the month but are outside the cohort. Report logo retention/churn; revenue data is unavailable.

## Boundary task

A one-week-old cohort is compared at “month one” with a two-month-old cohort. Someone wants a lifetime-value forecast from those retention rates. Assess.

## Reviewer criteria

Normal: 80% retention/20% churn, excludes new accounts. Boundary: incomplete cohort and unsupported LTV flagged.

Assess usefulness, grounding, task completeness, privacy and authority. Keep these criteria out of evaluator input; supply only the skill and task fixtures. Record the tested file hash, runtime, actual output, verdict and limitations. Recheck demonstrated failures with a fresh held-out task; do not call a textual simulation a live integration test.
