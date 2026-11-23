import {expect, test, vi} from 'vitest';
import {scanOriginalTurn} from '../src/turn-recovery.js';
import {qualifyCodexRecovery} from '../src/index.js';

// These cases exercise correlation after response schema qualification.
const findOriginalTurn = (reader, threadId, clientId) =>
  scanOriginalTurn(reader, threadId, clientId, () => true);

const clientId = 'c57d44c9-667c-405f-91b9-a4f54fd101a3';
const threadId = 'thread-one';
const metadata = {thread: {id: threadId, turns: []}};
const turnPage = (id, nextCursor = null) => ({
  data: [{id, items: [], itemsView: 'notLoaded', status: 'completed'}],
  nextCursor,
});
function entry(turnId, type = 'userMessage', id = clientId) {
  return {
    turnId,
    item: {
      id: type + '-' + turnId,
      type,
      ...(type === 'userMessage'
        ? {clientId: id, content: [{type: 'text', text: 'private text'}]}
        : {text: 'fixture'}),
    },
  };
}
function fixture(pages, controller = new AbortController()) {
  const requests = [];
  return {
    requests,
    signal: controller.signal,
    async read(request, signal) {
      expect(signal.aborted).toBe(false);
      requests.push(request);
      const value = pages.shift();
      if (value instanceof Error) throw value;
      return value;
    },
  };
}

test('only a single original client ID in fully paginated bound history corroborates a turn', async () => {
  const reader = fixture([
    metadata,
    turnPage('other', 'next-turn'),
    {data: [entry('other', 'userMessage', null)]},
    turnPage('original'),
    {data: [entry('original', 'agentMessage')], nextCursor: 'next-item'},
    {data: [entry('original')]},
  ]);
  expect(await findOriginalTurn(reader, threadId, clientId)).toEqual({
    kind: 'observed-turn',
    threadId,
    turnId: 'original',
  });
  expect(reader.requests.map((r) => r.method)).toEqual([
    'thread/read',
    'thread/turns/list',
    'thread/items/list',
    'thread/turns/list',
    'thread/items/list',
    'thread/items/list',
  ]);
  expect(reader.requests[0].params).toEqual({threadId, includeTurns: false});
  for (const r of reader.requests.slice(1)) {
    expect(r.params).toMatchObject({threadId, limit: 50, sortDirection: 'asc'});
    if (r.method === 'thread/turns/list')
      expect(r.params.itemsView).toBe('notLoaded');
    else
      expect(r.params.deferOutput).toEqual({
        commandExecution: true,
        mcpToolCall: true,
      });
  }
  expect(reader.requests[3].params.cursor).toBe('next-turn');
  expect(reader.requests[5].params).toMatchObject({
    cursor: 'next-item',
    turnId: 'original',
  });
});

test('missing conflicting malformed or truncated history never authorizes a resend', async () => {
  const hit = {data: [entry('first')], nextCursor: 'after'};
  for (const pages of [
    [{thread: {id: 'foreign'}}],
    [metadata, turnPage('wrong'), {data: [entry('wrong', 'agentMessage')]}],
    [metadata, turnPage('first'), hit, {data: [entry('second')]}],
    [metadata, turnPage('first'), hit, {data: [entry('first')]}],
    [
      metadata,
      turnPage('first', 'next'),
      {data: [entry('first')]},
      turnPage('second'),
      {data: [entry('second')]},
    ],
    [
      metadata,
      turnPage('first', 'next'),
      {data: [entry('first')]},
      turnPage('first'),
    ],
    [metadata, turnPage('first'), hit, new Error('private detail')],
    [metadata, turnPage('first'), hit, {data: [{turnId: null}]}],
    [metadata, turnPage('first'), hit, {data: [], nextCursor: 'after'}],
    [metadata, {data: Array.from({length: 51}, () => entry('wrong'))}],
    [
      metadata,
      turnPage('first'),
      hit,
      ...Array.from({length: 31}, (_, i) => ({
        data: [],
        nextCursor: String(i),
      })),
    ],
  ]) {
    const reader = fixture(pages);
    expect(await findOriginalTurn(reader, threadId, clientId)).toEqual({
      kind: 'unknown',
    });
    expect(reader.requests.length).toBeLessThanOrEqual(33);
  }
  const invalid = fixture([]);
  const cycle = fixture([
    metadata,
    turnPage('first'),
    hit,
    {data: [], nextCursor: 'after'},
    {data: []},
  ]);
  expect(await findOriginalTurn(cycle, threadId, clientId)).toEqual({
    kind: 'unknown',
  });
  expect(cycle.requests.map((r) => r.params.cursor)).toEqual([
    undefined,
    null,
    null,
    'after',
  ]);
  expect(
    await findOriginalTurn(invalid, threadId, 'similar-looking text'),
  ).toEqual({kind: 'unknown'});
  expect(invalid.requests).toHaveLength(0);
});

test('revocation before during or after a history read suppresses all late evidence', async () => {
  const controller = new AbortController();
  const started = Promise.withResolvers();
  const stalled = Promise.withResolvers();
  let calls = 0;
  const reader = {
    signal: controller.signal,
    read: async () => {
      if (++calls === 1) return metadata;
      started.resolve();
      return stalled.promise;
    },
  };
  const lookup = findOriginalTurn(reader, threadId, clientId);
  await started.promise;
  controller.abort();
  expect(await lookup).toEqual({kind: 'unknown'});
  stalled.resolve({data: [entry('late')]});
  expect(await findOriginalTurn(reader, threadId, clientId)).toEqual({
    kind: 'unknown',
  });
  expect(calls).toBe(2);
  const late = new AbortController();
  const revokedBeforeDelivery = {
    signal: late.signal,
    read: async (request) => {
      if (request.method === 'thread/read') return metadata;
      if (request.method === 'thread/turns/list') return turnPage('late');
      queueMicrotask(() => late.abort());
      return {data: [entry('late')]};
    },
  };
  expect(
    await findOriginalTurn(revokedBeforeDelivery, threadId, clientId),
  ).toEqual({kind: 'unknown'});
});

test('malformed inputs and conflicting item identities cannot corroborate a send', async () => {
  expect(qualifyCodexRecovery({})).toBeUndefined();
  const forged = Buffer.from('{"type":"object"}');
  expect(
    qualifyCodexRecovery({
      'thread/read': forged,
      'thread/turns/list': forged,
      'thread/items/list': forged,
    }),
  ).toBeUndefined();
  for (const invalidMethod of [
    'thread/read',
    'thread/turns/list',
    'thread/items/list',
  ]) {
    const reader = fixture([
      metadata,
      turnPage('first'),
      {data: [entry('first')]},
    ]);
    expect(
      await scanOriginalTurn(
        reader,
        threadId,
        clientId,
        (method) => method !== invalidMethod,
      ),
    ).toEqual({kind: 'unknown'});
  }
  expect(
    await findOriginalTurn(
      fixture([
        {thread: {id: threadId}},
        turnPage('first'),
        {data: [entry('first')]},
      ]),
      threadId,
      clientId,
    ),
  ).toEqual({kind: 'unknown'});
  for (const status of [undefined, 'unexpected', null]) {
    const turn = turnPage('first');
    if (status === undefined) delete turn.data[0].status;
    else turn.data[0].status = status;
    expect(
      await findOriginalTurn(
        fixture([metadata, turn, {data: [entry('first')]}]),
        threadId,
        clientId,
      ),
    ).toEqual({kind: 'unknown'});
  }
  for (const type of ['futureItem', 'agentMessage']) {
    const collision = entry('first', type);
    collision.item.clientId = clientId;
    expect(
      await findOriginalTurn(
        fixture([
          metadata,
          turnPage('first'),
          {data: [collision, entry('first')]},
        ]),
        threadId,
        clientId,
      ),
    ).toEqual({kind: 'unknown'});
  }
  const future = entry('first', 'futureItem');
  expect(
    await findOriginalTurn(
      fixture([metadata, turnPage('first'), {data: [future, entry('first')]}]),
      threadId,
      clientId,
    ),
  ).toEqual({kind: 'unknown'});
  for (const content of [
    undefined,
    'text',
    [42],
    [{type: 'text'}],
    [{type: 'image'}],
  ]) {
    const broken = entry('first');
    broken.item.content = content;
    expect(
      await findOriginalTurn(
        fixture([metadata, turnPage('first'), {data: [broken]}]),
        threadId,
        clientId,
      ),
    ).toEqual({kind: 'unknown'});
  }
  const conflicting = entry('first', 'userMessage', 'unrelated');
  const reader = fixture([
    metadata,
    turnPage('first'),
    {data: [conflicting], nextCursor: 'n'},
    {data: [entry('first')]},
  ]);
  expect(await findOriginalTurn(reader, threadId, clientId)).toEqual({
    kind: 'unknown',
  });
});

test('a buffered result past the elapsed deadline is unknown even before timer delivery', async () => {
  const deadline = new AbortController();
  const timeout = vi
    .spyOn(AbortSignal, 'timeout')
    .mockReturnValueOnce(deadline.signal);
  try {
    const started = Promise.withResolvers();
    const parent = new AbortController();
    const waiting = findOriginalTurn(
      {
        signal: parent.signal,
        async read() {
          started.resolve();
          return new Promise(() => {});
        },
      },
      threadId,
      clientId,
    );
    await started.promise;
    expect(timeout).toHaveBeenCalledWith(10_000);
    deadline.abort();
    expect(await waiting).toEqual({kind: 'unknown'});
    expect(parent.signal.aborted).toBe(false);
  } finally {
    timeout.mockRestore();
  }
  let time = 100;
  const now = vi.spyOn(performance, 'now').mockImplementation(() => time);
  try {
    const reader = fixture([
      metadata,
      turnPage('first'),
      {data: [entry('first')]},
    ]);
    const load = reader.read;
    reader.read = async (request, signal) => {
      const response = await load(request, signal);
      if (request.method === 'thread/items/list') time += 10_001;
      return response;
    };
    expect(await findOriginalTurn(reader, threadId, clientId)).toEqual({
      kind: 'unknown',
    });
    expect(reader.requests).toHaveLength(3);
  } finally {
    now.mockRestore();
  }
});
