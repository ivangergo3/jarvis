# Synthetic TypeScript exercise

Work only in a disposable copy of this case. Use the supplied local Node, Zod and package links. The runner can execute TypeScript directly. No installation, real account or app launch is required. None of the operations should reach an external service.

## Implementation and automation

1. `apps/server/src/submit.ts` must dispatch only supported, valid requests for an owned project/session pair. Return `invalid` for malformed data before looking up ownership, `denied` for an inaccessible destination and `accepted` after dispatch. Use the public schema. Implement this change and provide runnable regression cases.
2. `apps/client/src/view.ts` shows a selected conversation. The selector supplies stable identifiers. The rendered message must belong to the most recently opened conversation even if two reads finish in the opposite order. Test that behavior at the public `select` entry, then implement the repair. Use deterministic inputs and no network or clock sleeps.

Report the checks you ran and what their output establishes.

## Read-only review

Separately review a proposed one-line addition to the public `packages/contracts/src/index.ts` entry point:

```diff
+export {basename as displayTitle} from 'node:path';
```

The client draft validator in `apps/client/src/draft.ts` imports the public runtime schema. The renderer runtime has no Node built-ins or polyfills. The submit change above does not require the proposed export. Report any actionable finding with trigger and consequence.

## Verification planning

A release brief requires visual selection to stay correct after switching chats, and the packaged desktop to preserve an unsent draft after a native close/relaunch. Supplied evidence consists of a passing DOM selection test using a fake backend, with two equal display names and distinct IDs. No packaged app, native runner or close/relaunch result is supplied. State which acceptance criteria have evidence, what to check next, and what remains open.
