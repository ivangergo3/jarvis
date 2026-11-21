# Local command receipts and event replay

A Jarvis command belongs to one owner and names the stable IDs its operation requires. Creating a project or session precedes creation of its child IDs. The desktop must be able to recover that request after disconnect without creating a second run or answering a different approval. This document specifies the durable wire contract in [issue #108](https://github.com/ivangergo3/jarvis/issues/108). Its caller is a process-authenticated desktop with a current local Supabase session for the configured owner. The separate lifecycle and provider contracts govern execution after admission.

## Send a command

1. Electron main durably records a random command UUID, the owner and original Auth session, immutable destination and payload, attachment references and composer revision before sending. A local persistence error leaves the draft editable. Reconcile pending IDs after restart before enabling Send. Showing or restoring an outbox entry requires the active owner session.
2. Nest takes the owner from verified authentication and resolves the stored ancestry of the project, session, run and request. Display names and the currently visible chat cannot reroute a command.
3. Serialize competing requests by `(owner, commandId)`. In one database transaction, check for an existing receipt before consulting mutable run state. Fingerprint the operation, destination, expected revision and canonical payload including ordered immutable content references. Exclude refreshed credentials and delivery metadata. An identical fingerprint returns the original receipt. Different data with the same ID returns 409. Reserve the key even under concurrent inserts, using the database uniqueness constraint and retrying the lookup after a conflict.
4. For a new mutation, serialize the active original Auth session check at commit against revocation, expiry and same-ID retirement, including while waiting on a command lock. Admission and approval claims require an active session at that authorization point. Earlier revocation prevents the mutation. An earlier commit remains discoverable by the same owner. Then validate the payload, frozen local/provider destination, expected revision, permissions and admission state within that transaction. Commit the new IDs, domain change, owner-sequenced event and receipt together. If the transaction fails, no run or successful receipt is visible. Preserve deduplication records when compacting event replay. A committed receipt acknowledges the local operation. Provider handoff, acceptance, terminal outcome and cleanup each require their own evidence.

Only the acknowledged composer revision can clear. Retain its exact text and image bytes until the input is safely delivered or the owner can restore or discard it after definitive refusal or provably unsent cancellation. Restoring an older input creates a separately saved draft if newer edits exist. It does not send.

A receipt lookup can return 404 while an original send remains uncommitted, or when Electron died before sending. Keep that command pending. While the original Auth session remains active, an explicit owner retry can submit the exact same local request and ID under current authorization, destination and admission checks. After that session is revoked or expires, a new session for the same verified owner can read its existing receipt and restore its draft, but cannot revive its original authority. To resolve a missing receipt, Nest serializes retirement of that original command ID against admission under the same command lock. Return an earlier committed receipt or commit an unsent tombstone after verifying that the old session is permanently inactive and no admission committed. A late original request sees the tombstone. Only then may the owner explicitly submit the unsent input as a new command under the new session. If the old admission cannot be settled, keep it pending. A transient failure or ambiguous commit stays pending. This local retry never reissues an ambiguous provider frame. Reconcile any prior handoff on its original thread.

## Operations

Requests use versioned `/v1` routes on the authenticated local service. All product operations require the verified owner, including local history reads while the model provider is unavailable.

| Method and path | Result |
| --- | --- |
| POST /projects | Create a project with a stable ID and title. |
| PUT /projects/{project}/repository | Register the checkout selected by the owner through Electron’s native picker, with expected registration revision. |
| GET /projects, GET /projects/{project}/sessions | List durable selection metadata with stable IDs and bounded pagination. |
| POST /projects/{project}/sessions, POST /sessions/{session}/runs | Create one session or queue one run at the immutable destination. |
| GET /sessions/{session}/runs/{run} | Return this run’s truthful state and revision. |
| POST /runs/{run}/requests/{request}/answer | Claim the exact live request once, with its expected revision and bound channel. |
| POST /runs/{run}/cancel | Request cancellation of this run. The lifecycle contract governs stop delivery and cleanup. |
| GET /commands/{command} | Look up the original receipt within the owner namespace. |
| GET /snapshot, GET /events?after={cursor} | Obtain a consistent durable state and replay changes from its owner-scoped cursor. |
| GET /sessions/{session}/history?after={cursor}&limit={n} | Page durable entries by their stable sequence and a fixed high-water mark. |
| GET /sessions/{session}/history/{entry}/content/{content}?offset={n} | Read retained text or a normalized image in chunks of up to 64 KiB. Recheck owner, session, entry and immutable content reference on every request. |

Every product mutation in this table uses a command UUID. Return 201/202 for committed creation or accepted work, 400 for malformed input, 401 for an invalid session, 403 for disallowed operations and 404 for absent or inaccessible targets. Use 409 for conflicts, 410 for expired cursors, 413 for input size, 429 for full admission and 503 for unavailable dependencies. Responses carry safe reason codes, never credentials.

## Replay and recover

Allocate each owner's event sequence under a transactional counter held through commit. Every event records its ID, owner, typed subject ID, schema version, sequence and timestamp. Events for a run or its children require the run ID. A project-created event has a project subject and no run ID.

A consistent snapshot and cursor describe the same committed prefix. Include current pending approval/question data with the original request ID, revision and opaque channel binding. Recheck live binding and permitted scope when answering. Serialize answers with retirement or terminal state so only one decision wins. A lost channel leaves the request retired or unresolved. No decision is forwarded to a replacement channel.

Subscribe to wake-up notifications before reading the durable high-water mark. Replay in order from the last accepted cursor, then tail the log. Notifications can be lost: periodically query the log. Deduplicate delivered IDs and reconnect on gaps. Disconnect slow SSE readers with a resumable cursor. Use separate authenticated connections for commands and streaming so an open SSE response cannot block cancellation or approval receipts. Check active owner session before every read, batch and idle heartbeat.

A 410 triggers a fresh snapshot and history traversal. History retains Jarvis-submitted inputs, attachment references, observed content, decisions, outcomes and known gaps independently of event compaction. Bound pages to 100 entries and 1 MiB of encoded data. Chunk stored output to 32 KiB, cap optional output to 8 MiB per run and 1 GiB per owner, and reserve room for truthful final state. At the limit, retain an explicit truncation marker with the retained byte count and cause. Large or removed content is an owner-bound reference or removal tombstone.

## Synthetic acceptance

| Sequence | Expected outcome |
| --- | --- |
| Command C1 creates run R1 at sequence 41, then the desktop loses the local response | An exact C1 retry returns the original R1 receipt. A changed destination conflicts. |
| A second chat also named Planning is selected while the first chat has an approval | The answer remains bound to its original session, request and worker generation. An expired or competing decision cannot win. |
| A prompt's event aged out while its original channel remains live | The fresh snapshot contains the still-actionable prompt. A lost channel cannot become actionable merely through replay. |
| A restored client has an expired event cursor and the provider is offline | Its signed-in owner can retrieve stored history and referenced data page by page. |
| The DB transaction rolls back, or the service disconnects before confirming its commit | A rollback leaves no partial receipt, run or sequence gap. Ambiguous commit is reconciled at C1 before any new send. |

[Shared contracts #114](https://github.com/ivangergo3/jarvis/issues/114) defines the wire types. [Persistence #117](https://github.com/ivangergo3/jarvis/issues/117) verifies transaction, deduplication and recovery records. [Restart recovery #124](https://github.com/ivangergo3/jarvis/issues/124) verifies ambiguous sends against the actual adapter, and [request routing #125](https://github.com/ivangergo3/jarvis/issues/125) verifies answers and cancellations on their original run. Keep a send or decision pending if those implementations cannot establish the required evidence.
