# Implementing a TypeScript change

Start at the caller receiving the result and trace the operation to its owner. Read the public package exports, workspace dependency declarations, module resolution settings and target runtime along that path. A shared path alias can compile successfully while pointing a browser bundle at server code.

## Choose the owner

| Concern | Implementation decision |
| --- | --- |
| A renderer submits work | Capture the stable project and session identifiers with the draft. Expose a narrow operation in the preload or client API. The privileged receiver checks sender, owner, destination and input again. |
| A server returns a snapshot | Keep one authoritative copy in the backend. A query cache can hold the client view keyed by owner and destination. Keep drafts and navigation local. Invalidate or update the matching key from ordered events. |
| A pure contract serves both | Put transport-safe schemas and their inferred types in the public contract entry. Keep Node built-ins, UI libraries, persistence clients, secrets and provider objects in their owning packages. Check re-exports and import-time effects. |
| A process owns work | Start the child in the service or worker that can cancel and reap it. Track the exact child, listeners, timers, streams and outstanding requests through normal completion, disconnect and shutdown. |

Give the UI facts it can safely display. For example, the backend can return an approved display label. Importing its file-resolution helper into a component can pull filesystem access and configuration into the renderer. Avoid a general-purpose IPC method that accepts an arbitrary URL, file path or command. [Electron process model](https://www.electronjs.org/docs/latest/tutorial/process-model)

## Parse the wire once at each trust boundary

Accept incoming data as `unknown`. With Zod, keep the runtime schema and inferred type together. Use the parsed value on success and map a failed parse to a bounded application error. Test invalid values before any dispatch or state mutation. Apply wire limits before allocating unbounded request bodies. Scope the parsed target to the authenticated caller before using it. [Zod schema parsing and type inference](https://zod.dev/basics)

Make version, optionality, nullability, timestamp representation and numeric precision explicit when changing a public contract. Use a discriminated union for outcomes whose next action differs. An ambiguous send may require reading the original receipt. A new command ID can start a second effect.

## Own asynchronous transitions

Capture request identity before the first await. When an older response arrives, compare its destination and sequence or generation before updating state. Choose cancellation, reconciliation or an explicit unresolved state according to what the service observed. Associate cleanup with the code that acquired each resource. A UI unmount can unsubscribe a view while work continues under its service owner.

## Follow the project's Google-style conventions

Prefer named exports, `const` for bindings that stay fixed, descriptive lowerCamelCase variables and UpperCamelCase types when those match the repository profile. Use `import type` for type-only edges. Inspect the local policy for library entry points, exceptions and module syntax. Use its formatter for layout and its linter for semantic rules. Keep narrow failures visible and avoid broad casts or suppressions that hide a boundary mismatch. [Google TypeScript style guide](https://google.github.io/styleguide/tsguide.html)
