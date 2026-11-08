# Jarvis prioritised skill backlog

Status: 8 November 2026. P0 definitions are drafts awaiting behavioural evaluation. P1 and P2 entries are candidate families to refine before authoring.

## Priorities

- P0: foundations for useful delegation, evidence, and informed business decisions.
- P1: first complete engineering, content, and sales workflows.
- P2: extend acquisition, operations, and specialised work when needed.

Priority is definition order, not authorization to execute work. Skills can be combined by one agent or used in different runs. See [boundaries](SKILL_BOUNDARIES.md).

## P0 skill definitions

The original eight families are decomposed into 19 portable skills. Family names group discovery; they do not prescribe agents.

| ID | Family | Skill | Definition status |
| --- | --- | --- | --- |
| S01a | Discovery and mission briefing | [Mission briefing](../../skills/mission-briefing/SKILL.md) | Draft; evaluation pending |
| S01b | Discovery and mission briefing | [Acceptance criteria](../../skills/acceptance-criteria/SKILL.md) | Draft; evaluation pending |
| S02a | Prioritisation and tradeoff analysis | [Option analysis](../../skills/option-analysis/SKILL.md) | Draft; evaluation pending |
| S02b | Prioritisation and tradeoff analysis | [Work prioritisation](../../skills/work-prioritisation/SKILL.md) | Draft; evaluation pending |
| S03a | Task planning and handoffs | [Task decomposition](../../skills/task-decomposition/SKILL.md) | Draft; evaluation pending |
| S03b | Task planning and handoffs | [Dependency planning](../../skills/dependency-planning/SKILL.md) | Draft; evaluation pending |
| S03c | Task planning and handoffs | [Work handoffs](../../skills/work-handoffs/SKILL.md) | Draft; evaluation pending |
| S04a | Evidence based research | [Source assessment](../../skills/source-assessment/SKILL.md) | Draft; evaluation pending |
| S04b | Evidence based research | [Evidence synthesis](../../skills/evidence-synthesis/SKILL.md) | Draft; evaluation pending |
| S05a | Decision and project knowledge management | [Project context curation](../../skills/project-context-curation/SKILL.md) | Draft; evaluation pending |
| S05b | Decision and project knowledge management | [Decision recording](../../skills/decision-recording/SKILL.md) | Draft; evaluation pending |
| S06a | Risk based quality planning | [Delivery risk assessment](../../skills/delivery-risk-assessment/SKILL.md) | Draft; evaluation pending |
| S06b | Risk based quality planning | [Verification planning](../../skills/verification-planning/SKILL.md) | Draft; evaluation pending |
| S07a | Marketing and business economics | [Metric definition](../../skills/metric-definition/SKILL.md) | Draft; evaluation pending |
| S07b | Marketing and business economics | [Unit economics analysis](../../skills/unit-economics-analysis/SKILL.md) | Draft; evaluation pending |
| S07c | Marketing and business economics | [Concept coaching](../../skills/concept-coaching/SKILL.md) | Draft; evaluation pending |
| S08a | Audience problem and positioning discovery | [Customer segmentation](../../skills/customer-segmentation/SKILL.md) | Draft; evaluation pending |
| S08b | Audience problem and positioning discovery | [Customer problem validation](../../skills/customer-problem-validation/SKILL.md) | Draft; evaluation pending |
| S08c | Audience problem and positioning discovery | [Product positioning](../../skills/product-positioning/SKILL.md) | Draft; evaluation pending |

Recommended authoring and evaluation sequence: S01a–b for outcomes, S04a–b for evidence, S05a–b for durable context, S02a–b and S03a–c for decisions/plans, S06a–b for quality, then S07a–c and S08a–c for business understanding. This is a useful starting order, not a mandatory dependency chain.

## P1 skill families

| ID | Family | Definition scope |
| --- | --- | --- |
| S09 | Technical design and architecture assessment | Compare approaches against the existing system, compatibility, operational burden, and technical decisions retained by the user. |
| S10 | Software implementation and debugging | Define focused implementation and systematic diagnosis; evaluate whether these should be separate skills. |
| S11 | Test design and automation | Derive checks from behaviour and risk; consider separate test design, automation implementation, and maintenance skills. |
| S12 | Code review | Find actionable defects with evidence and consequences; distinguish review from implementation and full security audits. |
| S13 | Exploratory and acceptance verification | Exercise user flows and report reproducible findings; consider separate exploration, reproduction, and acceptance execution skills. |
| S14 | PR preparation and delivery reporting | Prepare reviewable changes and accurate delivery evidence; consider separate PR preparation and delivery reporting skills. |
| S15 | Offer and conversion copywriting | Define offers and produce supported product copy; consider offer design, landing-page writing, and product-email writing separately. |
| S16 | Personal brand ideation and writing | Assess existing greg-content-ideas and greg-personal-brand skills for reuse. Keep personal audience and product audience distinct. |
| S17 | Prospect research and qualification | Assess fit using appropriate evidence; separate account research from qualification where useful. Research is not permission to contact. |
| S18 | Cold outreach and follow-up writing | Draft relevant outreach and follow-ups without invented familiarity. Separate message types if their inputs and quality criteria differ. |
| S19 | Marketing and sales review | Assess claims, audience relevance, voice, offer clarity, and customer journey; define distinct reviews where they add value. |

## P2 skill families

| ID | Family | Definition scope |
| --- | --- | --- |
| S20 | Customer interviews and feedback synthesis | Define interview preparation, evidence capture, and feedback synthesis with explicit provenance and bias limitations. |
| S21 | Funnels and growth experiments | Define funnel analysis, experiment design, and experiment readout as independently reusable capabilities. |
| S22 | SEO research and content planning | Define intent research, content planning, and technical SEO checks using current primary sources and real product capabilities. |
| S23 | Paid campaign planning and analysis | Define campaign briefs, measurement, budget proposals, and readouts. Execution and spending require applicable authority. |
| S24 | Sales conversations and pipeline management | Define call preparation, objection analysis, and pipeline hygiene as needed; CRM mutations remain tool operations. |
| S25 | Customer onboarding support and retention | Define onboarding guidance, support preparation, and retention analysis with distinct inputs and outputs. |
| S26 | Release and operational verification | Define release planning, deployed verification, incident diagnosis, and recovery planning; do not implement infrastructure. |
| S27 | Skill authoring and evaluation | Create a reusable first-party skill maintenance method after evaluating the initial drafts. Evaluation itself starts with P0. |

S27 remains P2 as a reusable maintenance skill. The evaluation method itself applies immediately to P0.

## Existing first party skills

S16 should assess greg-content-ideas and greg-personal-brand for reuse rather than replace their voice and source boundaries. These currently live in the founder’s local skill library and are not copied into this public repository. They are not mandatory dependencies of any P0 skill.

## GitHub tracking

The existing repository is https://github.com/ivangergo3/jarvis. The private planning board is https://github.com/users/ivangergo3/projects/3. See [ticket index](GITHUB_TICKETS.md) for the per-item links and current drafting state.
