# Automating TypeScript behavior

Inspect the configured runner, workspace include patterns, environment and package commands. Place the regression where normal discovery will execute it. For a required gate, check that the discovered path and full test name appear in the result and have an executed passing status. Preserve failures from setup, teardown, zero discovery and unexpected skips.

## Control the boundary that can fail

| Failure | Fixture | Assertion |
| --- | --- | --- |
| A shared contract drifts between renderer and server | Round-trip valid JSON plus malformed, future-version and absent-field variants through the public package. | Both consumers accept the valid shape. Invalid input has no side effects and exposes the expected reason. |
| A reply reaches the wrong chat | Create two equal display names with distinct IDs. Hold the first promise, switch selection, finish the second request and release the first. | Observe both the selected destination and its displayed content after the late response. |
| Cancellation crosses an acknowledgement | Use a controllable fake provider and advance through the two possible orderings. | Assert the recorded intent, number of external handoffs and eventual observed state. |
| Storage commits and an acknowledgement is lost | Fail the reply after commit, then query or repeat the same command identity under the agreed contract. | The original assignment is returned and the effect count remains one. A changed payload with that identity yields conflict. |
| Shutdown leaks work | Track owned subscriptions, timers and child lifetime in the harness. Keep a separate unrelated observer or decoy alive. | Teardown releases resources owned by the subject and preserves the decoy. |

Prefer a promise barrier or fake clock at a named transition. A long sleep can pass before the event the assertion intends to cover. Isolate storage, ports and fixture directories. Bound timeouts and close resources in cleanup even if an assertion fails. Keep process tests at the actual process boundary when claiming signal or exit behavior.

Exercise the public entry a caller uses. A test that replaces the parser, scheduler and dispatcher with mocks can only establish its own wiring. Inspect a failure on the seeded or original defect and a pass after the targeted repair. Report which layers still use fakes.

For browser journeys, target roles, names and observable state. A headless DOM test can establish rendered state and interaction logic. Native menus, preload security, packaging, device permissions and external provider behavior each require their own matching environment.
