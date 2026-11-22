import {z} from 'zod';
import type {
  Event,
  GenerationId,
  OwnerId,
  RunObservation,
} from '@jarvis/contracts';

export interface CodexRunBinding {
  readonly ownerId: OwnerId;
  readonly target: Extract<Event, {kind: 'run.state'}>['target'];
  readonly generationId: GenerationId;
  readonly threadId: string;
  readonly turnId: string;
}

type ProjectedNotification =
  | {kind: 'ignored' | 'malformed'}
  | {kind: 'provider-interrupted'; binding: CodexRunBinding}
  | {kind: 'run-state'; binding: CodexRunBinding; observation: RunObservation}
  | {
      kind: 'private-assistant-text';
      binding: CodexRunBinding;
      itemId: string;
      text: string;
    }
  | {
      kind: 'private-item-withheld' | 'private-item-too-large';
      binding: CodexRunBinding;
      itemId: string;
    };

const providerId = z
  .string()
  .min(1)
  .max(512)
  .regex(/^[^\s\p{C}]+$/u);
const notification = z.object({
  method: z.string(),
  params: z.object({threadId: providerId}).passthrough(),
  id: z.never().optional(),
  result: z.never().optional(),
  error: z.never().optional(),
});
const turn = z.object({
  id: providerId,
  status: z.enum(['inProgress', 'completed', 'failed', 'interrupted']),
});
const itemHeader = z.object({type: z.string(), id: providerId});
const assistant = z.object({
  text: z.string(),
  // An actionable question and a restricted response have their own protected
  // surfaces. Unknown visibility metadata must never make prose visible.
  questions: z.tuple([]).nullish(),
  moderation: z
    .object({moderated: z.literal(false), display: z.null().optional()})
    .nullish(),
  delivery: z.null().optional(),
});
const outputLimit = 8 * 1024 * 1024;

/** Decode already bounded frames from a Jarvis-owned channel. Persist private
 * items under (binding, itemId); their text must not enter the public event log. */
export function mapRunNotification(
  binding: CodexRunBinding,
  sourceGeneration: GenerationId,
  value: unknown,
): ProjectedNotification {
  if (sourceGeneration !== binding.generationId) return {kind: 'ignored'};
  const frame = notification.safeParse(value);
  if (!frame.success) return {kind: 'malformed'};
  const {method, params} = frame.data;
  if (params.threadId !== binding.threadId) return {kind: 'ignored'};
  if (method === 'turn/started' || method === 'turn/completed') {
    const parsed = turn.safeParse(params.turn);
    if (!parsed.success) return {kind: 'malformed'};
    if (parsed.data.id !== binding.turnId) return {kind: 'ignored'};
    const status = parsed.data.status;
    if ((method === 'turn/started') !== (status === 'inProgress'))
      return {kind: 'malformed'};
    if (status === 'interrupted')
      return {kind: 'provider-interrupted', binding};
    const observation: RunObservation =
      status === 'inProgress'
        ? {state: 'running'}
        : status === 'failed'
          ? {state: 'failed', reason: 'execution_failed'}
          : {state: 'completed'};
    return {kind: 'run-state', binding, observation};
  }
  if (method !== 'item/completed') return {kind: 'ignored'};
  if (typeof params.turnId !== 'string') return {kind: 'malformed'};
  if (params.turnId !== binding.turnId) return {kind: 'ignored'};
  const header = itemHeader.safeParse(params.item);
  if (!header.success) return {kind: 'malformed'};
  if (header.data.type !== 'agentMessage') return {kind: 'ignored'};
  const itemId = header.data.id;
  const parsed = assistant.safeParse(params.item);
  if (!parsed.success) return {kind: 'private-item-withheld', binding, itemId};
  const {text} = parsed.data;
  if (
    text.length > outputLimit ||
    Buffer.byteLength(text, 'utf8') > outputLimit
  )
    return {kind: 'private-item-too-large', binding, itemId};
  return {kind: 'private-assistant-text', binding, itemId, text};
}
