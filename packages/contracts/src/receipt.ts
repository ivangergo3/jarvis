import {z} from 'zod';
import {
  CommandId,
  OwnerId,
  ProjectTarget,
  RequestTarget,
  RunTarget,
  Sequence,
  SessionTarget,
  Timestamp,
  Version,
} from './values.js';
import {AuthSessionId, ContentId, Digest, EpochId} from './input.js';
import {TakeoverId} from './staging.js';
import {StagingId} from './staging-id.js';
import {CancellationObservation} from './lifecycle.js';

const stamp = {
  schemaVersion: Version,
  commandId: CommandId,
  ownerId: OwnerId,
  originatingSessionId: AuthSessionId,
  controllerEpoch: EpochId,
  fingerprint: Digest,
  recordedAt: Timestamp,
  sequence: Sequence,
};
export const ErrorCode = z.enum([
  'invalid_payload',
  'unsupported_version',
  'unsupported_operation',
  'sign_in_required',
  'action_denied',
  'target_not_found',
  'command_id_reused',
  'stale_revision',
  'destination_mismatch',
  'request_retired',
  'expired_cursor',
  'staging_retired',
  'input_too_large',
  'queue_full',
  'service_stopping',
  'dependency_unavailable',
  'capability_unavailable',
  'commit_unknown',
  'delivery_unknown',
]);
export type ErrorCode = z.infer<typeof ErrorCode>;
const statusByCode = {
  invalid_payload: 400,
  unsupported_version: 400,
  unsupported_operation: 400,
  sign_in_required: 401,
  action_denied: 403,
  target_not_found: 404,
  command_id_reused: 409,
  stale_revision: 409,
  destination_mismatch: 409,
  request_retired: 409,
  expired_cursor: 410,
  staging_retired: 410,
  input_too_large: 413,
  queue_full: 429,
  service_stopping: 503,
  dependency_unavailable: 503,
  capability_unavailable: 503,
  commit_unknown: 503,
  delivery_unknown: 503,
} as const satisfies Record<ErrorCode, number>;
export function httpStatus(code: ErrorCode): number {
  return statusByCode[code];
}
const ambiguousCodes = ['commit_unknown', 'delivery_unknown'] as const;
export const ServiceError = z.discriminatedUnion('code', [
  z.strictObject({
    schemaVersion: Version,
    code: ErrorCode.exclude(ambiguousCodes),
  }),
  z.strictObject({
    schemaVersion: Version,
    code: z.enum(ambiguousCodes),
    commandId: z.union([CommandId, StagingId, TakeoverId]),
  }),
]);
export type ServiceError = z.infer<typeof ServiceError>;

const accepted = {...stamp, status: z.literal('accepted')};
const acceptance = z.discriminatedUnion('operation', [
  z.strictObject({
    ...accepted,
    operation: z.literal('project.create'),
    target: ProjectTarget,
  }),
  z.strictObject({
    ...accepted,
    operation: z.literal('project.register_repository'),
    target: ProjectTarget,
    repositoryRevision: Sequence,
  }),
  z.strictObject({
    ...accepted,
    operation: z.literal('session.create'),
    target: SessionTarget,
  }),
  z.strictObject({
    ...accepted,
    operation: z.literal('history.remove_content'),
    target: SessionTarget.extend({
      entryId: z.uuid().lowercase(),
      entryRevision: Sequence,
      contentId: ContentId,
    }),
  }),
  z.strictObject({
    ...accepted,
    operation: z.literal('run.submit'),
    target: RunTarget,
    draftRevision: Sequence,
  }),
  z.strictObject({
    ...accepted,
    operation: z.literal('run.cancel'),
    target: RunTarget,
    revision: Sequence,
    observation: CancellationObservation,
  }),
  z.strictObject({
    ...accepted,
    operation: z.enum([
      'run.resume_queued',
      'run.settle_unsent',
      'run.reconcile',
      'run.acknowledge_unknown_effect',
    ]),
    target: RunTarget,
  }),
  z.strictObject({
    ...accepted,
    operation: z.literal('request.answer'),
    target: RequestTarget,
  }),
  z.strictObject({
    ...accepted,
    operation: z.literal('command.retire'),
    target: z.strictObject({originalCommandId: CommandId}),
  }),
]);
const refusal = ErrorCode.exclude([
  'command_id_reused',
  'commit_unknown',
  'delivery_unknown',
  'sign_in_required',
  'dependency_unavailable',
  'expired_cursor',
  'staging_retired',
]);
const attempted = z.discriminatedUnion('operation', [
  z.strictObject({
    operation: z.literal('project.create'),
    target: z.strictObject({}),
  }),
  z.strictObject({
    operation: z.enum(['project.register_repository', 'session.create']),
    target: ProjectTarget,
  }),
  z.strictObject({
    operation: z.enum(['run.submit', 'history.remove_content']),
    target: SessionTarget,
  }),
  z.strictObject({
    operation: z.enum([
      'run.cancel',
      'run.resume_queued',
      'run.settle_unsent',
      'run.reconcile',
      'run.acknowledge_unknown_effect',
    ]),
    target: RunTarget,
  }),
  z.strictObject({
    operation: z.literal('request.answer'),
    target: RequestTarget,
  }),
  z.strictObject({
    operation: z.literal('command.retire'),
    target: z.strictObject({originalCommandId: CommandId}),
  }),
]);
export const Receipt = z.union([
  acceptance,
  z.strictObject({
    ...stamp,
    status: z.literal('definitively_refused'),
    reason: refusal,
    attempted,
  }),
  z.strictObject({...stamp, status: z.literal('retired_unsent'), attempted}),
]);
export type Receipt = z.infer<typeof Receipt>;
