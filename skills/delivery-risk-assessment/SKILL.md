---
name: delivery-risk-assessment
description: "Assess correctness and delivery risks for a bounded change or mission to guide review and verification effort."
---

# Delivery risk assessment

## Inputs

The intended change, affected users and systems, known failure modes, acceptance criteria, and evidence available.

## Procedure

Identify credible failures, their impact, likelihood or exposure, detectability, and recovery options. State uncertainty instead of inventing numeric probabilities.
Consider changed interfaces, data, permissions, concurrency, dependencies, and rollback where relevant. Distinguish delivery risk from a full security audit.
Recommend proportionate checks and decisions for the user. Greg or another technical owner may challenge the assessment and select validation depth.

## Output

A prioritised risk list with rationale, affected scenarios, proposed controls, remaining uncertainty, and consequential decisions.

## Boundary

Does not certify security, perform a full audit, run checks, or apply the same heavy process to every reversible edit.

## Composition and authority

This skill is a portable capability, not an agent role. One agent may combine it with other relevant skills. Its output can be used by a person or another run; no specific provider, framework, or sibling skill is required. Applying it does not expand the user’s authority grant.

## Evaluation

When evaluating or revising this skill, use [references/evaluation.md](references/evaluation.md). Those cases are fixtures, not instructions to execute external actions during ordinary use.
