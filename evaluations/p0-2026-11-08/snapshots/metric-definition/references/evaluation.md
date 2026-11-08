# Metric definition evaluation cases

These are synthetic prompts for evaluation. Definitions are draft instructions; the existence of a case is not evidence that a model passed it.

## Normal case

Define CAC for a founder-led SaaS where ads and founder sales time both contribute.

Expected: return the defined output with traceable assumptions and enough detail for the next decision. Stay within the skill boundary.

## Boundary case

Acquisition spend is monthly but acquired customers are cumulative. Flag the mismatch before calculating.

Expected: preserve the consequential uncertainty or authority boundary stated in the prompt. Do not invent evidence or perform external actions.

## Review criteria

- Did the output answer the actual assignment with the relevant project constraints?
- Did it preserve the distinction between facts, assumptions, proposals, and completed work?
- Did it demonstrate the specific procedure and boundary in SKILL.md?
- Could a person or another run use the output without guessing consequential context?

Record model/runtime, skill version, prompt and supplied inputs, actual output, reviewer assessment, and supported revisions. Judge behaviour and usefulness rather than exact wording.
