import {z} from 'zod';
import {batchLimit, eventFramesFit, eventLimit, parseWire} from './wire.js';
import {
  CommandId,
  Cursor,
  EventId,
  OwnerId,
  ProjectTarget,
  RequestTarget,
  RunTarget,
  Sequence,
  SessionTarget,
  Timestamp,
  Title,
  Version,
  wireBytes,
  wireVersion,
} from './values.js';
import {
  DeliveryState,
  RequestMetadata,
  RunObservation,
  SessionBinding,
} from './lifecycle.js';
import {HistoryContent} from './retained-content.js';
import {StagingId} from './staging-id.js';

const envelope = {
  schemaVersion: Version,
  ownerId: OwnerId,
  eventId: EventId,
  sequence: Sequence,
  occurredAt: Timestamp,
};
const accepted = z.strictObject({commandId: CommandId});
const variants = z.discriminatedUnion('kind', [
  z.strictObject({
    ...envelope,
    kind: z.literal('command.recorded'),
    target: z.strictObject({commandId: z.union([CommandId, StagingId])}),
    payload: z.strictObject({
      status: z.enum(['accepted', 'definitively_refused', 'retired_unsent']),
    }),
  }),
  z.strictObject({
    ...envelope,
    kind: z.literal('run.output'),
    target: RunTarget,
    payload: z.strictObject({
      entryId: z.uuid().lowercase(),
      entryRevision: Sequence,
      content: HistoryContent,
    }),
  }),
  z.strictObject({
    ...envelope,
    kind: z.literal('project.created'),
    target: ProjectTarget,
    payload: accepted.extend({title: Title}),
  }),
  z.strictObject({
    ...envelope,
    kind: z.literal('session.created'),
    target: SessionTarget,
    payload: accepted.extend({title: Title}),
  }),
  z.strictObject({
    ...envelope,
    kind: z.literal('session.binding'),
    target: SessionTarget,
    payload: z.strictObject({binding: SessionBinding}),
  }),
  z.strictObject({
    ...envelope,
    kind: z.literal('run.queued'),
    target: RunTarget,
    payload: accepted,
  }),
  z.strictObject({
    ...envelope,
    kind: z.literal('run.state'),
    target: RunTarget,
    payload: z.strictObject({revision: Sequence, observation: RunObservation}),
  }),
  z.strictObject({
    ...envelope,
    kind: z.literal('request.status'),
    target: RequestTarget,
    payload: RequestMetadata,
  }),
  z.strictObject({
    ...envelope,
    kind: z.literal('request.delivery'),
    target: RequestTarget,
    payload: accepted.extend({state: DeliveryState}),
  }),
]);
export const Event = variants.refine(
  (event) => wireBytes(event) <= eventLimit,
  'Event exceeds 64 KiB',
);
export type Event = z.infer<typeof Event>;
/** A validated kind, destination and payload before the owner ledger assigns its envelope. */
type WithoutEnvelope<T> = T extends Event
  ? Omit<T, keyof typeof envelope>
  : never;
export type EventBody = WithoutEnvelope<Event>;
export type DecodedEvent =
  | {status: 'ok'; event: Event}
  | {status: 'unsupported_version' | 'unsupported_event' | 'malformed'};

const kindHeader = z.object({
  ...envelope,
  schemaVersion: z.int().nonnegative(),
  kind: z.string().min(1),
});
const unknownEnvelope = z.strictObject({
  ...kindHeader.shape,
  target: z.union(variants.options.map((option) => option.shape.target)),
  payload: z.custom<object>(
    (value) =>
      typeof value === 'object' && value !== null && !Array.isArray(value),
  ),
});
const targetForKind = new Map<string, z.ZodType>(
  variants.options.map((option) => [
    option.shape.kind.value,
    option.shape.target,
  ]),
);

/** Only a successfully decoded event is eligible to advance a consumer's cursor. */
export function decodeEvent(wire: string): DecodedEvent {
  return decodedEvent(parseWire(wire, eventLimit));
}

function decodedEvent(value: unknown, futureBatch = false): DecodedEvent {
  const version = wireVersion(value);
  if (version === 'malformed') return {status: 'malformed'};
  const kind = kindHeader.safeParse(value);
  if (!kind.success) return {status: 'malformed'};
  const target = targetForKind.get(kind.data.kind);
  if (futureBatch || version === 'unsupported_version' || !target) {
    const frame = unknownEnvelope.safeParse(value);
    if (
      !frame.success ||
      (target && !target.safeParse(frame.data.target).success)
    )
      return {status: 'malformed'};
    return {
      status:
        futureBatch || version === 'unsupported_version'
          ? 'unsupported_version'
          : 'unsupported_event',
    };
  }
  const event = Event.safeParse(value);
  return event.success
    ? {status: 'ok', event: event.data}
    : {status: 'malformed'};
}

const routing = z.object({
  ownerId: OwnerId,
  eventId: EventId,
  sequence: Sequence,
  occurredAt: Timestamp,
});
function ordered(
  ownerId: OwnerId,
  after: string,
  events: readonly z.infer<typeof routing>[],
  hasApplied?: (eventId: EventId) => boolean,
): boolean {
  if (!Cursor.safeParse(after).success) return false;
  const seen = new Set<Event['eventId']>();
  let previous = BigInt(after);
  for (const event of events) {
    if (
      event.ownerId !== ownerId ||
      seen.has(event.eventId) ||
      hasApplied?.(event.eventId) ||
      !Sequence.safeParse(event.sequence).success ||
      BigInt(event.sequence) !== previous + 1n
    )
      return false;
    seen.add(event.eventId);
    previous = BigInt(event.sequence);
  }
  return true;
}
/** A replay batch continues the last acknowledged owner cursor without gaps. */
export const EventBatch = z
  .strictObject({
    schemaVersion: Version,
    ownerId: OwnerId,
    after: Cursor,
    events: z.array(Event).max(100),
  })
  .refine(
    (batch) =>
      ordered(batch.ownerId, batch.after, batch.events) &&
      wireBytes(batch) <= batchLimit,
    'Invalid owner, repeated event, noncontiguous sequence or oversized batch',
  );
export type EventBatch = z.infer<typeof EventBatch>;
export type DecodedEventBatch =
  | {status: 'ok'; batch: EventBatch}
  | {status: 'unsupported_version' | 'unsupported_event' | 'malformed'};
const batchItems = z.strictObject({
  schemaVersion: z.int().nonnegative(),
  ownerId: OwnerId,
  after: Cursor,
  events: z.array(z.unknown()).max(100),
});
const routingFrames = z.array(routing).max(100);

/** Accept a batch only for the authenticated stream and last applied cursor. */
export function readEventBatch(
  wire: string,
  expected: {
    ownerId: OwnerId;
    after: string;
    hasApplied: (eventId: EventId) => boolean;
  },
): DecodedEventBatch {
  const value = parseWire(wire, batchLimit, eventFramesFit);
  const version = wireVersion(value);
  if (version === 'malformed' || typeof expected.hasApplied !== 'function')
    return {status: 'malformed'};
  const items = batchItems.safeParse(value);
  if (
    !items.success ||
    items.data.ownerId !== expected.ownerId ||
    items.data.after !== expected.after
  )
    return {status: 'malformed'};
  const frames = routingFrames.safeParse(items.data.events);
  if (
    !frames.success ||
    !ordered(expected.ownerId, expected.after, frames.data, expected.hasApplied)
  )
    return {status: 'malformed'};
  const events: Event[] = [];
  let unknown: 'unsupported_version' | 'unsupported_event' | undefined =
    version === 'unsupported_version' ? version : undefined;
  for (const item of items.data.events) {
    const event = decodedEvent(item, version === 'unsupported_version');
    if (event.status === 'malformed') return {status: 'malformed'};
    if (event.status === 'ok') events.push(event.event);
    if (
      event.status === 'unsupported_version' ||
      (event.status === 'unsupported_event' && !unknown)
    )
      unknown = event.status;
  }
  if (unknown) return {status: unknown};
  return {
    status: 'ok',
    batch: {...items.data, schemaVersion: Version.value, events},
  };
}
