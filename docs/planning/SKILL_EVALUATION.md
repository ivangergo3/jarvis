# Jarvis skill evaluation

Each P0 skill includes synthetic normal and boundary cases in its references/evaluation.md. These cases define what to exercise; they do not establish that an execution passed.

## Review before behavioural evaluation

Check frontmatter and naming, a discriminating trigger, meaningful inputs and output, a narrow boundary, relative reference links, and portability when copied alone. Check overlap with adjacent skills and avoid mandatory team or provider assumptions.

## Behavioural evaluation

Use a realistic prompt and the relevant skill plus minimum raw artifacts. Use fixtures or read-only sources unless additional execution is authorized. Evaluate the normal case and the consequential boundary case, then a composition scenario where useful. A separate execution can reduce author bias, but this phase does not set up an agent team.

Record the exact skill version, model/runtime if used, prompt, supplied artifacts, actual output, reviewer assessment, and changes supported by the result. Review usefulness, factual grounding, output completeness, authority, and the skill’s specific boundary. Do not score exact phrasing as correctness.

Do not close a definition ticket solely because files exist or a structural validator passed. Keep the ticket open until the planned cases have reviewed outcomes or a clearly justified acceptance decision. Greg can review technical reasoning and choose validation depth; marketing exercises should also assess whether the explanation supports his understanding.

## Composition exercises

- Briefing plus acceptance criteria: a bounded CSV export without scheduled delivery.
- Source assessment plus synthesis plus problem validation: supplied interview excerpts, including contradictory evidence.
- Metric definition plus economics analysis plus coaching: €600 acquisition spend, six new paying customers in the same window, €30 monthly revenue per customer, 80% gross margin, no retention history. Expected calculations under the supplied simplified cost definition are €100 CAC and €24 monthly gross profit per customer; a roughly 4.17 month simple payback is conditional on continued contribution and the given cost scope. Do not estimate reliable lifetime value without supporting retention evidence.
- Risk assessment plus verification planning: a potentially accepted queued message with a lost acknowledgement. Plan reconciliation and duplicate-send checks, not blind retry.

## Initial verification record

The first drafting pass creates instructions and evaluation fixtures only. Structural validation and link checks are reported separately in the delivery record. No model-run behavioural result, external integration readiness, app acceptance, or team configuration is established by these documents.
