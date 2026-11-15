# Skill research and authoring decisions

Research date: 15 November 2026. External skills were inspected as untrusted text for ideas and failure modes. No external skill package, helper, installer, hook or dependency was imported or executed. The definitions in `skills/` are original instructions written around the existing backlog. This was a selective review, not an audit of every file in those repositories.

## Sources inspected

| Source | What informed this library | Deliberate limit |
| --- | --- | --- |
| [Marketing Skills catalogue](https://github.com/coreyhaines31/marketingskills/tree/1f837447b20bb6f0e72d87b80ece1c221c362c7d/skills) | Useful discovery categories for marketing capabilities. | Catalogue breadth does not expand the agreed backlog. No downloaded package or tools registry. |
| [Cold email skill](https://github.com/coreyhaines31/marketingskills/blob/1f837447b20bb6f0e72d87b80ece1c221c362c7d/skills/cold-email/SKILL.md) | Consider relevance and recipient state separately from prose quality. | Our drafting skills do not run outbound, prescribe sender domains or treat a cadence as universally appropriate. |
| [Ads skill](https://github.com/coreyhaines31/marketingskills/blob/1f837447b20bb6f0e72d87b80ece1c221c362c7d/skills/ads/SKILL.md) | Consider measurement quality, attribution and bounded learning before campaign decisions. | No imported platform playbooks, scale rules, benchmark claims or automatic contact actions. |
| [SEO audit skill](https://github.com/coreyhaines31/marketingskills/blob/1f837447b20bb6f0e72d87b80ece1c221c362c7d/skills/seo-audit/SKILL.md) | Distinguish fetch evidence from rendered-page evidence. | Do not inherit universal SEO checklists or treat a ranking hypothesis as a confirmed technical defect. |
| [Anthropic webapp testing example](https://github.com/anthropics/skills/blob/1780c5e5a552fd4d1c9d6a7b0cab26b0c2bef064/skills/webapp-testing/SKILL.md) | Observe the interface before choosing interactions. | No bundled server helper or mandatory browser/runtime. Unfamiliar code is inspected before execution, including `--help`. |
| [Superpowers debugging](https://github.com/obra/superpowers/blob/22f0b463e7a5e579904dd6211a520321035526f7/skills/systematic-debugging/SKILL.md) and [verification](https://github.com/obra/superpowers/blob/22f0b463e7a5e579904dd6211a520321035526f7/skills/verification-before-completion/SKILL.md) | Separate hypotheses from observations and tie completion claims to evidence. | No mandatory role graph, sibling imports, repeated checks without cause, or rigid prohibition on justified incident mitigation. |

The supplied marketing repository was read through the connected GitHub reader. An initial `paid-ads` lookup returned 404; the inspected current entry is `ads`. Repository SHAs record the observed revisions; web/provider caches can have different fetch times. These sources are inspiration, not runtime dependencies or endorsements of every recommendation. No copied source prose or scripts require vendoring into this library.

## Primary references checked

- [Agent Skills specification](https://agentskills.io/specification): portable folder/frontmatter conventions. The library uses name and description without tool-grant metadata or automatic-install machinery.
- [Playwright best practices](https://playwright.dev/docs/best-practices): observable behaviour and isolated tests. These principles inform framework-neutral testing instructions rather than requiring Playwright for every project.
- [Google Search Central starter guide](https://developers.google.com/search/docs/fundamentals/seo-starter-guide): useful content and search discoverability; the skills require current official guidance for platform-specific conclusions rather than freeze ranking folklore into instructions.
- [OWASP prompt injection guidance](https://genai.owasp.org/llmrisk/llm01-prompt-injection/): untrusted retrieved content and consequential tool use require boundaries beyond prompt wording. The library states that runtime enforcement remains necessary.

## Original design choices

The unit is a bounded capability, not a job title. Engineering separates design, implementation, diagnosis, test design, automation, maintenance, review and acceptance. Commercial work separates research, qualification, drafting, review and analysis. Operational skills separate diagnosis, recovery planning and verification. A single agent can combine any relevant subset.

All packaged skills are Markdown-only and useful when their folder is copied alone. They contain no tool installers, shell helpers, credentials, personal project facts or remote execution endpoints. They preserve already-granted authority while preventing a reference document from granting new authority. Local usage is not a promise of offline model inference: the selected runtime still controls where prompts and data are processed.
