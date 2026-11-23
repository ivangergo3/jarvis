import {z} from 'zod';

const id = z
  .string()
  .min(1)
  .max(512)
  .regex(/^[^\s\p{C}]+$/u);
const metadata = z.object({
  thread: z.object({id, turns: z.tuple([]).optional()}),
});
const pageSize = 50;
const maxPages = 32;
const item = z.object({
  id,
  type: id,
  clientId: z.string().max(512).nullish(),
});
const cursorValue = z.string().min(1).max(8192).nullish();
const turnsPage = z.object({
  data: z
    .array(
      z.object({
        id,
        items: z.tuple([]),
        itemsView: z.literal('notLoaded').optional(),
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
export async function findOriginalTurn(
  reader: CodexRecoveryReader,
  threadId: string,
  clientUserMessageId: string,
): Promise<Evidence> {
  const unknown = {kind: 'unknown'} as const;
  if (
    !id.safeParse(threadId).success ||
    !z.uuidv4().safeParse(clientUserMessageId).success
  )
    return unknown;
  const signal = AbortSignal.any([reader.signal, AbortSignal.timeout(10_000)]);
  if (signal.aborted) return unknown;
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
    signal.throwIfAborted();
    if (remaining-- <= 0) throw new Error('History limit reached');
    const result = await Promise.race([reader.read(request, signal), aborted]);
    signal.throwIfAborted();
    return result;
  };

  try {
    const record = metadata.safeParse(
      await read({
        method: 'thread/read',
        params: {threadId, includeTurns: false},
      }),
    );
    if (signal.aborted || !record.success || record.data.thread.id !== threadId)
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
      for await (const entry of items) {
        if (entry.turnId !== turn.id) return unknown;
        if (
          entry.item.type !== 'userMessage' ||
          entry.item.clientId !== clientUserMessageId
        )
          continue;
        if (found !== undefined) return unknown;
        found = turn.id;
      }
    }
    return found === undefined || signal.aborted
      ? unknown
      : {kind: 'observed-turn', threadId, turnId: found};
  } catch {
    // Transport errors can contain private provider text. No recovery evidence.
  } finally {
    observers.abort();
  }
  return unknown;
}
