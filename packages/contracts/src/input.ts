import {z} from 'zod';
import {Sequence} from './values.js';

const id = z.uuid().lowercase();
export const AuthSessionId = id.brand<'AuthSessionId'>();
export const EpochId = id.brand<'EpochId'>();
export const ContentId = id.brand<'ContentId'>();
export const AttachmentId = id.brand<'AttachmentId'>();
export const Digest = z.string().regex(/^[a-f0-9]{64}$/);
export const ContentDigest = z
  .strictObject({
    bytes: z
      .int()
      .min(0)
      .max(128 * 1024 * 1024),
    sha256: Digest,
  })
  .refine(
    (value) =>
      value.bytes > 0 ||
      value.sha256 ===
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    'Empty content requires the SHA-256 digest of zero bytes',
  );
export const ContentRef = ContentDigest.safeExtend({contentId: ContentId});
export const ImageRef = ContentRef.safeExtend({
  attachmentId: AttachmentId,
  mime: z.literal('image/png'),
  bytes: z
    .int()
    .positive()
    .max(20 * 1024 * 1024),
});
export const DraftInput = z
  .strictObject({
    revision: Sequence,
    text: ContentRef,
    images: z.array(ImageRef).max(6),
  })
  .refine(
    (value) => value.text.bytes > 0 || value.images.length > 0,
    'A run needs text or an image',
  )
  .refine(
    (value) =>
      new Set(value.images.map((image) => image.attachmentId)).size ===
      value.images.length,
    'Duplicate attachment',
  )
  .refine(
    (value) =>
      new Set([
        value.text.contentId,
        ...value.images.map((image) => image.contentId),
      ]).size ===
      value.images.length + 1,
    'Duplicate content reference',
  );
export type DraftInput = z.infer<typeof DraftInput>;

export type AuthSessionId = z.infer<typeof AuthSessionId>;
export type EpochId = z.infer<typeof EpochId>;
export type ContentId = z.infer<typeof ContentId>;
export type AttachmentId = z.infer<typeof AttachmentId>;
export type Digest = z.infer<typeof Digest>;
export type ContentRef = z.infer<typeof ContentRef>;
export type ImageRef = z.infer<typeof ImageRef>;
