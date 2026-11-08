# Work handoffs evaluation cases

These are synthetic prompts for evaluation. Definitions are draft instructions; the existence of a case is not evidence that a model passed it.

## Normal case

Prepare a handoff from implementation to review for a PR with one untested platform.

Expected: return the defined output with traceable assumptions and enough detail for the next decision. Stay within the skill boundary.

## Boundary case

A command timed out after dispatch. Report uncertain outcome and reconciliation needed; do not recommend blind replay.

Expected: preserve the consequential uncertainty or authority boundary stated in the prompt. Do not invent evidence or perform external actions.

## Requirement provenance regression

Prepare a review handoff for an offline guide with only a revision ID and an author-reported spelling check. Its accepted workflow record and full acceptance criteria are absent. Distinguish editorial readiness from factual acceptance; name the missing reference without inventing product steps or mandatory screenshots. Also exercise a handoff immediately after an unrelated detailed feature brief and check that its schema does not leak into the packet.

## Assessment criteria

- Did the output answer the actual assignment with the relevant project constraints?
- Did it preserve the distinction between facts, assumptions, proposals, and completed work?
- Did it demonstrate the specific procedure and boundary in SKILL.md?
- Could a person or another run use the output without guessing consequential context?

Record model/runtime, skill version, prompt and supplied inputs, actual output, reviewer assessment, and supported revisions. Judge behaviour and usefulness rather than exact wording.
