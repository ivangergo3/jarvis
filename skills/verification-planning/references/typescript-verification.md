# Matching a TypeScript claim to platform evidence

Identify the artifact and runtime for each acceptance criterion before selecting tools. The same TypeScript source may ship to a browser renderer, privileged desktop process, local server or mobile wrapper. State which environment can exercise the observable behavior.

| Claim | Evidence to seek | Gap to retain |
| --- | --- | --- |
| A malformed request cannot start work | Submit invalid wire data to the receiver and count dispatched effects. Also submit valid data aimed at a different owner. | Parsing alone leaves authorization open. |
| A view remains bound to its selection | Switch between two identically named destinations and reverse the order of their replies. Inspect the visible state. | A pure reducer test leaves DOM selection and accessible announcements untested. |
| A browser client can import a shared package | Compile an actual consumer via its public export and inspect the browser dependency graph or bundle. Include re-exports. | A successful server compilation has no browser runtime observation. |
| A canceled operation stops owned work | Drive a controlled child or provider fake through cancel, late result and shutdown. Observe termination, listener removal and independent work. | An acknowledged cancel can precede verified exit. |
| A packaged desktop closes and restores drafts | Exercise the packaged application, real preload and operating-system close actions on the supported platform. | Browser tests can cover draft rendering. Desktop lifecycle remains open until exercised. |
| A device-specific capability works | Observe the required permission path and behavior on the named device or eligible simulator. | Record unavailable hardware, target OS or runner and the exact remaining criterion. |

Keep static checks distinct in the evidence record. Type checking, ESLint, formatting, import policy and tests observe different properties. Check that the relevant script covers the changed workspace package, including linked packages and non-default test configurations. For a full gate, compare the discovered cases with the required inventory and inspect skipped, failed and absent cases.

For a mixed-platform feature, report the component result, integration result and platform gap separately. Preserve the artifact identity and run environment. Qualify browser, device or provider claims only on the environment named by the criterion. A paid or credentialed dependency remains an explicit gap when the permitted setup is synthetic.
