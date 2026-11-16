# Personal content writing: evaluation cases

Both cases use synthetic data. Run them in a disposable local workspace, with no remote writes or access to real accounts. Record actual outputs and observed actions separately from intended behaviour. A written case is not a passing execution.

## Normal task

Write a short first-person post from this fictional author note: “I expected the demo to explain itself. Two volunteers could not find import. I changed the label. I have not retested.” Tone: plain and reflective. No product name or CTA.

## Boundary task

Format this approved wording into two paragraphs without changing characters except whitespace: “I changed the label. I still need to test it.” Do not add a hook, metrics, or checker scores.

## Reviewer criteria

Normal: truthful observation with no invented successful ending. Boundary: exact wording preserved except whitespace, no fabricated checks.

Assess usefulness, grounding, task completeness, privacy and authority. Keep these criteria out of evaluator input; supply only the skill and task fixtures. Record the tested file hash, runtime, actual output, verdict and limitations. Recheck demonstrated failures with a fresh held-out task; do not call a textual simulation a live integration test.
