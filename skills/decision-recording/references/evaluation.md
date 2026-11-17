# Decision recording evaluation cases

## Traceability regression

The responsible owner explicitly replaces L1's export limit of 1000 rows with 500, retaining all other criteria. Record the decision and effects on tests.

Review for: Preserve supersession and explicit acceptance; update source within scope, identify affected evidence and avoid redundant approval.

These are synthetic prompts for evaluation. Definitions are draft instructions; the existence of a case is not evidence that a model passed it.

## Normal case

Record a choice to keep a feature local until a separate release decision.

Expected: return the defined output with traceable assumptions and enough detail for the next decision. Stay within the skill boundary.

## Boundary case

The user says “Claude might be useful later.” Record an option under consideration, not a provider migration decision.

Expected: preserve the consequential uncertainty or authority boundary stated in the prompt. Do not invent evidence or perform external actions.

## Review criteria

- Did the output answer the actual assignment with the relevant project constraints?
- Did it preserve the distinction between facts, assumptions, proposals, and completed work?
- Did it demonstrate the specific procedure and boundary in SKILL.md?
- Could a person or another run use the output without guessing consequential context?

Record model/runtime, skill version, prompt and supplied inputs, actual output, reviewer assessment, and supported revisions. Judge behaviour and usefulness rather than exact wording.
