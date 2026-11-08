# Jarvis work board

The [Team board](https://github.com/users/ivangergo3/projects/3/views/1) is the shared place to track Jarvis work. Cards represent outcomes or bounded deliverables. They do not define permanent agent roles; one executor can use several skills and work can move between executors.

## Columns

| Column | Meaning | Move onward when |
| --- | --- | --- |
| Backlog | Proposed or planned work that has not started | Scope and next action are clear enough to begin |
| In progress | Work is actively being carried out | Deliverable and applicable evidence are available |
| In review | Work and evidence are ready; review, acceptance, or merge remains | Required review is resolved and acceptance is recorded |
| Blocked | A named dependency or decision prevents meaningful progress | The blocker is resolved and the next action can proceed |
| Done | Acceptance criteria are met and the accepted deliverable is recorded | Reopen or create follow-up work if later evidence changes the outcome |

Verification can happen within In progress; In review can include checking its evidence. Add a separate testing stage later if it helps actual work. Do not move work to Done merely because an agent turn ended. For repository changes requiring merge, unmerged work belongs in In review, not Done.

## Card details

Use a plain task title. Keep stable skill IDs in the issue body and ticket index; priority is shown as a badge. P0 means foundational skill work, P1 the first delivery workflows, and P2 later expansion in the current backlog; priority is distinct from status. Revisit priority meanings as the company backlog broadens.

Record the expected result, acceptance criteria, next action, evidence links and known gaps. For blocked work, name the blocker, the person or dependency that can resolve it when known, and what will resume afterwards. Review evidence should identify the version checked. Use actual responsibility when it exists; do not invent agent assignments now.

## Current scope

The board can track future engineering, marketing and company work when authorized. This phase evaluates skills and maintains planning only. The 19 P0 tickets move to In review with their results; the 19 P1/P2 families remain in Backlog. Empty Blocked and Done columns are intentional until actual work belongs there.
