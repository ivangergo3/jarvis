import {z} from 'zod';
import {
  Cursor,
  OwnerId,
  RequestTarget,
  RunTarget,
  Sequence,
  SessionTarget,
  Timestamp,
  Version,
  wireBytes,
} from './values.js';
import {ContentRef, EpochId, ImageRef, LiveRequestTarget} from './input.js';
import {
  DeliveryState,
  RequestKind,
  RequestMetadata,
  RunObservation,
} from './lifecycle.js';
import {DraftChunkRef} from './staging.js';
import {Receipt} from './receipt.js';
import {HistoryContent} from './retained-content.js';
import {type PageRange, pageHeader, validPageRange} from './paging.js';

/** Available only to the original authenticated session while the channel and requested revision are current. */
export const LiveRequestDescriptor = z.strictObject({
  schemaVersion: Version,
  ownerId: OwnerId,
  target: LiveRequestTarget,
  kind: RequestKind,
  content: ContentRef.refine((ref) => ref.bytes > 0),
});
export type LiveRequestDescriptor = z.infer<typeof LiveRequestDescriptor>;

function orderedPage(page: PageRange, sequences: readonly string[]): boolean {
  if (
    !Cursor.safeParse(page.highWater).success ||
    !validPageRange(page, sequences.length) ||
    wireBytes(page) > 1024 * 1024
  )
    return false;
  const through = BigInt(page.highWater);
  let previous = BigInt(page.offset);
  for (const value of sequences) {
    if (!Sequence.safeParse(value).success) return false;
    const sequence = BigInt(value);
    if (sequence <= previous || sequence > through) return false;
    previous = sequence;
  }
  const remaining =
    BigInt(page.totalRecords) - BigInt(page.offset) - BigInt(sequences.length);
  return remaining <= through - previous;
}

export const ReceiptPage = z
  .strictObject({
    ...pageHeader,
    epoch: EpochId,
    receipts: z.array(Receipt).max(100),
  })
  .refine(
    (page) =>
      page.receipts.every(
        (item) =>
          item.ownerId === page.ownerId && item.controllerEpoch === page.epoch,
      ) &&
      new Set(page.receipts.map((item) => item.commandId)).size ===
        page.receipts.length &&
      orderedPage(
        page,
        page.receipts.map((item) => item.sequence),
      ),
  );
export type ReceiptPage = z.infer<typeof ReceiptPage>;

const chunks = z
  .array(
    z.strictObject({
      index: z.int().min(0).max(2047),
      ref: DraftChunkRef,
    }),
  )
  .max(2048);
const manifest = {revision: Sequence, chunks, images: z.array(ImageRef).max(6)};
function consistentContent(refs: readonly ContentRef[]): boolean {
  const known = new Map<string, ContentRef>();
  for (const ref of refs) {
    const prior = known.get(ref.contentId);
    if (prior && (prior.bytes !== ref.bytes || prior.sha256 !== ref.sha256))
      return false;
    known.set(ref.contentId, ref);
  }
  return true;
}
function manifestRefs(draft: {
  text: ContentRef | null;
  images: ContentRef[];
  chunks: {ref: ContentRef}[];
}): ContentRef[] {
  return [
    ...(draft.text ? [draft.text] : []),
    ...draft.images,
    ...draft.chunks.map((item) => item.ref),
  ];
}
export const DraftManifest = z
  .discriminatedUnion('status', [
    z.strictObject({...manifest, status: z.literal('open'), text: z.null()}),
    z.strictObject({
      ...manifest,
      status: z.literal('sealed'),
      text: ContentRef,
    }),
  ])
  .refine((draft) => {
    let previous = -1;
    let textBytes = 0;
    for (const item of draft.chunks) {
      if (
        item.index <= previous ||
        (draft.status === 'sealed' && item.index !== previous + 1)
      )
        return false;
      previous = item.index;
      textBytes += item.ref.bytes;
    }
    const selected = [...draft.images, ...(draft.text ? [draft.text] : [])];
    if (new Set(selected.map((ref) => ref.contentId)).size !== selected.length)
      return false;
    return (
      consistentContent(manifestRefs(draft)) &&
      (draft.text === null ||
        draft.chunks.length !== 1 ||
        draft.chunks[0]?.ref.sha256 === draft.text.sha256) &&
      (draft.text === null || draft.text.bytes === textBytes) &&
      new Set(draft.images.map((image) => image.attachmentId)).size ===
        draft.images.length
    );
  });
export type DraftManifest = z.infer<typeof DraftManifest>;
export const DraftManifestPage = z
  .strictObject({
    ...pageHeader,
    target: SessionTarget,
    drafts: z.array(DraftManifest).max(100),
  })
  .refine(
    (page) =>
      consistentContent(page.drafts.flatMap(manifestRefs)) &&
      orderedPage(
        page,
        page.drafts.map((draft) => draft.revision),
      ),
  );
export type DraftManifestPage = z.infer<typeof DraftManifestPage>;

const entry = {
  entryId: z.uuid().lowercase(),
  revision: Sequence,
  sequence: Sequence,
  occurredAt: Timestamp,
};
const decision = z.discriminatedUnion('requestKind', [
  z.strictObject({
    requestKind: z.literal('approval'),
    category: z.enum(['allow_once', 'deny', 'cancel']),
  }),
  z.strictObject({
    requestKind: z.literal('input'),
    category: z.literal('input_provided'),
  }),
]);
export const HistoryEntry = z.discriminatedUnion('kind', [
  z.strictObject({
    ...entry,
    kind: z.literal('request_status'),
    target: RequestTarget,
    metadata: RequestMetadata,
  }),
  z.strictObject({
    ...entry,
    kind: z.literal('input'),
    target: RunTarget,
    content: HistoryContent.refine((value) => value.kind !== 'truncated'),
  }),
  z.strictObject({
    ...entry,
    kind: z.literal('output'),
    target: RunTarget,
    content: HistoryContent,
  }),
  z.strictObject({
    ...entry,
    kind: z.literal('decision'),
    target: RequestTarget,
    decision,
    delivery: DeliveryState,
  }),
  z.strictObject({
    ...entry,
    kind: z.literal('outcome'),
    target: RunTarget,
    observation: RunObservation,
  }),
  z.strictObject({
    ...entry,
    kind: z.literal('gap'),
    target: RunTarget,
    reason: z.enum([
      'missing_observation',
      'scope_unverified',
      'retention_limit',
    ]),
  }),
]);
export type HistoryEntry = z.infer<typeof HistoryEntry>;
export const HistoryPage = z
  .strictObject({
    ...pageHeader,
    target: SessionTarget,
    entries: z.array(HistoryEntry).max(100),
  })
  .refine(
    (page) =>
      page.entries.every(
        (item) =>
          item.target.projectId === page.target.projectId &&
          item.target.sessionId === page.target.sessionId,
      ) &&
      new Set(page.entries.map((item) => item.entryId)).size ===
        page.entries.length &&
      consistentContent(
        page.entries.flatMap((item) =>
          'content' in item && 'ref' in item.content ? [item.content.ref] : [],
        ),
      ) &&
      orderedPage(
        page,
        page.entries.map((item) => item.sequence),
      ),
  );
export type HistoryPage = z.infer<typeof HistoryPage>;
