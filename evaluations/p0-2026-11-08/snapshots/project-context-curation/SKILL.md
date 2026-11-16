---
name: project-context-curation
description: "Prepare or maintain a concise project context record from verified decisions and current evidence."
---

# Project context curation

## Inputs

The project identity, existing context record if any, source artifacts, and authorized destination when persistence is requested.

## Procedure

Separate durable product facts, current operational state, decisions, assumptions, and historical notes. Preserve provenance and as-of date for facts likely to change.
Resolve conflicts using explicit user decisions and direct current evidence; retain an unresolved conflict visibly when the answer is not established. Retire superseded claims without silently rewriting history.
Keep private information scoped to its intended audience. If only a draft is requested, return it; if saving is authorized, update the intended record and verify the write.

## Output

A compact context record with sources, dates where material, unresolved conflicts, and pointers to detailed artifacts.

## Boundary

Does not infer current deployment, authorization, or product availability from an old plan; portable skill instructions contain no private project facts.

## Composition and authority

This skill is a portable capability, not an agent role. One agent may combine it with other relevant skills. Its output can be used by a person or another run; no specific provider, framework, or sibling skill is required. Applying it does not expand the user’s authority grant.

## Evaluation

When evaluating or revising this skill, use [references/evaluation.md](references/evaluation.md). Those cases are fixtures, not instructions to execute external actions during ordinary use.
