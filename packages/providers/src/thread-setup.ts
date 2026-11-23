import {isDeepStrictEqual} from 'node:util';
import {z} from 'zod';
import {compilePinnedReply} from './pinned-schema.js';
import type {PendingTurnReceipt} from './turn-receipt.js';

/** The repository records this intent against the verified checkout and
 * account before starting a thread. No user turn exists at this point. */
export interface NewThreadIntent extends Omit<
  PendingTurnReceipt,
  'threadId' | 'clientUserMessageId'
> {
  readonly setupId: string;
  readonly cwd: string;
  readonly model: string;
  readonly cliVersion: string;
  readonly profile: string | null;
  readonly mode: 'readOnly' | 'workspaceWrite';
}

const label = z
  .string()
  .min(1)
  .max(512)
  .regex(/^[^\s\p{C}]+$/u);
const header = z.object({
  id: z.string(),
  method: z.never().optional(),
  error: z.never().optional(),
  result: z.object({
    model: z.string(),
    modelProvider: z.literal('openai'),
    cwd: z.string(),
    runtimeWorkspaceRoots: z.array(z.string()).default([]),
    approvalPolicy: z.literal('on-request'),
    approvalsReviewer: z.literal('user'),
    activePermissionProfile: z
      .object({
        id: z.string(),
        extends: z.null().optional(),
      })
      .nullish(),
    sandbox: z.unknown(),
    thread: z.object({
      id: label,
      modelProvider: z.literal('openai'),
      model: z.string().nullish(),
      cwd: z.string(),
      cliVersion: z.string(),
      ephemeral: z.literal(false),
      status: z.object({type: z.literal('idle')}),
      turns: z.tuple([]),
      parentThreadId: z.null().optional(),
      attachedToThreadId: z.null().optional(),
      forkedFromId: z.null().optional(),
    }),
  }),
});

type ThreadSetupResult =
  {kind: 'ignored' | 'unknown'} | {kind: 'bound'; threadId: string};

/** Qualify the output of thread/start only. An exact persistence receipt is
 * required before returning the provider thread ID. The function owns no
 * transport capability, so a missing receipt cannot re-create a thread. */
export function qualifyNewThreadReceipt(bytes: Uint8Array) {
  const check = compilePinnedReply(
    bytes,
    '1e3c5bf155d2861994e76b63ab5c1f23b9e265aac79bbe7515a28028b179b4b8',
  );
  if (!check) return undefined;
  return async (
    intent: NewThreadIntent,
    source: Pick<NewThreadIntent, 'channelId' | 'generationId'> & {
      /** Supplied by the host that confines this worker. The legacy sandbox
       * reply reports additional writable roots but cannot prove read scope. */
      readonly confinement?: {
        readonly generationId: string;
        readonly channelId: string;
        readonly cwd: string;
        readonly mode: NewThreadIntent['mode'];
        readonly profile: string | null;
        readonly readableRoots: readonly string[];
        readonly writableRoots: readonly string[];
        readonly networkAccess: boolean;
      };
    },
    frame: unknown,
    signal: AbortSignal,
    commit: (
      original: NewThreadIntent,
      threadId: string,
      signal: AbortSignal,
    ) => Promise<boolean>,
  ): Promise<ThreadSetupResult> => {
    if (
      source.channelId !== intent.channelId ||
      source.generationId !== intent.generationId ||
      !frame ||
      typeof frame !== 'object' ||
      !('id' in frame) ||
      frame.id !== intent.rpcId
    )
      return {kind: 'ignored'};
    if (signal.aborted || !('result' in frame) || !check(frame.result))
      return {kind: 'unknown'};
    const parsed = header.safeParse(frame);
    if (!parsed.success) return {kind: 'unknown'};
    const value = parsed.data.result;
    const thread = value.thread;
    const roots = value.runtimeWorkspaceRoots;
    if (
      value.cwd !== intent.cwd ||
      thread.cwd !== intent.cwd ||
      thread.cliVersion !== intent.cliVersion ||
      value.model !== intent.model ||
      (thread.model !== null &&
        thread.model !== undefined &&
        thread.model !== intent.model) ||
      (value.activePermissionProfile?.id ?? null) !== intent.profile ||
      roots.length !== 1 ||
      roots[0] !== intent.cwd
    )
      return {kind: 'unknown'};
    const confinement = source.confinement;
    if (
      !confinement ||
      confinement.generationId !== intent.generationId ||
      confinement.channelId !== intent.channelId ||
      confinement.cwd !== intent.cwd ||
      confinement.mode !== intent.mode ||
      confinement.profile !== intent.profile ||
      confinement.networkAccess !== false ||
      !isDeepStrictEqual(confinement.readableRoots, [intent.cwd]) ||
      !isDeepStrictEqual(
        confinement.writableRoots,
        intent.mode === 'readOnly' ? [] : [intent.cwd],
      )
    )
      return {kind: 'unknown'};

    const sandbox =
      intent.mode === 'readOnly'
        ? {type: 'readOnly', networkAccess: false}
        : {
            type: 'workspaceWrite',
            writableRoots: [],
            networkAccess: false,
            excludeSlashTmp: true,
            excludeTmpdirEnvVar: true,
          };
    if (!isDeepStrictEqual(sandbox, value.sandbox)) return {kind: 'unknown'};
    const original = Object.freeze({
      ...intent,
      target: Object.freeze({...intent.target}),
    });
    try {
      if ((await commit(original, thread.id, signal)) && !signal.aborted)
        return {kind: 'bound', threadId: thread.id};
    } catch {
      // A failed acknowledgement may follow a committed binding.
    }
    return {kind: 'unknown'};
  };
}
