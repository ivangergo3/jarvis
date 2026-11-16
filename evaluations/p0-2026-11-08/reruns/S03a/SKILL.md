---
name: task-decomposition
description: "Break an agreed mission into bounded assignments that can be completed and reviewed. Use without requiring any particular agent topology."
---

# Task decomposition

## Inputs

Mission brief, acceptance criteria, relevant system boundaries, and known dependencies.

## Procedure

Group work by coherent deliverable and ownership boundary. Give each task enough context, an expected output, relevant criteria, and exclusions.
Derive requirements from the current brief and explicitly linked accepted artifacts. If criteria or a schema are missing, reference that gap or label a proposed discovery check; do not turn plausible details from another task into mandatory scope.
Keep the smallest useful assignments; avoid splitting trivial edits into bureaucracy. Identify shared-file or shared-resource contention and discovery work needed before a reliable implementation estimate.
Allow one executor to handle multiple tasks or skills. Do not assign an agent per task unless separately requested.

## Output

A task breakdown with stable task references, inputs, outputs, completion checks, dependencies, and unresolved decisions.

## Boundary

Produces a plan; does not dispatch workers, select models, or start implementation.

## Composition and authority

This skill is a portable capability, not an agent role. One agent may combine it with other relevant skills. Its output can be used by a person or another run; no specific provider, framework, or sibling skill is required. Applying it does not expand the user’s authority grant.

## Evaluation

When evaluating or revising this skill, use [references/evaluation.md](references/evaluation.md). Those cases are fixtures, not instructions to execute external actions during ordinary use.
