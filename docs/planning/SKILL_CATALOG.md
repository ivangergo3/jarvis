# Skill catalogue

68 focused skills: 19 P0 foundations, 25 P1 delivery capabilities and 24 P2 expansion capabilities. One agent can use multiple skills, and any skill can be used without a fixed team. This is a definition/review catalogue, not an installed-agent configuration.

Read [boundaries](SKILL_BOUNDARIES.md), [local-use safety](SKILL_SAFETY.md) and the [review guide](SKILL_REVIEW_GUIDE.md). The [machine-readable catalogue](skill-catalog.json) records current file hashes and ticket mappings. Evaluation evidence identifies its own tested hashes; a later edit does not inherit an earlier pass.

## P0

| ID | Capability | Use when | Ticket |
| --- | --- | --- | --- |
| S01a | [Mission briefing](../../skills/mission-briefing/SKILL.md) | Turn a requested outcome into a bounded mission brief before planning work. Use when scope, constraints, or decision authority need agreement. | [#4](https://github.com/ivangergo3/jarvis/issues/4) |
| S01b | [Acceptance criteria](../../skills/acceptance-criteria/SKILL.md) | Define observable acceptance criteria for a feature, deliverable, or mission. Use when success needs to be testable without prescribing the implementation. | [#5](https://github.com/ivangergo3/jarvis/issues/5) |
| S02a | [Option analysis](../../skills/option-analysis/SKILL.md) | Compare concrete approaches and recommend a choice when meaningful technical, product, or commercial tradeoffs exist. | [#6](https://github.com/ivangergo3/jarvis/issues/6) |
| S02b | [Work prioritisation](../../skills/work-prioritisation/SKILL.md) | Order candidate work against an agreed objective, capacity, dependencies, and uncertainty. | [#7](https://github.com/ivangergo3/jarvis/issues/7) |
| S03a | [Task decomposition](../../skills/task-decomposition/SKILL.md) | Break an agreed mission into bounded assignments that can be completed and reviewed. Use without requiring any particular agent topology. | [#8](https://github.com/ivangergo3/jarvis/issues/8) |
| S03b | [Dependency planning](../../skills/dependency-planning/SKILL.md) | Identify prerequisites, safe concurrency, and revalidation needs across planned tasks or deliverables. | [#9](https://github.com/ivangergo3/jarvis/issues/9) |
| S03c | [Work handoffs](../../skills/work-handoffs/SKILL.md) | Prepare or assess a handoff between tasks, people, or agent runs with sufficient context and precise delivery state. | [#10](https://github.com/ivangergo3/jarvis/issues/10) |
| S04a | [Source assessment](../../skills/source-assessment/SKILL.md) | Find and assess sources for a specific question, including currency, authority, provenance, and relevance. | [#11](https://github.com/ivangergo3/jarvis/issues/11) |
| S04b | [Evidence synthesis](../../skills/evidence-synthesis/SKILL.md) | Synthesise supplied or retrieved evidence into findings relevant to a question or decision. | [#12](https://github.com/ivangergo3/jarvis/issues/12) |
| S05a | [Project context curation](../../skills/project-context-curation/SKILL.md) | Prepare or maintain a concise project context record from verified decisions and current evidence. | [#13](https://github.com/ivangergo3/jarvis/issues/13) |
| S05b | [Decision recording](../../skills/decision-recording/SKILL.md) | Capture an explicit decision, its rationale, scope, and consequences without confusing proposals with agreements. | [#14](https://github.com/ivangergo3/jarvis/issues/14) |
| S06a | [Delivery risk assessment](../../skills/delivery-risk-assessment/SKILL.md) | Assess correctness and delivery risks for a bounded change or mission to guide review and verification effort. | [#15](https://github.com/ivangergo3/jarvis/issues/15) |
| S06b | [Verification planning](../../skills/verification-planning/SKILL.md) | Plan proportionate verification from acceptance criteria and credible risks before claiming a deliverable is ready. | [#16](https://github.com/ivangergo3/jarvis/issues/16) |
| S07a | [Metric definition](../../skills/metric-definition/SKILL.md) | Define a business or product metric precisely before collecting, comparing, or interpreting numbers. | [#17](https://github.com/ivangergo3/jarvis/issues/17) |
| S07b | [Unit economics analysis](../../skills/unit-economics-analysis/SKILL.md) | Analyse acquisition cost, customer value, margin, and payback using explicitly defined metrics and available evidence. | [#18](https://github.com/ivangergo3/jarvis/issues/18) |
| S07c | [Concept coaching](../../skills/concept-coaching/SKILL.md) | Explain an unfamiliar concept in the context of the user’s current decision, especially while they learn marketing and business. | [#19](https://github.com/ivangergo3/jarvis/issues/19) |
| S08a | [Customer segmentation](../../skills/customer-segmentation/SKILL.md) | Identify and compare candidate customer segments for a product or offer using evidence and practical access. | [#20](https://github.com/ivangergo3/jarvis/issues/20) |
| S08b | [Customer problem validation](../../skills/customer-problem-validation/SKILL.md) | Assess evidence for a customer problem and identify a suitable next validation step before committing to a solution. | [#21](https://github.com/ivangergo3/jarvis/issues/21) |
| S08c | [Product positioning](../../skills/product-positioning/SKILL.md) | Draft evidence-based positioning for a defined product and audience before writing campaign assets. | [#22](https://github.com/ivangergo3/jarvis/issues/22) |

## P1

| ID | Capability | Use when | Ticket |
| --- | --- | --- | --- |
| S09a | [Technical design](../../skills/technical-design/SKILL.md) | Design a bounded software change from accepted requirements and existing interfaces before implementation. | [#23](https://github.com/ivangergo3/jarvis/issues/23) |
| S09b | [Architecture assessment](../../skills/architecture-assessment/SKILL.md) | Assess an existing software architecture against concrete change scenarios and quality constraints without prescribing a rewrite. | [#23](https://github.com/ivangergo3/jarvis/issues/23) |
| S10a | [Software implementation](../../skills/software-implementation/SKILL.md) | Implement an authorized, bounded code change in an existing repository and verify its behaviour. | [#24](https://github.com/ivangergo3/jarvis/issues/24) |
| S10b | [Defect diagnosis](../../skills/defect-diagnosis/SKILL.md) | Investigate a reproducible software failure and distinguish supported causes from hypotheses before choosing a fix. | [#24](https://github.com/ivangergo3/jarvis/issues/24) |
| S11a | [Test design](../../skills/test-design/SKILL.md) | Derive meaningful test conditions and oracles from agreed behaviour, risks and interfaces. | [#25](https://github.com/ivangergo3/jarvis/issues/25) |
| S11b | [Test automation](../../skills/test-automation/SKILL.md) | Implement automated checks for agreed test conditions using the existing framework and isolated data. | [#25](https://github.com/ivangergo3/jarvis/issues/25) |
| S11c | [Test maintenance](../../skills/test-maintenance/SKILL.md) | Diagnose failing or flaky tests and restore useful coverage without weakening the behavioural contract. | [#25](https://github.com/ivangergo3/jarvis/issues/25) |
| S12 | [Code review](../../skills/code-review/SKILL.md) | Review a specific code diff for actionable defects, regressions and relevant maintainability risks. | [#26](https://github.com/ivangergo3/jarvis/issues/26) |
| S13a | [Exploratory testing](../../skills/exploratory-testing/SKILL.md) | Explore a bounded user journey with adaptive charters and record observations beyond scripted checks. | [#27](https://github.com/ivangergo3/jarvis/issues/27) |
| S13b | [Defect reproduction](../../skills/defect-reproduction/SKILL.md) | Turn a reported failure into a minimal reproducible record and distinguish intermittent or unconfirmed behaviour. | [#27](https://github.com/ivangergo3/jarvis/issues/27) |
| S13c | [Acceptance verification](../../skills/acceptance-verification/SKILL.md) | Assess a specific deliverable against accepted criteria using observed evidence and explicit gaps. | [#27](https://github.com/ivangergo3/jarvis/issues/27) |
| S14a | [Pull request preparation](../../skills/pull-request-preparation/SKILL.md) | Prepare a scoped, reviewable pull request description and inspect the exact patch for publication readiness. | [#28](https://github.com/ivangergo3/jarvis/issues/28) |
| S14b | [Delivery reporting](../../skills/delivery-reporting/SKILL.md) | Report what a bounded task delivered, what was actually verified and what remains unresolved. | [#28](https://github.com/ivangergo3/jarvis/issues/28) |
| S15a | [Offer design](../../skills/offer-design/SKILL.md) | Define a clear commercial offer from customer evidence, deliverable constraints and supplied economics. | [#29](https://github.com/ivangergo3/jarvis/issues/29) |
| S15b | [Landing page copy](../../skills/landing-page-copy/SKILL.md) | Write or revise landing-page copy for a defined audience, supported offer and intended next action. | [#29](https://github.com/ivangergo3/jarvis/issues/29) |
| S15c | [Lifecycle email writing](../../skills/lifecycle-email-writing/SKILL.md) | Draft customer lifecycle emails tied to a known product event and recipient state, separate from cold outreach. | [#29](https://github.com/ivangergo3/jarvis/issues/29) |
| S16a | [Personal brand strategy](../../skills/personal-brand-strategy/SKILL.md) | Define a personal publishing direction from the author\u2019s supplied experience, goals and disclosure preferences. | [#30](https://github.com/ivangergo3/jarvis/issues/30) |
| S16b | [Content ideation](../../skills/content-ideation/SKILL.md) | Develop grounded post or short-video ideas from real notes, experiences and reader questions. | [#30](https://github.com/ivangergo3/jarvis/issues/30) |
| S16c | [Personal content writing](../../skills/personal-content-writing/SKILL.md) | Draft or edit personal posts and short scripts in an author-approved voice using supported experiences. | [#30](https://github.com/ivangergo3/jarvis/issues/30) |
| S17a | [Account research](../../skills/account-research/SKILL.md) | Research an organization\u2019s relevant business context using appropriate public or explicitly supplied sources. | [#31](https://github.com/ivangergo3/jarvis/issues/31) |
| S17b | [Prospect qualification](../../skills/prospect-qualification/SKILL.md) | Assess an account against explicit fit criteria while keeping unknowns distinct from negative evidence. | [#31](https://github.com/ivangergo3/jarvis/issues/31) |
| S18a | [Cold outreach writing](../../skills/cold-outreach-writing/SKILL.md) | Draft a relevant first-contact business message from verified context and a supported offer. | [#32](https://github.com/ivangergo3/jarvis/issues/32) |
| S18b | [Follow up writing](../../skills/follow-up-writing/SKILL.md) | Draft a context-aware follow-up from an actual conversation or authorized sequence state. | [#32](https://github.com/ivangergo3/jarvis/issues/32) |
| S19a | [Marketing claims review](../../skills/marketing-claims-review/SKILL.md) | Review marketing or sales copy for substantiated claims, truthful presentation and relevant disclosure gaps. | [#33](https://github.com/ivangergo3/jarvis/issues/33) |
| S19b | [Conversion journey review](../../skills/conversion-journey-review/SKILL.md) | Assess a customer journey for clarity, friction and offer continuity using observed steps and evidence. | [#33](https://github.com/ivangergo3/jarvis/issues/33) |

## P2

| ID | Capability | Use when | Ticket |
| --- | --- | --- | --- |
| S20a | [Customer interview planning](../../skills/customer-interview-planning/SKILL.md) | Prepare a customer research interview that tests a learning question without leading the participant. | [#34](https://github.com/ivangergo3/jarvis/issues/34) |
| S20b | [Research evidence capture](../../skills/research-evidence-capture/SKILL.md) | Turn supplied research notes into traceable, minimally identifying observations without changing their meaning. | [#34](https://github.com/ivangergo3/jarvis/issues/34) |
| S20c | [Feedback synthesis](../../skills/feedback-synthesis/SKILL.md) | Synthesize customer feedback into supported themes while retaining dissent, context and sampling limits. | [#34](https://github.com/ivangergo3/jarvis/issues/34) |
| S21a | [Funnel analysis](../../skills/funnel-analysis/SKILL.md) | Analyze progression through defined customer journey stages using comparable cohorts and reliable denominators. | [#35](https://github.com/ivangergo3/jarvis/issues/35) |
| S21b | [Growth experiment design](../../skills/growth-experiment-design/SKILL.md) | Design a bounded growth experiment with a testable hypothesis, decision rule and customer-protection guardrails. | [#35](https://github.com/ivangergo3/jarvis/issues/35) |
| S21c | [Growth experiment analysis](../../skills/growth-experiment-analysis/SKILL.md) | Read out a growth experiment against its predeclared design and distinguish evidence from exploratory signals. | [#35](https://github.com/ivangergo3/jarvis/issues/35) |
| S22a | [Search intent research](../../skills/search-intent-research/SKILL.md) | Research searcher intent and relevant topic opportunities using current search evidence and real capabilities. | [#36](https://github.com/ivangergo3/jarvis/issues/36) |
| S22b | [Seo content planning](../../skills/seo-content-planning/SKILL.md) | Plan useful search-oriented content briefs from intent evidence, existing content and supported expertise. | [#36](https://github.com/ivangergo3/jarvis/issues/36) |
| S22c | [Technical seo review](../../skills/technical-seo-review/SKILL.md) | Review technical search discoverability for a bounded set of pages using verifiable crawl, render and indexing evidence. | [#36](https://github.com/ivangergo3/jarvis/issues/36) |
| S23a | [Paid campaign planning](../../skills/paid-campaign-planning/SKILL.md) | Prepare a bounded paid-acquisition campaign proposal with truthful creative hypotheses and explicit spending limits. | [#37](https://github.com/ivangergo3/jarvis/issues/37) |
| S23b | [Campaign measurement planning](../../skills/campaign-measurement-planning/SKILL.md) | Define paid-campaign measurement, reconciliation and validation before relying on attributed performance. | [#37](https://github.com/ivangergo3/jarvis/issues/37) |
| S23c | [Paid campaign analysis](../../skills/paid-campaign-analysis/SKILL.md) | Analyze campaign results against compatible business outcomes, cost scope and attribution limitations. | [#37](https://github.com/ivangergo3/jarvis/issues/37) |
| S24a | [Sales call preparation](../../skills/sales-call-preparation/SKILL.md) | Prepare a sales conversation around known customer context, unresolved fit questions and truthful offer limits. | [#38](https://github.com/ivangergo3/jarvis/issues/38) |
| S24b | [Objection analysis](../../skills/objection-analysis/SKILL.md) | Analyze a customer objection and prepare a truthful response or learning question without pressuring a poor-fit buyer. | [#38](https://github.com/ivangergo3/jarvis/issues/38) |
| S24c | [Pipeline hygiene](../../skills/pipeline-hygiene/SKILL.md) | Review sales pipeline records for stale, inconsistent or unsupported state and propose precise corrections. | [#38](https://github.com/ivangergo3/jarvis/issues/38) |
| S25a | [Onboarding design](../../skills/onboarding-design/SKILL.md) | Design a customer onboarding path toward a verified first useful outcome with clear prerequisites and recovery. | [#39](https://github.com/ivangergo3/jarvis/issues/39) |
| S25b | [Support response preparation](../../skills/support-response-preparation/SKILL.md) | Prepare an accurate support reply and diagnostic next steps from a customer\u2019s report and verified product knowledge. | [#39](https://github.com/ivangergo3/jarvis/issues/39) |
| S25c | [Retention analysis](../../skills/retention-analysis/SKILL.md) | Analyze customer retention or churn using explicit cohorts, activity definitions and observation windows. | [#39](https://github.com/ivangergo3/jarvis/issues/39) |
| S26a | [Release planning](../../skills/release-planning/SKILL.md) | Prepare a release decision and rollout plan from an exact artifact, compatibility risks and verified readiness evidence. | [#40](https://github.com/ivangergo3/jarvis/issues/40) |
| S26b | [Deployed verification](../../skills/deployed-verification/SKILL.md) | Verify a specified deployed artifact and critical user journey within an explicitly permitted environment. | [#40](https://github.com/ivangergo3/jarvis/issues/40) |
| S26c | [Incident diagnosis](../../skills/incident-diagnosis/SKILL.md) | Assess an operational incident from scoped telemetry and build a supported timeline and impact hypothesis. | [#40](https://github.com/ivangergo3/jarvis/issues/40) |
| S26d | [Recovery planning](../../skills/recovery-planning/SKILL.md) | Prepare a reversible recovery or restoration plan with explicit preconditions, data risks and verification. | [#40](https://github.com/ivangergo3/jarvis/issues/40) |
| S27a | [Portable skill authoring](../../skills/portable-skill-authoring/SKILL.md) | Create or revise a focused reusable skill from real tasks while separating personal context, project rules and execution authority. | [#41](https://github.com/ivangergo3/jarvis/issues/41) |
| S27b | [Skill evaluation](../../skills/skill-evaluation/SKILL.md) | Evaluate a specific skill version on realistic tasks and record actual outcomes, failure modes and narrow improvements. | [#41](https://github.com/ivangergo3/jarvis/issues/41) |
