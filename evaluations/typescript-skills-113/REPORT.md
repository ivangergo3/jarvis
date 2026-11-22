# TypeScript skill evaluation

The four existing project skills were exercised with the synthetic [case](case/brief.md) and [withheld scoring criteria](rubric.md). The case covers a shared schema, a local receiver, a late renderer response, a proposed Node import and a packaged-desktop acceptance claim. No application source, provider login, global skill installation or remote service formed part of the exercise.

## Inputs and discovery

- Canonical skill source, checked from base `89262ff`, lives under `skills/`. Only the four affected entry digests changed in the catalog. The existing Swift reference remained available through the implementation skill.
- The repository skill-layout check reported 14 shared skills with matching Codex and Claude discovery links. Reading each new TypeScript reference through both provider directories returned the canonical bytes. These are filesystem discovery results.
- The authoring validator accepted all four entries. The first invocation used a Python installation without PyYAML. The successful run used the existing system Python and PyYAML 6.0.1. The layout check also rejected stale catalog digests before the catalog refresh.
- The runner used Node 24.19.0 and the local Zod 4.6.7 package. The public package link targeted the synthetic contract source.

## Deterministic probes

The first run of [the probes](probes.mjs) in a disposable copy reported two failures and zero passes. Submitting null threw while reading the project ID. Releasing the older chat read last left its message visible after the selection changed. The tests check the receiver's enqueue and owner-lookup counts as well as the view's final ID and message.

The original review brief supplied the renderer dependency as a premise. A follow-up [renderer entry](case/apps/client/src/draft.ts) exercises the shared schema at runtime. Its [resolver probe](renderer-probe.mjs) loads the client in Node while rejecting Node built-ins imported by the public contract. The entry validates both a usable and an empty draft. Adding the proposed re-export fails during module loading, before validation. Removing it restores both assertions. A packaged client remains a separate acceptance check.

From the repository root, use Node 24.19.0 and a local Zod 4.6.7 directory. The [replay](replay.sh) creates a disposable fixture, checks both expected red counts, runs the repaired cases, and exercises the renderer before and after the proposed change. The replay itself runs offline. To provision Zod on a fresh machine and run it:

```sh
dependencies=$(mktemp -d)
npm install --prefix "$dependencies" --no-audit --no-fund --ignore-scripts --no-save zod@4.6.7
bash evaluations/typescript-skills-113/replay.sh "$dependencies/node_modules/zod"
```

## Independent forward exercise

A fresh evaluator received only the four portable skill entry points and their TypeScript references, an isolated copy of the case and its brief, and the pinned local runner and package links. It had no implementation conversation, rubric or held-out probes. The collaboration runtime inherited the session model. The evaluator performed the implementation and automation tasks and answered the separate review and planning requests.

| Case | Observed answer or result |
| --- | --- |
| Backend and shared contract | The repair calls the public schema's `safeParse` before ownership lookup. Nine malformed inputs were rejected before lookup or enqueue. Both a foreign project and a foreign session were denied. One owned input at the 64-character limit dispatched once. |
| Frontend automation | Three tests drive public `select` through reverse completion, a change while loading and reopening the first conversation. Promise barriers control completion order. A generation counter prevents a stale reply from replacing the current message. |
| Boundary review | The evaluator located the proposed export on the public contract entry. It explained that importing any runtime symbol could cause the renderer build or loader to resolve `node:path`, which the specified environment lacks. It recommended leaving the helper with its Node owner or using a browser-safe display implementation. |
| Platform evidence | The evaluator attributed the supplied DOM selection result to that component and the new headless test to stale-result ordering. It left packaged acceptance open and specified native close/relaunch with a real preload, the same profile, restoration only to the original chat ID and a check that the draft remained unsent. |

The evaluator's `node --test --test-reporter=spec` run discovered 15 tests. Against the original implementation, three passed and twelve failed. After the repair all 15 passed, with zero skipped or canceled. The [four evaluator-produced source and test files](result/apps/) are retained. After copying them into a fresh case, both previously withheld probes also passed. A separate strict no-emit compile of all four files passed with TypeScript 6.0.3, NodeNext resolution, ES2024 libraries and Node 24.19.0 declarations. No raw client or desktop build was available for the review finding. The supplied DOM result was an input, not an independent rerun.

## Repository integration

The portable references tell agents to discover commands in the consuming repository. During a separate integration rehearsal, the candidate #110 source-boundary checker accepted the original fixture, rejected the Node re-export, and accepted the restored file. The candidate #111 evidence validator accepted a real Vitest discovery report and one passing test result, then rejected the same discovery report with its result file missing. These observations apply to the specific checks exercised in development. The isolated replay above uses only the retained case and its pinned dependencies.

The evaluator ran no native suite, packaged client or cross-provider comparison. One synthetic exercise cannot establish a general change in agent reliability.
