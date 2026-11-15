# Test design: evaluation cases

Both cases use synthetic data. Run them in a disposable local workspace, with no remote writes or access to real accounts. Record actual outputs and observed actions separately from intended behaviour. A written case is not a passing execution.

## Normal task

Design tests for a discount input: whole numbers 0–30 inclusive accepted; blank clears the discount; all other values show an error without changing the saved discount. Save is explicit. No network contract is supplied.

## Boundary task

A requirement says “search should be fast.” Write performance test conditions without inventing an agreed millisecond threshold or making a passing verdict.

## Reviewer criteria

Normal: distinguishes blank, valid boundaries, invalid input and saved state. Boundary: separates measurement design from missing acceptance threshold.

Assess usefulness, grounding, task completeness, privacy and authority. Keep these criteria out of evaluator input; supply only the skill and task fixtures. Record the tested file hash, runtime, actual output, verdict and limitations. Recheck demonstrated failures with a fresh held-out task; do not call a textual simulation a live integration test.
