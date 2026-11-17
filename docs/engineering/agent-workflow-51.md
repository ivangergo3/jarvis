# Skill discovery and agent workflow

Ticket #51 applies selected official best practices to this repository. The [traceability workflow](traceability-54.md) remains the criteria/evidence policy; this note covers how a run gets relevant context and how its result is assessed. It does not create a team or enable the Jarvis coordinator.

## One library, explicit project discovery

`skills/` is the maintained portable library. `Tools/project-skills.json` selects 14 existing planning, engineering, testing, review and reporting capabilities used for this repository's work. Each entry has a relative directory symlink in `.agents/skills/` for Codex and `.claude/skills/` for Claude Code. Both point to the same canonical source; edit `skills/`, not copies. The rest of the 68-skill library remains available for explicit relevant tasks. This subset is a starting selection, not a fixed role structure. One executor can use several skills.

No global settings, permissions, MCP server, provider credentials or skill body changed. `CLAUDE.md` contains only `@AGENTS.md`, so Claude-compatible clients can import the project instructions without a second policy. Current Claude versions may also discover AGENTS.md directly; the documented import supports sessions where they do not. Runtime discovery still needs to be checked on the actual client and policy configuration.

Run `swift run quality-gate skills` after changing the selected set, sources or discovery links. It checks exact provider inventories, relative targets, canonical source containment, basic name/description frontmatter and the existing catalogue's source hashes. It rejects copies, missing/broken/external links, unexpected entries and stale hashes, and overwrites stale success evidence on failure. This is a structural gate, not a complete YAML parser, runtime sandbox or behavioural evaluator. `./scripts/check.sh` includes it once; CI does not require installed Codex or Claude or a model account. A clone must preserve Git symlinks; a checkout that materializes them as text fails this check rather than silently passing.

## Observed discovery, with limits

On 17 November 2026, installed `codex-cli 0.169.0-alpha.11.1` was exercised through a fresh local stdio App Server with a disposable home/config directory and scrubbed environment. The installed client generated its JSON schema first. Only `initialize`, `initialized` and `skills/list` were sent; no thread or model turn was started. Baseline: zero repo skills, no load errors. After wiring: all 14 expected repo skills enabled, exact canonical paths, no load errors, both at repository root and under `Sources/Jarvis`. Built-in non-repository skills are excluded from the public result. [Sanitized evidence](../../evaluations/discovery-2026-11-17/result.json) records metadata only, without machine names, home paths or personal skill inventories.

This verifies fresh-process metadata discovery for the stated client. It does **not** verify automatic skill selection, body/reference activation, compliance, the desktop session's cached catalogue, or settings on another machine. Recheck after relevant client/configuration/wiring changes. Existing sessions may need a refresh/restart; inspect their loaded skill list before assuming the new entries are available.

Claude was not found on PATH. Its links and import are prepared from official documentation and checked structurally; **Claude runtime verification remains pending**. Do not install a client or purchase a subscription merely to make a checkbox green. When available, start Claude in a fresh trusted checkout, record `claude --version`, inspect `/context all` for the imported instructions and skill metadata, and use a synthetic read-only request to check one explicitly selected skill. Record discovery separately from that behavioural result. Personal/managed configuration may override discovery; inspect it locally and keep private settings out of public evidence.

To repeat the Codex metadata check, use the installed client's generated schema, an owned disposable HOME/CODEX_HOME and a private stdio process. Send initialize and wait for its response; send initialized, then skills/list with `forceReload: true` and the root/nested `cwds`. Compare repo-scoped names, enabled flags, canonical paths and errors against the manifest. Close stdin and wait for process exit. Do not start/resume chats, send model turns, export raw startup notifications, or replace a live user's home/config. A bare `skills/list` pass is deliberately narrower than saying “the agent followed the skill.”

## Focused work behind one point of contact

Keep a run focused on a coherent outcome. Reuse the existing ticket/PR or handoff for: accepted goal/criteria, exclusions, source/base and working branch, relevant files, selected skills, verification expectations, known gaps and next action. Include only necessary evidence, not the full history of unrelated tickets. For an ordinary continuation, retain useful context; when a task truly branches, use a separately authorized chat or bounded worker with this handoff. A worktree isolates edits, not conversation context. One user-facing Jarvis thread can eventually coordinate these focused runs without forwarding all company history. No new chat, delegation topology or automated routing is enabled by this document.

Before unattended execution, define the allowed actions/targets, completion evidence, result destination and an actual supported time/turn/spend limit. Record the enforcing control; prompt wording is not enforcement. If such a limit is unavailable, keep the run attended or obtain an explicit bounded alternative. Pause dependent work on an unresolved contract or after repeated attempts produce no new evidence; preserve failures and state the next decision. Do not silently broaden permissions or keep spending to manufacture a success claim.

## Checks and review

Use focused tests while developing and the existing full gate before review for code changes. Inspect the resulting behaviour and actual test inventory. A documentation-only edit needs relevant link/content checks; CI remains unchanged except for the cheap structural skill check. Do not add a full-suite hook after every edit or conversation turn. Runtime authority constraints and remaining production gates are still described in [the authority guide](authority-boundaries-49.md).

The owner selected the **next meaningful change** for the fresh-reviewer pilot. Supply accepted criteria, exact base/head diff, necessary surrounding code and raw verification evidence in a fresh context; omit the implementer's rationale and expected findings. Default to read-only review and require actionable trigger/consequence/location for correctness findings. A reviewer need not be another provider and cannot replace tests or owner acceptance. Record findings, dispositions and remaining gaps; do not invent style defects or treat model agreement as proof. This setup change has no independent reviewer result.

The subsequent performance-evidence feature from PR #68 supplied the meaningful
change for this pilot. On 17 November 2026, after the owner's requested merge,
a fresh Codex reviewer received the accepted criteria, immutable base/head,
surrounding code and raw verification evidence without the implementer's chat
history, PR rationale or explanatory reports. It reported two P2 evidence-
qualification gaps; one was reproduced with a source-compiled offline harness
and then independently confirmed through the ordinary quality CLI. The
[retained pilot record](../../evaluations/fresh-review-51-2026-11-17/REPORT.md)
contains the supplied context boundary, actual review output, reproduction and
dispositions. The gaps remain work under #47, not silently marked fixed by a
successful review. This was a post-merge review, not a pre-merge gate, and does
not replace the owner's acceptance.

## Minimal delivery observations

Keep these in the existing PR/evidence record when useful; no separate metrics dashboard or mandatory new file is required:

| Observation | Record honestly |
| --- | --- |
| Time to reviewable result | Measured start/end and scope; distinguish active work, tool/CI waiting and user waiting where available. |
| Verification | Checks, elapsed time if measured, tested artifact and outcome; planned commands are not execution. |
| Human review effort | Owner-supplied time/feedback; unknown until supplied. |
| Rework | Concrete correction and cause, such as misunderstood scope or discovered defect; avoid judging by lines changed. |
| Escaped defects | Defects found after acceptance within a stated observation window; no observation is not zero defects. |
| Usage and cost | Actual provider counters/billing when available; do not convert subscription usage into an invented per-request price. |

For #51, discovery found a concrete missing setup: zero repository skills before wiring, 14 afterwards. Human review time, escaped defects, provider cost and comparative productivity are not measured. During implementation, an incorrect relative-link depth and directory URL trailing-slash comparison were corrected before final verification; regression coverage now checks actual reads through both providers and rejects wrong/external targets. There is no claim that this change made a model more accurate or reduced delivery time.

## Sources and remaining work

Rechecked official [Codex best practices](https://learn.chatgpt.com/guides/best-practices), [Codex skill discovery](https://learn.chatgpt.com/docs/build-skills), [Claude best practices](https://code.claude.com/docs/en/best-practices), [Claude skills](https://code.claude.com/docs/en/skills) and [Claude project instructions](https://code.claude.com/docs/en/memory). External text informed original repository guidance; no upstream script or hook was imported or executed. Skill metadata bodies remain unchanged.

The accepted #51 setup scope (AC1–7) and fresh-reviewer pilot (AC8) now have
recorded evidence. The conditional Claude runtime exercise remains deferred
until that client is available, as already accepted for AC3; no runtime pass is
claimed and no client was installed. #47 tracks the two review findings.
Ticket #54 shared this real-feature exercise for its traceability pilot, avoiding
a duplicate project. One pilot does not establish lower costs, faster delivery,
general model compliance or a production coordination capability.
