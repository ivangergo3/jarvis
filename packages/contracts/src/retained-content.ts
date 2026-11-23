import {z} from 'zod';
import {ContentId, ContentRef, ImageRef} from './input.js';

export const HistoryContent = z.discriminatedUnion('kind', [
  z.strictObject({kind: z.literal('retained_text'), ref: ContentRef}),
  z.strictObject({kind: z.literal('retained_image'), ref: ImageRef}),
  z.strictObject({kind: z.literal('removed'), contentId: ContentId}),
  z.strictObject({
    kind: z.literal('truncated'),
    retainedBytes: z
      .int()
      .nonnegative()
      .max(8 * 1024 * 1024),
    cause: z.enum(['run_limit', 'owner_limit', 'storage_unavailable']),
  }),
]);
export type HistoryContent = z.infer<typeof HistoryContent>;
