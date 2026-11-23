import {z} from 'zod';

const id = z.uuid().lowercase();
export const OwnerId = id.brand<'OwnerId'>();
export const ProjectId = id.brand<'ProjectId'>();
export const SessionId = id.brand<'SessionId'>();
export const RunId = id.brand<'RunId'>();
export const EventId = id.brand<'EventId'>();
export const RequestId = id.brand<'RequestId'>();
export const GenerationId = id.brand<'GenerationId'>();
export const SnapshotId = id.brand<'SnapshotId'>();
export const CommandId = z.uuidv4().lowercase().brand<'CommandId'>();

export type OwnerId = z.infer<typeof OwnerId>;
export type ProjectId = z.infer<typeof ProjectId>;
export type SessionId = z.infer<typeof SessionId>;
export type RunId = z.infer<typeof RunId>;
export type EventId = z.infer<typeof EventId>;
export type RequestId = z.infer<typeof RequestId>;
export type GenerationId = z.infer<typeof GenerationId>;
export type SnapshotId = z.infer<typeof SnapshotId>;
export type CommandId = z.infer<typeof CommandId>;

export const Version = z.literal(1);
const versionHeader = z.object({schemaVersion: z.int().nonnegative()});
export function wireVersion(
  value: unknown,
): 'ok' | 'malformed' | 'unsupported_version' {
  const version = versionHeader.safeParse(value);
  if (!version.success) return 'malformed';
  return version.data.schemaVersion === Version.value
    ? 'ok'
    : 'unsupported_version';
}
export const Timestamp = z.iso.datetime({precision: 3});
export const Cursor = z
  .string()
  .max(19)
  .regex(/^(0|[1-9][0-9]*)$/)
  .refine((value) => value.length < 19 || value <= '9223372036854775807');
export const Sequence = Cursor.refine((value) => value !== '0');
export const Title = z
  .string()
  .min(1)
  .max(256)
  .refine((value) => value.trim().length > 0)
  // PostgreSQL text represents Unicode scalar values except NUL.
  .refine((value) => !value.includes('\0') && !/\p{Surrogate}/u.test(value));
export const ProjectTarget = z.strictObject({projectId: ProjectId});
export const SessionTarget = ProjectTarget.extend({sessionId: SessionId});
export const RunTarget = SessionTarget.extend({runId: RunId});
export const RequestTarget = RunTarget.extend({
  requestId: RequestId,
  generationId: GenerationId,
  revision: Sequence,
});

/** Size of an encoded JSON value, with strings measured in UTF-8 bytes. */
export function wireBytes(value: object): number {
  return utf8Bytes(JSON.stringify(value));
}

/** Number of bytes in an already encoded JSON frame, including original escapes. */
export function utf8Bytes(json: string): number {
  let bytes = 0;
  for (const symbol of json) {
    const unit = symbol.charCodeAt(0);
    if (symbol.length === 2) bytes += 4;
    else if (unit <= 0x7f) bytes++;
    else if (unit <= 0x7ff) bytes += 2;
    else bytes += 3;
  }
  return bytes;
}

export type Timestamp = z.infer<typeof Timestamp>;
export type Cursor = z.infer<typeof Cursor>;
export type Sequence = z.infer<typeof Sequence>;
export type Title = z.infer<typeof Title>;
export type ProjectTarget = z.infer<typeof ProjectTarget>;
export type SessionTarget = z.infer<typeof SessionTarget>;
export type RunTarget = z.infer<typeof RunTarget>;
export type RequestTarget = z.infer<typeof RequestTarget>;
