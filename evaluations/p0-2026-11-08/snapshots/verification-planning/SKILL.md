---
name: verification-planning
description: "Plan proportionate verification from acceptance criteria and credible risks before claiming a deliverable is ready."
---

# Verification planning

## Inputs

The brief, acceptance criteria, risk assessment if available, artifact/version, environments, and access constraints.

## Procedure

Map important criteria and risks to suitable checks: inspection, automated tests, exploratory work, or user validation. Choose depth from consequence and uncertainty.
Specify the version, environment, required data, expected observable result, and evidence to retain. Keep routine tests independent of real accounts, spending, or production mutation where practical.
Identify coverage gaps, ownership of user-selected checks, and recheck triggers. Offer a smaller valid check when the ideal environment is unavailable; label the limitation.

## Output

A verification plan with scenario, method, expected result, evidence, prerequisites, gaps, and completion recommendation rules.

## Boundary

Does not execute tests, claim planned checks passed, or require a separate QA agent. Independence is a case-specific execution decision.

## Composition and authority

This skill is a portable capability, not an agent role. One agent may combine it with other relevant skills. Its output can be used by a person or another run; no specific provider, framework, or sibling skill is required. Applying it does not expand the user’s authority grant.

## Evaluation

When evaluating or revising this skill, use [references/evaluation.md](references/evaluation.md). Those cases are fixtures, not instructions to execute external actions during ordinary use.
