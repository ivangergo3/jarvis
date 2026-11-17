# Authority verification before autonomy

Ticket #49 adds a tested Swift authority component and an isolated, synthetic tool harness. It does **not** enable a coordinator, register live tools, change Codex permissions, or sandbox the shipping Jarvis app. The existing explicit chat/approval path and its owner remain unchanged.

## Trusted control and untrusted data

`JarvisAuthority` is a separate Foundation-only Swift module. The app does not depend on it yet. A trusted host constructs an `AuthoritySession` with immutable resources and grants derived from explicit user authorization. Future adapters must keep this host interface out of the model's tool catalogue. The model-facing proposal schema accepts only request ID, action kind, destination ID, resource ID, amount and optional currency. Unknown fields, oversized packets and unknown action kinds fail; there are no permission, approval, shell, URL, credential or inline-payload fields.

Resources are host-owned snapshots with stable UUIDs and host-assigned classification. Resource text is never interpreted as authority. The harness includes instruction-like chat, tool, transcript and imported-skill content and checks the actual calls that reach its no-op tool. This verifies runtime enforcement when malicious proposals are attempted; it is not a measurement of a model's ability to resist prompt injection.

| Capability | Required scope | Additional constraint |
| --- | --- | --- |
| Observe | Exact destination and resource IDs | Credential resources are never accessible |
| Draft | Separate draft grant for the exact IDs | Drafting cannot authorize delivery |
| Send / publish | Separate action grant for exact IDs | Only host-classified public resources may leave the boundary |
| Spend | Exact action, destination, resource, currency, call count and total minor-unit budget | Positive amount; budget reserved before suspension; EUR/USD/GBP only in this prototype |
| Delete | Separate destructive-action grant for exact IDs | Never implied by read/draft authority |

All grants expire and have bounded call counts. An already granted action runs without another approval. A grant marked as requiring approval stays pending until the trusted host approves that exact immutable request. Denial is final for that request; changing its destination or resource under the same ID fails. Revocation/expiry are checked again at dispatch. Concurrent calls cannot consume the same request or overspend the grant.

An adapter receives the exact proposal and host-owned resource after authorization. It must not resolve a resource ID to mutable replacement content, infer a destination from a display name, or expand the grant using tool output. Private-resource export is deliberately unsupported even with a send grant; a later explicit declassification/export design needs separate review. This restricted resource-reference API is not a general DLP solution for arbitrary free text.

## Outcomes, cancellation and evidence

The ledger records pending approval, ready, denied, cancelled, dispatched, succeeded, rejected and uncertain outcomes. Cancellation before dispatch makes no tool call. Cancellation/disconnect after dispatch records uncertainty, not rollback. A failed call can have produced an effect, so it never automatically replenishes the call/spend allowance. Repeated execution of the same request cannot resend it.

Reconciliation uses the adapter's read-only lookup and requires a structured receipt matching the entire original proposal. A missing, mismatched or failed lookup leaves the outcome uncertain. A success claim embedded in tool text is not a receipt. Adapters must authenticate this lookup; the fake harness does not prove any external provider's idempotency or receipt guarantees.

The ledger fails closed at its configured capacity instead of evicting request identities. Sessions are ephemeral and cannot reconnect after disconnect; fresh host authority is needed for a new session. Durable crash recovery, trusted user-identity binding and live adapters remain prerequisites for autonomous use. There is no persisted grant that a restart silently reloads and replays.

Audit entries contain only request UUID, action kind and state. They exclude payloads, labels, paths, credentials and raw errors and retain at most 256 entries in memory. The harness writes a fixed-shape report with synthetic observed calls, the commit/dirty flag, executable SHA-256 and sandbox-profile SHA-256. Local evidence overwrites `test-results/authority.json`; temporary raw worker logs are removed. CI retains the existing bounded diagnostics artifact for seven days. These are metadata minimization and bounded retention, not a promise that arbitrary future adapters redact everything correctly.

## OS isolation evidence and limits

`quality-gate authority` stages a no-op executable in an owned temporary directory and starts it with a scrubbed environment under `sandbox-exec`. The profile denies network and child processes by default, denies reads of user-home/volume roots and the synthetic private fixture, and allows writes only to its selected output file and `/dev/null`. The worker must observe permission-denied errors for a synthetic credential read, unauthorized write, loopback network attempt and child-process launch. Missing files, connection refusal and unrelated errors cannot count as successful isolation. The controller independently checks that no unauthorized output file was created. Only synthetic credentials are used; no Keychain query or real message/purchase/ad operation is performed.

The verification profile permits broad read access outside the denied roots for runtime loading. It is **not a complete filesystem allowlist**, and it does not prove Keychain isolation or containment of a hostile native plugin. Trusted Swift code, tool implementations, resource classification and the host approval channel are outside the model-data threat boundary. The probe checks the specified kernel restrictions on the runner; it is not evidence that the current unsandboxed Jarvis app has those restrictions.

Apple's installed `sandbox-exec(1)` manual marks the utility deprecated. It is used only for this fail-closed local/CI verification fixture; unavailable or ineffective isolation fails the gate rather than silently running unconfined. A production implementation must select and verify a supported [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)/[XPC helper](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingXPCServices.html) design with an explicit filesystem/network/credential policy. Do not turn this test profile into shipping security configuration or relax it to make an autonomous feature run.

## Running and reviewing

Run `./scripts/check.sh`: existing formatting/concurrency/architecture/tests remain, followed by the isolated authority check and Release build. `swift run quality-gate authority` runs the focused harness; `swift run quality-gate mutations` tests deliberately broken destination/export checks in disposable copies alongside the existing fault probes. Unit tests exercise approval denial, scope/identity, cancellation/disconnect, lost acknowledgement, spending races, schema boundaries and ledger/audit constraints. The two test-module inventories remain complete; the new critical assertions are explicitly required.

Review the authority types and `AuthoritySession` first, then the observed-call tests, worker and OS profile/controller. The dependency gate protects the new module from UI, process, network and filesystem dependencies. Passing this ticket establishes a reusable verified component and evidence harness. It does not open the production autonomy gate: live adapters, authenticated host integration, durable uncertain-outcome recovery and supported production isolation still need implementation and acceptance.
