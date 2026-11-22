# Reviewing a TypeScript boundary

Read the changed public export, its actual recipient and the implementation it resolves to in each supported runtime. Check the changed branch against an ordinary caller, an invalid request and a late or repeated result. Use the smallest case that demonstrates a consequence.

## Follow the runtime graph

A renderer can import a safe-looking shared name whose barrel also re-exports a server-only value. Inspect static imports, dynamic imports, package exports, subpath aliases and module initialization. A type-only import may disappear at runtime while still violating a repository's declared dependency policy. Distinguish a reproduced runtime or build failure from a policy diagnostic.

Trace privileged actions from the renderer through preload or transport to the service. Verify the receiver checks origin/sender, ownership, full target and parsed payload before any effect. Reject reliance on an imported TypeScript interface or `as SomeRequest` as evidence that a wire value passed validation.

## Follow state through a failure

Compare cache and storage keys with the destination captured before an await. Changing a display name, view or current selection cannot establish command identity. Examine the check performed before committing a late reply or handling an already accepted request. Look for duplicate effects after lost acknowledgements and stale data after reconnect.

For a process, identify who owns startup, cancellation, exit observation and final cleanup. Find which outstanding operation can finish after shutdown. Confirm that an interrupt request, a verified terminal event and an ambiguous external effect have separately representable outcomes.

## Qualify the finding

Cite the changed file and line, then state a reachable trigger and the observable consequence. Reference a terminal result, compiler diagnostic, dependency-policy output or reproducible fixture when available. Document absent packaged or device evidence under limitations. An unavailable environment alone does not establish a product defect.

Check that the patch preserves the repository's Google-style conventions and selected lint rules. Treat layout as formatter territory. A style preference needs a stated project rule or a concrete defect to justify blocking the change. Report the bounded verdict even if there are no findings.
