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
import {AuthSessionId, ContentId, DraftInput, EpochId} from './input.js';

const header = {
  schemaVersion: Version,
  commandId: CommandId,
  controllerEpoch: EpochId,
  originatingSessionId: AuthSessionId,
};
export const RunRevisionTarget = RunTarget.extend({revision: Sequence});
/** Compare a parsed mutation with current trusted run state immediately before applying it. */
export function matchesRunRevision(
  requested: RunRevisionTarget,
  current: RunRevisionTarget,
): boolean {
  return (
    requested.projectId === current.projectId &&
    requested.sessionId === current.sessionId &&
    requested.runId === current.runId &&
    requested.revision === current.revision
  );
}

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
export const Command = z.discriminatedUnion('operation', [
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
    operation: z.literal('history.remove_content'),
    target: removal,
  }),
]);
export type Command = z.infer<typeof Command>;

export type RunRevisionTarget = z.infer<typeof RunRevisionTarget>;
export type FrozenDestination = z.infer<typeof FrozenDestination>;
