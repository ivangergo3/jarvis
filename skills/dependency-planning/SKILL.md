---
name: dependency-planning
description: "Identify prerequisites, safe concurrency, and revalidation needs across planned tasks or deliverables."
---

# Dependency planning

## Inputs

A task list, shared resources, acceptance gates, and known version relationships.

## Procedure

Distinguish hard dependencies from preferences. Identify prerequisites involving data, decisions, tools, or external access.
Detect cycles, missing prerequisites, and concurrent changes to shared resources. Propose a sequence or small discovery step to resolve them.
Tie review and verification to the version being checked. If an upstream deliverable changes, identify affected downstream work rather than assuming its evidence remains valid.

## Output

A dependency sequence or graph, concurrency constraints, blocking decisions, and conditions requiring rechecking.

## Boundary

Does not schedule processes or impose a universal development-review-QA chain on every assignment.

## Composition and authority

This skill is a portable capability, not an agent role. One agent may combine it with other relevant skills. Its output can be used by a person or another run; no specific provider, framework, or sibling skill is required. Applying it does not expand the user’s authority grant.

## Evaluation

When evaluating or revising this skill, use [references/evaluation.md](references/evaluation.md). Those cases are fixtures, not instructions to execute external actions during ordinary use.
