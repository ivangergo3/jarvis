import {z} from 'zod';
import {
  CommandId,
  Cursor,
  ProjectTarget,
  RunTarget,
  Sequence,
  SessionTarget,
  Title,
  Version,
} from './values.js';
import {
  Answer,
  AuthSessionId,
  ContentId,
  Digest,
  DraftInput,
  EpochId,
  LiveRequestTarget,
} from './input.js';

const header = {
  schemaVersion: Version,
  commandId: CommandId,
  controllerEpoch: EpochId,
  originatingSessionId: AuthSessionId,
};
export const RunRevisionTarget = RunTarget.extend({revision: Sequence});
// The service resolves this immutable local registration/provider selection
// and checks the original binding again before dispatch. It carries no credential.
export const FrozenDestination = SessionTarget.extend({
  bindingId: z.uuid().lowercase(),
  repositoryRevision: Sequence,
});
const noTarget = z.strictObject({});
const registration = z.strictObject({
  selectionId: z.uuid().lowercase(),
  expectedRevision: Cursor,
});
const commandFingerprint = z.strictObject({
  originalCommandId: CommandId,
  originalSessionId: AuthSessionId,
  originalControllerEpoch: EpochId,
  fingerprint: Digest,
});
const removal = SessionTarget.extend({
  entryId: z.uuid().lowercase(),
  entryRevision: Sequence,
  contentId: ContentId,
});
const runControls = z.enum([
  'run.cancel',
  'run.resume_queued',
  'run.settle_unsent',
  'run.reconcile',
]);
// An original command may never have arrived. Its operation and original admission
// epoch must be recoverable from this packet without reversing the fingerprint.
const retirement = z.discriminatedUnion('originalOperation', [
  commandFingerprint.extend({
    originalOperation: z.literal('project.create'),
    destination: noTarget,
  }),
  commandFingerprint.extend({
    originalOperation: z.enum([
      'session.create',
      'project.register_repository',
    ]),
    destination: ProjectTarget,
  }),
  commandFingerprint.extend({
    originalOperation: z.literal('run.submit'),
    destination: FrozenDestination,
  }),
  commandFingerprint.extend({
    originalOperation: runControls.or(
      z.literal('run.acknowledge_unknown_effect'),
    ),
    destination: RunRevisionTarget,
  }),
  commandFingerprint.extend({
    originalOperation: z.literal('request.answer'),
    destination: LiveRequestTarget,
  }),
  commandFingerprint.extend({
    originalOperation: z.literal('history.remove_content'),
    destination: removal,
  }),
  commandFingerprint.extend({
    originalOperation: z.literal('command.retire'),
    destination: z.strictObject({originalCommandId: CommandId}),
  }),
]);

export const Command = z
  .discriminatedUnion('operation', [
    z.strictObject({
      ...header,
      operation: z.literal('project.create'),
      target: noTarget,
      payload: z.strictObject({title: Title}),
    }),
    z.strictObject({
      ...header,
      operation: z.literal('project.register_repository'),
      target: ProjectTarget,
      payload: registration,
    }),
    z.strictObject({
      ...header,
      operation: z.literal('session.create'),
      target: ProjectTarget,
      payload: z.strictObject({title: Title}),
    }),
    z.strictObject({
      ...header,
      operation: z.literal('run.submit'),
      target: FrozenDestination,
      payload: DraftInput,
    }),
    z.strictObject({
      ...header,
      operation: runControls,
      target: RunRevisionTarget,
    }),
    z.strictObject({
      ...header,
      operation: z.literal('run.acknowledge_unknown_effect'),
      target: RunRevisionTarget,
      payload: z.strictObject({
        repositoryId: z.uuid().lowercase(),
        fenceRevision: Sequence,
      }),
    }),
    z.strictObject({
      ...header,
      operation: z.literal('request.answer'),
      target: LiveRequestTarget,
      payload: Answer,
    }),
    z.strictObject({
      ...header,
      operation: z.literal('history.remove_content'),
      target: removal,
    }),
    z.strictObject({
      ...header,
      operation: z.literal('command.retire'),
      target: retirement,
    }),
  ])
  .refine((command) => {
    if (command.operation === 'request.answer')
      return command.target.authSessionId === command.originatingSessionId;
    if (command.operation === 'command.retire')
      return (
        command.commandId !== command.target.originalCommandId &&
        command.originatingSessionId !== command.target.originalSessionId &&
        (command.target.originalOperation !== 'request.answer' ||
          command.target.originalSessionId ===
            command.target.destination.authSessionId)
      );
    return true;
  }, 'The command is not bound to its original session or retirement identity');
export type Command = z.infer<typeof Command>;

export type RunRevisionTarget = z.infer<typeof RunRevisionTarget>;
export type FrozenDestination = z.infer<typeof FrozenDestination>;
