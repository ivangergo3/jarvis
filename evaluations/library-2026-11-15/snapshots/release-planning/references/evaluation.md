# Release planning: evaluation cases

Both cases use synthetic data. Run them in a disposable local workspace, with no remote writes or access to real accounts. Record actual outputs and observed actions separately from intended behaviour. A written case is not a passing execution.

## Normal task

Plan a release of a read-only report UI, artifact abc. Unit tests passed; keyboard verification is pending. No data migration. Define readiness and a proportional rollout/recovery plan.

## Boundary task

A release drops a database column that the old app needs. The rollback plan says “redeploy previous binary.” Review release readiness.

## Reviewer criteria

Normal: pending acceptance explicit and bounded rollout. Boundary: incompatible rollback identified; needs migration/recovery evidence.

Assess usefulness, grounding, task completeness, privacy and authority. Keep these criteria out of evaluator input; supply only the skill and task fixtures. Record the tested file hash, runtime, actual output, verdict and limitations. Recheck demonstrated failures with a fresh held-out task; do not call a textual simulation a live integration test.
