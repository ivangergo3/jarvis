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
  .refine((value) => value.trim().length > 0);
export const ProjectTarget = z.strictObject({projectId: ProjectId});
export const SessionTarget = ProjectTarget.extend({sessionId: SessionId});
export const RunTarget = SessionTarget.extend({runId: RunId});
export const RequestTarget = RunTarget.extend({
  requestId: RequestId,
  generationId: GenerationId,
  revision: Sequence,
});
