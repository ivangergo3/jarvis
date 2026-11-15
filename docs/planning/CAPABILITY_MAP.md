# Jarvis capability map

Status: 15 November 2026. The full P0/P1/P2 skill library is defined for consolidated review; agent organisation and app implementation remain separate decisions. See the [skill catalogue](SKILL_CATALOG.md) and [evaluation record](../../evaluations/library-2026-11-15/REPORT.md).

Jarvis should help a solo founder run a small company through one conversation. It should turn agreed outcomes into coordinated work, preserve decisions, make progress and evidence visible, and involve the founder in meaningful decisions.

## Founder involvement

The owner controls priorities, technical direction and delegated authority, and may select hands-on validation. Deliverables should include enough evidence for those decisions. Business explanations should support informed decisions without requiring a fixed level of prior knowledge.

## Company capabilities

| Capability | Intended outcome | Typical deliverables |
| --- | --- | --- |
| Company direction | Choose outcomes and balance product and commercial work | Objectives, priorities, decision records |
| Work coordination | Convert outcomes into bounded work and manage dependencies and blockers | Mission brief, task plan, handoff, progress report |
| Product and customers | Understand problems and decide what to build | Research synthesis, interview guide, feature brief |
| Engineering and delivery | Design, implement, review, verify, and release software | Technical proposal, PR, test evidence, release report |
| Marketing and positioning | Establish whom the product serves, its value, and how to explain the offer | Segment definition, positioning, product copy |
| Personal brand and content | Share useful experiences in the founder’s voice | Post ideas, drafts, video scripts, content plan |
| Sales and relationships | Find relevant prospects and develop opportunities | Prospect brief, outreach draft, call preparation, pipeline record |
| Growth and measurement | Understand performance and run measurable experiments | Metric definitions, economics analysis, experiment readout |
| Customer success and operations | Help customers succeed and keep the product dependable | Onboarding guide, support response, incident report |
| Knowledge and improvement | Preserve useful context and improve repeatable work | Context records, playbooks, evaluated skills, lessons learned |

## Current app and future coordination

The native SwiftUI app provides project/chat observation, a graph and card view, a companion conversation panel, and a linked Codex queue/history path. Most visible team nodes currently represent chats. The central Jarvis view does not establish autonomous coordination.

Future coordination needs durable missions, tasks, execution attempts, artifact versions, reviews, decisions, and authority. A completed chat turn is not proof that a mission succeeded. Connection health and task state must remain distinct. Existing linked chats do not automatically become Jarvis-owned workers.

Preserve the current native appearance, graph and accessible list alternatives, and read-only observation adapter. The engineering requirements in [REQUIREMENTS.md](../../REQUIREMENTS.md) still govern future app changes. This plan does not implement or authorize those changes.

## First workflow candidates

Engineering: agreed feature brief → technical decision → implementation → independent review when warranted → verification → PR and evidence.

Commercial: audience and problem brief → positioning → landing-page or outreach draft → review → measurement proposal.

These are evaluation examples, not fixed pipelines or agent assignments. A task may combine skills or use a simpler sequence when appropriate. External publication, sending, spending, and production changes follow the authority granted for the particular assignment.

## Planning sequence

1. Maintain this capability map and the [skill backlog](SKILL_BACKLOG.md).
2. Define and evaluate focused skill building blocks.
3. Review the complete skill library, then refine composition through bounded real assignments.
4. Design agent execution and independence from demonstrated needs.
5. Plan bounded app implementation separately.

See [skill boundaries](SKILL_BOUNDARIES.md) for the composition rules and [skill evaluation](SKILL_EVALUATION.md) for acceptance of definitions.
