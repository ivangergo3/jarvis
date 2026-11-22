import {z} from 'zod';

const id = z
  .string()
  .min(1)
  .max(512)
  .regex(/^[^\s\p{C}]+$/u);
const metadata = z.object({thread: z.object({id})});
const pageSize = 50;
const maxPages = 32;
const item = z.object({
  id,
  type: id,
  clientId: z.string().max(512).nullish(),
});
const page = z.object({
  data: z.array(z.object({turnId: id, item})).max(pageSize),
  nextCursor: z.string().min(1).max(8192).nullish(),
});

type HistoryRead =
  | {method: 'thread/read'; params: {threadId: string; includeTurns: false}}
  | {
      method: 'thread/items/list';
      params: {
        threadId: string;
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
  const read = (request: HistoryRead) => {
    signal.throwIfAborted();
    return Promise.race([reader.read(request, signal), aborted]);
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
    const seen = new Set<string>();
    let cursor: string | null = null;
    let found: string | undefined;
    for (let index = 0; index < maxPages; index++) {
      const result = page.safeParse(
        await read({
          method: 'thread/items/list',
          params: {threadId, cursor, limit: pageSize, sortDirection: 'asc'},
        }),
      );
      if (signal.aborted || !result.success) return unknown;
      for (const entry of result.data.data) {
        if (
          entry.item.type !== 'userMessage' ||
          entry.item.clientId !== clientUserMessageId
        )
          continue;
        if (found !== undefined) return unknown;
        found = entry.turnId;
      }
      const next = result.data.nextCursor;
      if (next === null || next === undefined) {
        return found === undefined
          ? unknown
          : {kind: 'observed-turn', threadId, turnId: found};
      }
      if (seen.has(next)) return unknown;
      seen.add(next);
      cursor = next;
    }
  } catch {
    // Transport errors can contain private provider text. No recovery evidence.
  } finally {
    observers.abort();
  }
  return unknown;
}
