# Fresh-reviewer context supplied

17 November 2026. Fresh Codex collaboration worker with `fork_turns: none`;
no implementer conversation inherited. Model version and token/cost counters
were not exposed. The reviewer read the existing code-review skill, SHA-256
`b8f359b42798e18d0ea904232d643597e43eb6cea10654d39be59fd9083a474d`.
This is the retained context inventory; local absolute path prefixes are omitted.

- Objective: read-only #51 AC8 review. No source edits, GitHub writes, installs,
  live integrations, new profiling or full native-suite run.
- Required instructions: AGENTS.md, REQUIREMENTS.md, code-review skill.
- Exact artifact: base `bf13fa1c3940ab054a4507eecb79d6471b9ef7f0` to candidate
  `8818c8f970e149f053a001b5bdddcc27586b87a4`. Squash merge
  `45f5f2b2335bccdb5bbe878e770da30c7628c3a6` has the same reviewed source.
- Review all changed executable source, build/fixture scripts, policy/CLI,
  tests, raw numeric evidence and necessary callers/error paths.
- Exclude PR #68's description, all author `REPORT.md` explanations and
  `docs/engineering/performance-evidence-47-54.md` from initial context.
- Accepted #47 intent: representative synthetic workloads; version/environment/
  data/repetitions/spread; CPU/memory/main-thread/growth where relevant; budgets
  from evidence; correctness/cancellation/dropped/stale work; stable regressions
  and noise policy; variable benchmarks informational; no production load or
  private telemetry by default.
- Owner's advisory mean CPU budgets: Mac15,13 ARM64, 1500×940, 2×, 60 Hz,
  animations enabled; idle20 ≤5%, hover20 ≤12%, hover100 ≤20% of one core.
  Prespecified qualification: ≥80% requested cadence, foreground/visible,
  stable power, preserved selection, paired achieved rates within 10% and
  matched configuration. Direct OS-launch/input-to-photon and longer memory
  limits remain unverified.
- Raw evidence supplied: local final full-gate log; CI test summary and
  hover-fault JSON; attempt 1 failed native log and attempt 2 passing log; the
  checked-in synthetic JSON/JSON.gz performance reports. The build identity
  in those reports is `bbc38db1c3920c456ab0ebb3acd7bd5dd418be81`; later candidate
  changes affect the auditor/tests. CI's 164 tests, nine fault stages and eight
  native journeys are evidence to inspect, not proof of absence of defects.
- Requested output: supported actionable correctness findings only, with
  severity, exact verified location, trigger, consequence, reproduction,
  performed checks and limits. Explicitly report no findings if none exist.
  No expected finding or implementer rationale was supplied.

The run was attended by the user-facing coordinator. Read-only was a task
instruction, not a newly enforced tool sandbox. No autonomous team, provider
purchase or background review loop was created.
