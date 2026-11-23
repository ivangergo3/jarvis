import {z} from 'zod';

const id = z
  .string()
  .min(1)
  .max(512)
  .regex(/^[^\s\p{C}]+$/u);
const metadata = z.object({
  thread: z.object({id, turns: z.tuple([])}),
});
const pageSize = 50;
const maxPages = 32;
const detail = z.enum(['auto', 'low', 'high', 'original']).nullish();
const offset = z.number().int().nonnegative();
const textElement = z.object({
  byteRange: z.object({start: offset, end: offset}),
  placeholder: z.string().nullish(),
});
const remoteMedia = z
  .object({url: z.string()})
  .or(z.object({fileId: z.string()}));
const contentPart = z.union([
  z.object({
    type: z.literal('text'),
    text: z.string(),
    text_elements: z.array(textElement).optional(),
  }),
  z.object({type: z.literal('image'), detail}).and(remoteMedia),
  z.object({type: z.literal('audio')}).and(remoteMedia),
  z.object({type: z.literal('localImage'), path: z.string(), detail}),
  z.object({type: z.literal('localAudio'), path: z.string()}),
  z.object({
    type: z.enum(['skill', 'mention']),
    name: z.string(),
    path: z.string(),
  }),
]);
const contents = z.array(contentPart);
// Discriminators in the pinned Codex v2 ThreadItem schema. A future item
// variant may carry a different relationship to the sought client ID.
const itemType = z.enum([
  'userMessage',
  'hookPrompt',
  'agentMessage',
  'functionCallOutput',
  'plan',
  'reasoning',
  'commandExecution',
  'fileChange',
  'mcpToolCall',
  'dynamicToolCall',
  'collabAgentToolCall',
  'subAgentActivity',
  'webSearch',
  'imageView',
  'sleep',
  'imageGeneration',
  'enteredReviewMode',
  'exitedReviewMode',
  'contextCompaction',
]);
const item = z
  .object({
    id,
    type: itemType,
    clientId: z.string().max(512).nullish(),
    content: z.unknown().optional(),
  })
  .refine((entry) =>
    entry.type === 'userMessage'
      ? contents.safeParse(entry.content).success
      : entry.clientId === undefined,
  );
const cursorValue = z.string().min(1).max(8192).nullish();
const turnsPage = z.object({
  data: z
    .array(
      z.object({
        id,
        status: z.enum(['completed', 'interrupted', 'failed', 'inProgress']),
        items: z.tuple([]),
        itemsView: z.literal('notLoaded'),
      }),
    )
    .max(pageSize),
  nextCursor: cursorValue,
});
const itemsPage = z.object({
  data: z.array(z.object({turnId: id, item})).max(pageSize),
  nextCursor: cursorValue,
});

type HistoryRead =
  | {method: 'thread/read'; params: {threadId: string; includeTurns: false}}
  | {
      method: 'thread/turns/list';
      params: {
        threadId: string;
        cursor: string | null;
        limit: number;
        sortDirection: 'asc';
        itemsView: 'notLoaded';
      };
    }
  | {
      method: 'thread/items/list';
      params: {
        threadId: string;
        turnId: string;
        deferOutput: {commandExecution: true; mcpToolCall: true};
        cursor: string | null;
        limit: number;
        sortDirection: 'asc';
      };
    };

/** A recovery-only channel already bound to the authenticated owner, frozen
 * repository/worker identity and a quiescent history. Its transport enforces
 * frame size and checks its revocable permit at actual handoff and delivery. */
export interface CodexRecoveryReader {
  readonly signal: AbortSignal;
  read(request: HistoryRead, signal: AbortSignal): Promise<unknown>;
}

type Evidence =
  {kind: 'unknown'} | {kind: 'observed-turn'; threadId: string; turnId: string};

async function* pages<T>(
  load: (
    cursor: string | null,
  ) => Promise<{data: T[]; nextCursor?: string | null | undefined}>,
) {
  const seen = new Set<string>();
  let cursor: string | null = null;
  for (;;) {
    const response = await load(cursor);
    yield* response.data;
    const next = response.nextCursor;
    if (next === null || next === undefined) return;
    if (seen.has(next)) throw new Error('Repeated history cursor');
    seen.add(next);
    cursor = next;
  }
}

/** Corroborate a previously persisted send. Even complete history without a
 * match is inconclusive. This lookup cannot resume, resend or complete work. */
export async function scanOriginalTurn(
  reader: CodexRecoveryReader,
  threadId: string,
  clientUserMessageId: string,
  validate: (method: HistoryRead['method'], response: unknown) => boolean,
): Promise<Evidence> {
  const unknown = {kind: 'unknown'} as const;
  if (
    !id.safeParse(threadId).success ||
    !z.uuidv4().safeParse(clientUserMessageId).success
  )
    return unknown;
  const deadline = performance.now() + 10_000;
  const signal = AbortSignal.any([reader.signal, AbortSignal.timeout(10_000)]);
  const expired = () => signal.aborted || performance.now() >= deadline;
  if (expired()) return unknown;
  const observers = new AbortController();
  const aborted = new Promise<void>((resolve) => {
    signal.addEventListener('abort', () => resolve(), {
      once: true,
      signal: observers.signal,
    });
  });
  // An unresponsive worker must not keep its caller waiting after revocation.
  let remaining = maxPages + 1;
  const read = async (request: HistoryRead) => {
    if (expired()) throw new Error('History lookup expired');
    if (remaining-- <= 0) throw new Error('History limit reached');
    const result = await Promise.race([reader.read(request, signal), aborted]);
    if (expired() || !validate(request.method, result))
      throw new Error('Unqualified history reply');
    return result;
  };

  try {
    const record = metadata.safeParse(
      await read({
        method: 'thread/read',
        params: {threadId, includeTurns: false},
      }),
    );
    if (expired() || !record.success || record.data.thread.id !== threadId)
      return unknown;
    const turns = pages(async (cursor) =>
      turnsPage.parse(
        await read({
          method: 'thread/turns/list',
          params: {
            threadId,
            cursor,
            limit: pageSize,
            sortDirection: 'asc',
            itemsView: 'notLoaded',
          },
        }),
      ),
    );
    const seenTurns = new Set<string>();
    let found: string | undefined;
    for await (const turn of turns) {
      if (seenTurns.has(turn.id)) return unknown;
      seenTurns.add(turn.id);
      const items = pages(async (cursor) =>
        itemsPage.parse(
          await read({
            method: 'thread/items/list',
            params: {
              threadId,
              turnId: turn.id,
              cursor,
              limit: pageSize,
              sortDirection: 'asc',
              deferOutput: {commandExecution: true, mcpToolCall: true},
            },
          }),
        ),
      );
      const seenItems = new Set<string>();
      for await (const entry of items) {
        if (entry.turnId !== turn.id || seenItems.has(entry.item.id))
          return unknown;
        seenItems.add(entry.item.id);
        if (
          entry.item.type !== 'userMessage' ||
          entry.item.clientId !== clientUserMessageId
        )
          continue;
        if (found !== undefined) return unknown;
        found = turn.id;
      }
    }
    return found === undefined || expired()
      ? unknown
      : {kind: 'observed-turn', threadId, turnId: found};
  } catch {
    // Transport errors can contain private provider text. No recovery evidence.
  } finally {
    observers.abort();
  }
  return unknown;
}
