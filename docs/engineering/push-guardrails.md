# Small PRs, independent review and local verification (#52 / #55 / #57)

One coherent behaviour per PR, at most **1,000 added plus deleted text lines**
from the merge base with main. This is a ceiling, not a target. Tests, docs and
generated/evidence text count; renames are counted as deletion plus addition.
Warnings start at 800. Binary assets are reported separately and require owner
inspection. Split an oversized change; no automatic exception or hidden exclusion.

## Workflow

1. Once per checkout: `bash scripts/install-hooks.sh`. Existing custom hooks are
   preserved by refusing installation; integrate explicitly rather than overwrite.
2. Stage new files and run `swift run quality-gate push size` during development.
   Pre-commit checks the entire staged PR, not merely the most recent commit.
3. Write a short intended outcome and acceptance checklist to a local file. Commit
   a candidate, then `bash scripts/prepare-push.sh --intent-file=/path/to/checklist`.
   It fetches main, creates an owned detached verification worktree,
   launches an independent ephemeral read-only `codex exec`, validates its structured
   result and runs the checks selected for the cumulative diff. No implementation conversation is forwarded.
   The reviewer gets exact base/head, project requirements, changed files and
   necessary callers. Review must explicitly report completion; an incomplete or
   blocked review cannot approve even with no findings. All actionable findings block; optional preferences should
   not be manufactured as findings. Review unknowns remain in `limitations`.
4. Fix findings, commit and repeat. No evidence is reused across a changed
   head/base/Swift or Xcode identity/SDK configuration. An unchanged verified candidate
   can reuse its receipt. Do not edit while checks run.
5. Push one branch to origin. Pre-push refreshes main and verifies the outgoing
   SHA, clean tree, size, whitespace, added-secret scan and exact review/check receipt. Missing,
   failed, malformed or stale evidence blocks. Tags, branch deletion and direct
   main pushes are outside this workflow and blocked by the local hook.
6. Required GitHub checks independently run the complete PR size/secret checks,
   whitespace and the applicable app checks before merge. Owner approves
   the behaviour using the short acceptance checklist; no auto-merge is enabled.

A PR that changes only ordinary Markdown under `docs/` or the root `README.md`
gets the same independent local review and basic diff checks. App tests, builds,
formatter setup and native UI runs are skipped locally and in CI. The required
GitHub job still reports its result. Agent instructions (AGENTS, CLAUDE and SKILL
Markdown files), the reviewer's `docs/engineering/push-guardrails.md`, hidden
paths, binary assets, executable files and symlinks take the full route. A
mixed PR takes the full route even if its last commit only changes prose.

The installed CLI supports `--ephemeral`, `--ignore-user-config`, `--sandbox
read-only`, `--output-schema` and `--output-last-message`. The child uses existing
Codex authentication and model usage; no API key/provider/service is installed.
It does not inherit this chat or user-configured connectors. It may read project
instructions; minimal context is not an isolation or prompt-injection guarantee.
Review infrastructure is Swift; Bash only wires commands/hooks.

## Verification and limits

`scripts/check.sh` includes formatting, strict concurrency, architecture/authority/
skill gates, all discovered and required tests, Release build, bundle resources/
signature and seeded hover regression probes. Failures, skips, zero tests and
timeouts cannot create a receipt. With full Xcode, prepare additionally runs native
UI verification. CLT-only machines record that native UI is unavailable; required
CI must supply it, never a fabricated local pass. CPU benchmarks stay advisory.

Receipts/reviewer output/logs stay under ignored `.build/push-gate/<head>/`; attempts
have separate directories so retries preserve failed logs. Review and tests run
against the detached candidate, with only the pinned formatter cache shared;
successful worktrees are removed and nested test diagnostics retained. Failed
candidate worktrees remain in their attempt directory: inspect the retained
process/command diagnostics and confirm all workers stopped before explicitly
removing an owned failed worktree with `git worktree remove`. Do not
commit them or expose private context. Read diagnostics when blocked. The secret
scan catches common private-key/API-token forms in added text and outgoing commit
patches/messages, including secrets later removed before pushing; it does not prove
absence of confidential data. Model review and passing tests do not guarantee
correctness. UI changes need the owner's relevant app check, and sensitive changes
(permissions, execution, sends, credentials, destruction, dependencies or weakened
gates) must be called out for explicit owner approval before merge.

Git hooks and local JSON receipts are cooperative workflow controls, not tamper-
proof attestations. A local user can bypass them; remote required checks remain
independent. Main already requires the macOS check, up-to-date branches, PR flow
and administrator enforcement; force pushes/deletion are disabled. No extra
human GitHub reviewer is required for this solo project, and agent reviews are
not represented as GitHub human approvals.

## Acceptance and regression contract

- #52: fresh read-only review of exact base/head; findings or invalid output block.
- #55: exact-candidate local tests and real pre-push validation; stale/missing,
  failed or changed-during-check evidence cannot pass. Existing hooks survive setup.
- #57: cumulative 1,000-line block / 800-line agent warning, no path exemptions;
  secret check; direct-main/ref restrictions; required CI preserved.
- Synthetic native Swift tests exercise boundary sizes, deletion/rename/binary
  counts, secret detection, missing/stale/failed evidence, review failure, test
  failure, candidate mutation and a successful review → tests → verify path.
  Test doubles never contact a model or production; one actual fresh review and
  full local run qualify this implementation before its first push.
