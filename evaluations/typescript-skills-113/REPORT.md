# TypeScript skill evaluation

The four existing project skills were exercised with the synthetic [case](case/brief.md) and [withheld scoring criteria](rubric.md). The case covers a shared schema, a local receiver, a late renderer response, a proposed Node import and a packaged-desktop acceptance claim. No application source, provider login, global skill installation or remote service formed part of the exercise.

## Inputs and discovery

- Canonical skill source, checked from base `89262ff`, lives under `skills/`. Only the four affected entry digests changed in the catalog. The existing Swift reference remained available through the implementation skill.
- The repository skill-layout check reported 14 shared skills with matching Codex and Claude discovery links. Reading each new TypeScript reference through both provider directories returned the canonical bytes. These are filesystem discovery results.
- The authoring validator accepted all four entries. The first invocation used a Python installation without PyYAML. The successful run used the existing system Python and PyYAML 6.0.1. The layout check also rejected stale catalog digests before the catalog refresh.
- The runner used Node 24.19.0 and the local Zod 4.6.7 package. The public package link targeted the synthetic contract source. The boundary-rule source used for the probe had SHA-256 `e27b0ad12c41cb1e3ca5dbd3b0439ba68b01a8d8c11a95a12495093f4bbd09e5`.

## Deterministic probes

The first run of [the probes](probes.mjs) in a disposable copy reported two failures and zero passes. Submitting null threw while reading the project ID. Releasing the older chat read last left its message visible after the selection changed. The tests check the receiver's enqueue and owner-lookup counts as well as the view's final ID and message.

The dependency check in the clean case exited zero. Appending the proposed public re-export to the case produced exit one and the diagnostic `packages/contracts/src/index.ts:10: unapproved external dependency (node:path)`. This measures the dependency policy. A packaged client was unavailable.

To repeat, copy `case/` to an empty directory and place `probes.mjs` beside `brief.md`. Link `node_modules/@example/contracts` to that copy's `packages/contracts` and `node_modules/zod` to a pinned local Zod installation. Initialize a disposable Git repository there and invoke the commands from that directory.

```sh
node --test probes.mjs
node "$BOUNDARY_CHECKER"
```

Set `BOUNDARY_CHECKER` to the checked-out dependency's `scripts/typescript/boundaries.mjs`. Repeat the boundary check after adding the single export in the brief to the disposable copy. Preserve the unmodified baseline when evaluating a repaired copy.

## Independent forward exercise

A fresh evaluator received only the four portable skill entry points and their TypeScript references, an isolated copy of the case and its brief, and the pinned local runner and package links. It had no implementation conversation, rubric or held-out probes. The collaboration runtime inherited the session model. The evaluator performed the implementation and automation tasks and answered the separate review and planning requests.

| Case | Observed answer or result |
| --- | --- |
| Backend and shared contract | The repair calls the public schema's `safeParse` before ownership lookup. Nine malformed inputs were rejected before lookup or enqueue. Both a foreign project and a foreign session were denied. One owned input at the 64-character limit dispatched once. |
| Frontend automation | Three tests drive public `select` through reverse completion, a change while loading and reopening the first conversation. Promise barriers control completion order. A generation counter prevents a stale reply from replacing the current message. |
| Boundary review | The evaluator located the proposed export on the public contract entry. It explained that importing any runtime symbol could cause the renderer build or loader to resolve `node:path`, which the specified environment lacks. It recommended leaving the helper with its Node owner or using a browser-safe display implementation. |
| Platform evidence | The evaluator attributed the supplied DOM selection result to that component and the new headless test to stale-result ordering. It left packaged acceptance open and specified native close/relaunch with a real preload, the same profile, restoration only to the original chat ID and a check that the draft remained unsent. |

The evaluator's `node --test --test-reporter=spec` run discovered 15 tests. Against the original implementation, three passed and twelve failed. After the repair all 15 passed, with zero skipped or canceled. The [four evaluator-produced source and test files](result/apps/) are retained. After copying them into a fresh case, both previously withheld probes also passed. A separate strict no-emit compile of all four files passed with TypeScript 6.0.3, NodeNext resolution, ES2024 libraries and Node 24.19.0 declarations. The boundary checker returned exit zero after removal of the separate proposed export. No raw client or desktop build was available for the review finding. The supplied DOM result was an input, not an independent rerun.

To replay the evaluator's red run, copy the two `*.test.ts` files from `result/apps/` into the corresponding prepared case directories and run `node --test --test-reporter=spec`. For the green run, overlay the two repaired implementation files in the same locations and repeat. Run `node --test probes.mjs` separately to verify the held-out inputs.

## Repository integration

The candidate engineering commands confirmed against #110 and #111 are project-specific. The portable references direct agents to inspect the consuming repository's own package and gate configuration.

| Candidate command | Evidence it is designed to produce |
| --- | --- |
| `pnpm check:style` | Workspace typecheck, `pnpm check:boundaries`, lint and formatting checks. |
| `bash scripts/check-typescript.sh <fresh-evidence-directory>` | Pinned workspace checks, recursively configured package tests and Vitest execution with discovered case results. |
| `swift run quality-gate vitest --root <source> --output <evidence>` | Validation of Vitest reports against the required inventory in `Tools/required-vitest.json`. |

This skill exercise used the targeted boundary and fixture checks. No full TypeScript gate, native suite, browser launch, or cross-provider comparison ran in this exercise. One synthetic evaluation cannot establish a general change in agent reliability.
