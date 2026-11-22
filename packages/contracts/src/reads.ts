import {z} from 'zod';
import {
  CommandId,
  Cursor,
  OwnerId,
  ProjectTarget,
  RequestTarget,
  RunTarget,
  Sequence,
  SessionTarget,
  SnapshotId,
  Version,
  wireBytes,
} from './values.js';
import {
  AuthSessionId,
  ContentDigest,
  ContentId,
  Digest,
  EpochId,
  LiveRequestTarget,
} from './input.js';
import {StagingId} from './staging-id.js';
import {ProjectRecord, SessionRecord} from './state.js';

const header = {schemaVersion: Version};
const opaque = z.string().min(1).max(2048);
const page = z.strictObject({
  after: opaque.nullable(),
  limit: z.int().min(1).max(100),
});
const highWaterPage = page.extend({highWater: Cursor});
const snapshotContinuation = z.strictObject({
  highWater: Sequence,
  offset: Sequence,
  pageToken: opaque,
});
const contentPart = z.strictObject({
  contentId: ContentId,
  offset: z
    .int()
    .nonnegative()
    .max(128 * 1024 * 1024),
});
const historyTarget = SessionTarget.extend({
  entryId: z.uuid().lowercase(),
  entryRevision: Sequence,
});
export const ReadRequest = z.discriminatedUnion('operation', [
  z.strictObject({...header, operation: z.literal('project.list'), page}),
  z.strictObject({
    ...header,
    operation: z.literal('session.list'),
    target: ProjectTarget,
    page,
  }),
  z.strictObject({
    ...header,
    operation: z.literal('draft.list'),
    target: SessionTarget,
    page: highWaterPage.nullable(),
  }),
  z.strictObject({
    ...header,
    operation: z.literal('draft.content'),
    target: SessionTarget.extend({revision: Sequence}),
    part: contentPart,
  }),
  z.strictObject({
    ...header,
    operation: z.literal('run.read'),
    target: RunTarget,
  }),
  z.strictObject({
    ...header,
    operation: z.literal('request.describe'),
    target: RequestTarget,
  }),
  z.strictObject({
    ...header,
    operation: z.literal('request.content'),
    target: LiveRequestTarget,
    part: contentPart,
  }),
  z.strictObject({
    ...header,
    operation: z.enum(['staging.cursor', 'controller.current_epoch']),
  }),
  z.strictObject({
    ...header,
    operation: z.literal('controller.closed_epochs'),
    through: opaque,
    page,
  }),
  z.strictObject({
    ...header,
    operation: z.literal('controller.receipts'),
    epoch: EpochId,
    page: highWaterPage,
  }),
  z.strictObject({
    ...header,
    operation: z.literal('command.lookup'),
    commandId: z.union([CommandId, StagingId]),
  }),
  z.strictObject({
    ...header,
    operation: z.literal('snapshot.read'),
    snapshotId: SnapshotId,
    continuation: snapshotContinuation.nullable(),
  }),
  z.strictObject({
    ...header,
    operation: z.literal('events.after'),
    after: Cursor,
  }),
  z.strictObject({
    ...header,
    operation: z.literal('history.read'),
    target: SessionTarget,
    page: highWaterPage.nullable(),
  }),
  z.strictObject({
    ...header,
    operation: z.literal('history.content'),
    target: historyTarget,
    part: contentPart,
  }),
]);
export type ReadRequest = z.infer<typeof ReadRequest>;

const listing = {
  ...header,
  ownerId: OwnerId,
  after: opaque.nullable(),
  next: opaque.nullable(),
};
function validListing(
  value: {
    after: string | null;
    next: string | null;
    records: readonly unknown[];
  },
  ids: readonly string[],
) {
  return (
    (value.next === null || (value.next !== value.after && ids.length > 0)) &&
    new Set(ids).size === ids.length &&
    wireBytes(value) <= 1024 * 1024
  );
}
export const ProjectPage = z
  .strictObject({...listing, records: z.array(ProjectRecord).max(100)})
  .refine((value) =>
    validListing(
      value,
      value.records.map((r) => r.target.projectId),
    ),
  );
export const SessionPage = z
  .strictObject({
    ...listing,
    target: ProjectTarget,
    records: z.array(SessionRecord).max(100),
  })
  .refine(
    (value) =>
      value.records.every(
        (r) => r.target.projectId === value.target.projectId,
      ) &&
      validListing(
        value,
        value.records.map((r) => r.target.sessionId),
      ),
  );
export type ProjectPage = z.infer<typeof ProjectPage>;
export type SessionPage = z.infer<typeof SessionPage>;

export const CloseAdmissionEpoch = z.strictObject({
  ...header,
  originatingSessionId: AuthSessionId,
  operation: z.literal('controller.close_epoch'),
  commandId: CommandId,
  expectedEpoch: EpochId,
});
export const AdmissionEpochResult = z.strictObject({
  ...header,
  ownerId: OwnerId,
  currentEpoch: EpochId,
  closedThrough: opaque,
});
export const ReceiptLedger = z.strictObject({
  epoch: EpochId,
  highWater: Cursor,
});
export const ClosedEpochPage = z
  .strictObject({
    ...header,
    ownerId: OwnerId,
    through: opaque,
    ledgers: z.array(ReceiptLedger).max(100),
    next: opaque.nullable(),
  })
  .refine(
    (value) =>
      wireBytes(value) <= 1024 * 1024 &&
      new Set(value.ledgers.map((row) => row.epoch)).size ===
        value.ledgers.length &&
      (value.next === null || value.ledgers.length > 0),
  );
export type ClosedEpochPage = z.infer<typeof ClosedEpochPage>;

// Content is returned as bytes by a separately authorized stream. These headers
// bind each range to the immutable object. A reader must verify the assembled digest.
export const ContentChunk = z
  .strictObject({
    ...header,
    contentId: ContentId,
    sha256: Digest,
    totalBytes: z
      .int()
      .nonnegative()
      .max(128 * 1024 * 1024),
    offset: z.int().nonnegative(),
    bytes: z.int().nonnegative().max(65536),
  })
  .refine(
    (value) =>
      value.offset <= value.totalBytes &&
      value.offset + value.bytes <= value.totalBytes &&
      (value.bytes > 0 || value.totalBytes === 0) &&
      ContentDigest.safeParse({bytes: value.totalBytes, sha256: value.sha256})
        .success,
  );

export type CloseAdmissionEpoch = z.infer<typeof CloseAdmissionEpoch>;
export type AdmissionEpochResult = z.infer<typeof AdmissionEpochResult>;
export type ReceiptLedger = z.infer<typeof ReceiptLedger>;
export type ContentChunk = z.infer<typeof ContentChunk>;
