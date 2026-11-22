# Local wire contracts

The browser and backend import stable typed IDs and wire values from `@jarvis/contracts`. A request names its entire destination by ID, including its worker generation and request revision. IDs use a canonical lowercase UUID. General command IDs are random version 4 UUIDs. Timestamps use UTC with three fractional digits. Decimal cursors fit a signed 64-bit counter, with zero as the initial cursor. Revisions and event sequences start at one.

The pinned Zod 4.6.7 declarations reference the WHATWG URL type. The pnpm patch gives Zod’s URL helpers a module-local type when the consumer compiles with only ES2023 libraries. Consumers with native URL declarations retain that type. The patch changes only TypeScript declarations.

The public lifecycle schemas distinguish the observed provider outcome from cleanup of its local worker. A verified local exit alone leaves the provider effect unknown. An interrupted outcome requires a verified provider interruption. Record worker cleanup independently for any state when there is evidence about the run’s registered helper. A terminal-unsent input can retain its setup fence and record a verified worker exit together. Omit the field when there is no observation, except for interrupted runs where cleanup must be explicit. Unavailable requests carry one safe reason. Private prompts, channel handles and answers belong to the authorized request flow. Unknown state values require a compatible consumer.

## Snapshot pages

Create a reader with `createSnapshotReader(ownerId, snapshotId)`, using the authenticated owner and a fresh snapshot UUID. Pass the original JSON text of each page so it can enforce the 1 MiB UTF-8 limit, including escapes and whitespace. Each page holds up to 100 public records. Repeated JSON keys are rejected, including different escaped spellings of the same key.

The first page has `pageToken: null` and offset zero. A later page echoes the previous `next` as its token. The owner, snapshot ID, total record count and high-water mark stay fixed. Producers sort rows by the ASCII key returned by `snapshotRecordKey`. The reader validates ordering within and across pages while retaining only the prior key. A final page has `next: null`. A zero high-water mark describes an empty snapshot.

Apply data only after an `ok` response. A malformed page or an unsupported version cannot advance the reader. Discard an expired or mismatched partial projection, then start a fresh snapshot. Public records contain safe request status. The service’s authorized live route supplies any private prompt. [Local command and event contract](../../docs/engineering/local-command-stream.md)

## Event replay

Pass an original JSON event to `decodeEvent`. For a batch, pass the original text plus the authenticated `ownerId`, last applied `after` cursor and a required `hasApplied(eventId)` lookup to `readEventBatch`. The lookup uses that owner’s committed projection history. After an accepted batch, commit the projected changes, event IDs and new cursor together. A repeated ID at a new sequence is invalid, including after a restart. Compare decimal cursors numerically with `BigInt`.

The wire reader limits each event envelope to 64 KiB before decoding the batch. JSON separator whitespace counts towards the batch limit. Formatting and escapes inside an envelope count towards both limits. A batch holds at most 100 events and 1 MiB of original UTF-8 data. Known event kinds must carry their original project, session, run and request ancestry. Unknown kinds still require a stable target, owner and contiguous sequence. An incompatible version or event kind produces a compatibility status only after those common checks pass. Gaps, repeated IDs or keys, wrong destinations and malformed data stop the replay without advancing it.

An `ok` result contains the validated events. Every other result omits them. For a trusted locally constructed object the `Event` and `EventBatch` schemas are available. Actual projection, authorization and durable cursor storage belong to the consuming service.
