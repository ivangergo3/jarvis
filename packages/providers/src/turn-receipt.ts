import {z} from 'zod';
import type {CodexRunBinding} from './run-notification.js';

type Destination = Omit<CodexRunBinding, 'turnId'>;

/** Captured by the service before the original turn/start handoff. The RPC
 * reply itself contains no thread, owner, repository or generation identity. */
export interface PendingTurnReceipt extends Destination {
  readonly channelId: string;
  readonly rpcId: string;
  readonly clientUserMessageId: string;
}

const id = z
  .string()
  .min(1)
  .max(512)
  .regex(/^[^\s\p{C}]+$/u);
const turn = z.object({
  id,
  status: z.enum(['inProgress', 'completed', 'failed', 'interrupted']),
  items: z.array(z.unknown()),
});
const reply = z.object({
  id: z.string(),
  error: z.never().optional(),
  method: z.never().optional(),
  result: z.object({turn}),
});

type BindingResult =
  {kind: 'ignored' | 'unknown'} | {kind: 'bound'; binding: CodexRunBinding};

/** Persist the observed binding before attaching the notification mapper.
 * bindOriginal must atomically check the original pending intent, owner,
 * channel and generation and accept only an identical replay. A thrown
 * write or revocation leaves the caller uncertain even if a write landed. */
export async function acceptTurnReceipt(
  pending: PendingTurnReceipt,
  source: Pick<PendingTurnReceipt, 'channelId' | 'generationId'>,
  frame: unknown,
  signal: AbortSignal,
  bindOriginal: (
    intent: PendingTurnReceipt,
    turnId: string,
    signal: AbortSignal,
  ) => Promise<boolean>,
): Promise<BindingResult> {
  if (
    source.channelId !== pending.channelId ||
    source.generationId !== pending.generationId
  )
    return {kind: 'ignored'};
  if (signal.aborted) return {kind: 'unknown'};
  if (
    typeof frame !== 'object' ||
    !frame ||
    !('id' in frame) ||
    frame.id !== pending.rpcId
  )
    return {kind: 'ignored'};
  const result = reply.safeParse(frame);
  if (!result.success) return {kind: 'unknown'};
  const turnId = result.data.result.turn.id;
  try {
    const bound = await bindOriginal(pending, turnId, signal);
    if (!bound || signal.aborted) return {kind: 'unknown'};
  } catch {
    return {kind: 'unknown'};
  }
  return {
    kind: 'bound',
    binding: {
      ownerId: pending.ownerId,
      generationId: pending.generationId,
      target: pending.target,
      threadId: pending.threadId,
      turnId,
    },
  };
}
