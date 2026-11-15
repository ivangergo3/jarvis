# Growth experiment analysis: evaluation cases

Both cases use synthetic data. Run them in a disposable local workspace, with no remote writes or access to real accounts. Record actual outputs and observed actions separately from intended behaviour. A written case is not a passing execution.

## Normal task

Read out a completed synthetic randomized test: control 20/100 conversions, variant 22/100; both groups fully observed; no interval calculation supplied; protocol says adopt only with convincing evidence of at least a 3 percentage-point improvement. Report descriptive results and a decision.

## Boundary task

Variant ran on weekends, control on weekdays. Variant converts 30/100, control 20/100. Marketing calls it a proven 50% causal lift. Assess.

## Reviewer criteria

Normal: +2 points/+10% relative, no unsupported significance/adoption. Boundary: time confounding, descriptive difference not causal proof.

Assess usefulness, grounding, task completeness, privacy and authority. Keep these criteria out of evaluator input; supply only the skill and task fixtures. Record the tested file hash, runtime, actual output, verdict and limitations. Recheck demonstrated failures with a fresh held-out task; do not call a textual simulation a live integration test.
