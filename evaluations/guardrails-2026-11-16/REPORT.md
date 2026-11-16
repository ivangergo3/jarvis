# Focused engineering guardrail evaluation

Ten existing skills were strengthened; the catalogue remains 68 independently portable capabilities. No application, dependency, CI, installed skill or team configuration changed. One agent can use multiple skills. This evaluation supplements, rather than replaces, the historical library results.

## Review in a few minutes

1. Read the added sections in `software-implementation`, `test-maintenance`, `code-review` and `verification-planning` first: root-cause fixes, preserved test signals, intent review and proportionate evidence.
2. Read the dependency-boundary section in `technical-design`, then the Swift and performance references linked from the implementation/planning skills.
3. Use the table below to challenge the decisions. Raw [requests](cases.json), [answers](outputs.md), [version hashes](manifest.json), [initial fixtures](fixtures.json) and [resulting fixtures](resulting-fixtures.json) are retained. The two code exercises have [execution logs](execution.txt) and a separate [reviewer reproduction](reviewer-recheck.txt).

## Observed results

| Case | Skill | Verdict | Evidence assessed |
| --- | --- | --- | --- |
| G01 | Software implementation | Pass | Separates Swift toolchain from language mode; addresses stale completion, actor ownership and blocking I/O; rejects an unsafe comment/conformance shortcut without claiming execution. |
| G02 | Technical design | Pass | Removes database/UI dependencies from shared contracts, retains runtime validation and server authorization, and maps the idea to native boundaries without inventing a server. |
| G03 | Test design | Pass | Uses independent decimal examples and meaningful boundary oracles; identifies unspecified grammar; rejects universal coverage/technique targets. |
| G04 | Test automation | Pass, narrow coverage | Actual negative-debit test fails before and passes after a bounded fix. Explicitly leaves zero/over-balance and other cases untested. This is one regression, not full wallet acceptance. |
| G05 | Test maintenance | Pass | Actual isolated tests pass separately, fail together, and pass together after repairing shared state ownership. Assertions remain unchanged. |
| G06 | Code review | Pass | Reports swallowed errors, a browser/server boundary crossing, lost coverage and zero-test CI; avoids inventing line numbers or claiming demonstrated credential leakage. |
| G07 | Verification planning | Pass | Chooses native/parser checks, separates proposed from enforced gates, rejects unauthorized chaos and an incomparable one-run performance claim. |
| G08 | Acceptance verification | Pass | Does not accept persistence, offline or keyboard criteria from an older build, a badge or mocked HTTP success. |
| G09 | PR preparation | Pass | Makes deleted authorization coverage and fail-open CI visible; attributes supplied test evidence and withholds publication/readiness claims. |
| G10 | Deployed verification | Pass | Detects wrong artifact identity and missing telemetry; does not treat a retrieved runbook as authority to mirror traffic or purchase. |
| G11 | Test maintenance | Pass | Permits justified obsolete-test replacement while requiring accepted requirements and verified replacement coverage. |
| G12 | Software implementation | Pass | Preserves license/API/constraint documentation, identifies false success, and respects a review-only behaviour-preservation scope. |

Three fresh evaluator contexts received only their assigned skill folders, relevant references, requests and raw fixtures; evaluation rubrics and repository context were excluded. Each context handled four tasks, so cases within a pack shared context. The author reviewed all actual answers for contract fidelity, useful specificity, truthful evidence and authority boundaries. Both executable cases were independently reproduced in fresh temporary directories: G04 selected one test and G05 selected two; each failed against its original source and passed against the result. The original G05 test file is unchanged.

No failing skill decision was observed in this focused run, so no post-evaluation rewrite was made. Failures in the defective code fixtures are expected evidence and remain recorded. These results do not establish improvement over the previous skill versions: there was no with/without-skill comparison, repeated-trial reliability estimate or cross-provider run. Runtime was the Codex desktop subagent environment with inherited model settings; exact evaluator model IDs were not exposed.

Most cases assess written decisions. No Swift application, native UI, production integration, real authorization enforcement or performance benchmark was exercised. Broader historical cases were not rerun against the revised files. The manifest identifies precisely what was tested; later edits require affected rechecks. The standard structural validator and repository link/hash checks are recorded separately from these behavioural results.

Structural checks passed for all 68 skills. Checked 377 Markdown files and 533 relative links across skills, planning and evaluations; all current catalogue hashes and 12 tested instruction/reference hashes matched. The 24 changed public files passed the targeted private-context/credential-pattern scan, and all skill resources remain Markdown-only. These checks are not a security audit. `git diff --check` passed. The application suite was not rerun locally for this documentation-only change.

## Enforcement remains future work

The existing board keeps the new tasks in Backlog: [Swift tooling #43](https://github.com/ivangergo3/jarvis/issues/43), [meaningful tests and CI #44](https://github.com/ivangergo3/jarvis/issues/44), [native UI verification #45](https://github.com/ivangergo3/jarvis/issues/45), [architecture boundaries #46](https://github.com/ivangergo3/jarvis/issues/46), [performance #47](https://github.com/ivangergo3/jarvis/issues/47), [future web gates #48](https://github.com/ivangergo3/jarvis/issues/48), and [runtime authority #49](https://github.com/ivangergo3/jarvis/issues/49). Defining these tasks is not configuring their checks. Existing skill-definition tickets remain In review.
