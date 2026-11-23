import {z} from 'zod';
import {StagingId} from './staging-id.js';
import {
  Cursor,
  OwnerId,
  Sequence,
  SessionTarget,
  Timestamp,
  Version,
} from './values.js';
import {
  AttachmentId,
  AuthSessionId,
  ContentDigest,
  ContentRef,
  Digest,
  EpochId,
  ImageRef,
} from './input.js';

const lowMask = (1n << 62n) - 1n;
export function stagingCommandId(sequence: string): string {
  const n = BigInt(Sequence.parse(sequence));
  const lower = ((n & lowMask) | (1n << 63n)).toString(16).padStart(16, '0');
  return (
    '00000000-0000-800' +
    (n >> 62n).toString() +
    '-' +
    lower.slice(0, 4) +
    '-' +
    lower.slice(4)
  );
}
const meta = {
  schemaVersion: Version,
  originatingSessionId: AuthSessionId,
  writerEpoch: EpochId,
  sequence: Sequence,
  commandId: StagingId,
};
const draft = SessionTarget.extend({revision: Sequence});
const chunkBytes = z.int().min(1).max(65536);
const part = z.strictObject({bytes: chunkBytes, sha256: Digest});
export const DraftChunkRef = ContentRef.safeExtend({bytes: chunkBytes});
export type DraftChunkRef = z.infer<typeof DraftChunkRef>;
const sealed = ContentDigest.safeExtend({
  chunkCount: z.int().min(0).max(2048),
}).refine(
  (ref) => ref.chunkCount <= ref.bytes && ref.bytes <= ref.chunkCount * 65536,
);
const image = z.strictObject({
  mime: z.literal('image/png'),
  bytes: z
    .int()
    .min(1)
    .max(20 * 1024 * 1024),
  sha256: Digest,
});
const numbered = (value: {sequence: string; commandId: string}) =>
  Sequence.safeParse(value.sequence).success &&
  value.commandId === stagingCommandId(value.sequence);
// Binary bodies travel with their independently validated metadata.
export const StagingCommand = z
  .discriminatedUnion('operation', [
    z.strictObject({
      ...meta,
      operation: z.literal('draft.allocate'),
      target: SessionTarget,
    }),
    z.strictObject({
      ...meta,
      operation: z.literal('draft.chunk'),
      target: draft.extend({index: z.int().min(0).max(2047)}),
      payload: part,
    }),
    z.strictObject({
      ...meta,
      operation: z.literal('draft.seal'),
      target: draft,
      payload: sealed,
    }),
    z.strictObject({
      ...meta,
      operation: z.literal('draft.image'),
      target: draft.extend({attachmentId: AttachmentId}),
      payload: image,
    }),
    z.strictObject({
      ...meta,
      operation: z.literal('draft.discard'),
      target: draft,
    }),
  ])
  .refine(numbered, 'Staging ID must encode its sequence');
export type StagingCommand = z.infer<typeof StagingCommand>;

const saved = {...meta, fingerprint: Digest, recordedAt: Timestamp};
const result = z.discriminatedUnion('operation', [
  z.strictObject({operation: z.literal('draft.allocate'), target: draft}),
  z.strictObject({
    operation: z.literal('draft.chunk'),
    target: draft.extend({index: z.int().min(0).max(2047)}),
    content: DraftChunkRef,
  }),
  z.strictObject({
    operation: z.literal('draft.seal'),
    target: draft,
    content: ContentRef,
  }),
  z.strictObject({
    operation: z.literal('draft.image'),
    target: draft,
    image: ImageRef,
  }),
  z.strictObject({operation: z.literal('draft.discard'), target: draft}),
]);
export const StagingReceipt = z
  .discriminatedUnion('status', [
    z.strictObject({...saved, status: z.literal('committed'), result}),
    z.strictObject({
      ...saved,
      status: z.literal('definitively_refused'),
      reason: z.enum([
        'conflict',
        'invalid_input',
        'capacity',
        'closed_revision',
      ]),
    }),
    z.strictObject({...saved, status: z.literal('retired_unsent')}),
  ])
  .refine(numbered, 'Staging ID must encode its sequence');
export type StagingReceipt = z.infer<typeof StagingReceipt>;

export const StagingCursor = z
  .strictObject({
    schemaVersion: Version,
    ownerId: OwnerId,
    writerEpoch: EpochId,
    sequence: Cursor,
    lastReceipt: StagingReceipt.optional(),
  })
  .refine(
    (value) =>
      value.lastReceipt === undefined ||
      (Sequence.safeParse(value.lastReceipt.sequence).success &&
        Cursor.safeParse(value.sequence).success &&
        (value.lastReceipt.writerEpoch === value.writerEpoch
          ? value.lastReceipt.sequence === value.sequence
          : BigInt(value.lastReceipt.sequence) < BigInt(value.sequence))),
  );
export type StagingCursor = z.infer<typeof StagingCursor>;
export const TakeoverId = z.uuidv7().lowercase().brand<'TakeoverId'>();
export type TakeoverId = z.infer<typeof TakeoverId>;
export const StagingTakeover = z.strictObject({
  schemaVersion: Version,
  originatingSessionId: AuthSessionId,
  operation: z.literal('staging.takeover'),
  requestId: TakeoverId,
  expectedWriterEpoch: EpochId,
});
export const StagingRetirement = z
  .strictObject({
    ...meta,
    operation: z.literal('staging.retire'),
    originalSessionId: AuthSessionId,
    fingerprint: Digest,
  })
  .refine(numbered)
  .refine((value) => value.originalSessionId !== value.originatingSessionId);

export type StagingTakeover = z.infer<typeof StagingTakeover>;
export type StagingRetirement = z.infer<typeof StagingRetirement>;
