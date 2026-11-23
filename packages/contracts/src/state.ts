import {z} from 'zod';
import {batchLimit, parseWire} from './wire.js';
import {pageHeader, validPageRange} from './paging.js';
import type {OwnerId} from './values.js';
import {
  CommandId,
  ProjectTarget,
  RequestTarget,
  RunTarget,
  Sequence,
  SessionTarget,
  SnapshotId,
  Timestamp,
  Title,
  wireBytes,
  wireVersion,
} from './values.js';

import {
  DeliveryState,
  RequestMetadata,
  RunObservation,
  SessionBinding,
} from './lifecycle.js';

// Snapshots and replays contain public metadata. Private prompt and answer content
// belongs to the separately authorized live request transport.
export const ProjectRecord = z.strictObject({
  kind: z.literal('project'),
  target: ProjectTarget,
  title: Title,
});
export const SessionRecord = z.strictObject({
  kind: z.literal('session'),
  target: SessionTarget,
  title: Title,
  binding: SessionBinding,
});
export type ProjectRecord = z.infer<typeof ProjectRecord>;
export type SessionRecord = z.infer<typeof SessionRecord>;
export const SnapshotRecord = z.discriminatedUnion('kind', [
  ProjectRecord,
  SessionRecord,
  z.strictObject({
    kind: z.literal('run'),
    target: RunTarget,
    revision: Sequence,
    updatedAt: Timestamp,
    observation: RunObservation,
  }),
  z.strictObject({
    kind: z.literal('request'),
    target: RequestTarget,
    metadata: RequestMetadata,
  }),
  z.strictObject({
    kind: z.literal('answer_delivery'),
    target: RequestTarget,
    commandId: CommandId,
    delivery: DeliveryState,
  }),
]);
export type SnapshotRecord = z.infer<typeof SnapshotRecord>;

/** Stable bytewise order for snapshot producers and readers. Later revisions keep their subject's key. */
export function snapshotRecordKey(record: SnapshotRecord): string {
  switch (record.kind) {
    case 'project':
      return '0/' + record.target.projectId;
    case 'session':
      return '1/' + record.target.sessionId;
    case 'run':
      return '2/' + record.target.runId;
    case 'request':
      return '3/' + record.target.requestId;
    case 'answer_delivery':
      return '4/' + record.commandId;
  }
}
const snapshotHeader = z.strictObject({
  ...pageHeader,
  schemaVersion: z.int().nonnegative(),
  snapshotId: SnapshotId,
  records: z.array(z.unknown()).max(100),
});
export const SnapshotPage = snapshotHeader
  .extend({
    schemaVersion: pageHeader.schemaVersion,
    records: z.array(SnapshotRecord).max(100),
  })
  .refine(
    (page) => validPageRange(page, page.records.length),
    'Invalid snapshot range or continuation',
  )
  .refine(
    (page) => wireBytes(page) <= batchLimit,
    'Snapshot page exceeds 1 MiB',
  )
  .refine((page) => {
    let previous = '';
    for (const record of page.records) {
      const key = snapshotRecordKey(record);
      if (key <= previous) return false;
      previous = key;
    }
    return true;
  }, 'Snapshot rows must be strictly ordered by stable identity');
export type SnapshotPage = z.infer<typeof SnapshotPage>;
export type DecodedSnapshotPage =
  | {status: 'ok'; page: SnapshotPage}
  | {status: 'malformed' | 'unsupported_version'};

/** Read one snapshot in order. Discard this reader and its partial projection on a mismatch. */
export function createSnapshotReader(
  ownerId: OwnerId,
  snapshotId: SnapshotId,
): (wire: string) => DecodedSnapshotPage {
  let highWater: string | undefined;
  let total: string | undefined;
  let offset = 0n;
  let previousKey: string | undefined;
  let expectedToken: string | null = null;
  return (wire) => {
    if (highWater !== undefined && expectedToken === null)
      return {status: 'malformed'};
    const value = parseWire(wire, batchLimit);
    const version = wireVersion(value);
    if (version === 'malformed') return {status: 'malformed'};
    const header = snapshotHeader.safeParse(value);
    if (
      !header.success ||
      !validPageRange(header.data, header.data.records.length) ||
      header.data.ownerId !== ownerId ||
      header.data.snapshotId !== snapshotId ||
      header.data.offset !== offset.toString() ||
      header.data.pageToken !== expectedToken ||
      (highWater !== undefined &&
        (header.data.highWater !== highWater ||
          header.data.totalRecords !== total))
    )
      return {status: 'malformed'};
    if (version === 'unsupported_version') return {status: version};
    const result = SnapshotPage.safeParse(value);
    if (!result.success) return {status: 'malformed'};
    const page = result.data;
    const first = page.records.at(0);
    if (
      previousKey !== undefined &&
      first !== undefined &&
      snapshotRecordKey(first) <= previousKey
    )
      return {status: 'malformed'};
    highWater = page.highWater;
    total = page.totalRecords;
    offset += BigInt(page.records.length);
    const last = page.records.at(-1);
    if (last !== undefined) previousKey = snapshotRecordKey(last);
    expectedToken = page.next;
    return {status: 'ok', page};
  };
}
