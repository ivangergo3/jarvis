import {expect, test} from 'vitest';
import {findOriginalTurn} from '../src/turn-recovery.js';

const clientId = 'c57d44c9-667c-405f-91b9-a4f54fd101a3';
const threadId = 'thread-one';
const metadata = {thread: {id: threadId}};
const turnPage = (id, nextCursor = null) => ({
  data: [{id, items: [], itemsView: 'notLoaded'}],
  nextCursor,
});
function entry(turnId, type = 'userMessage', id = clientId) {
  return {
    turnId,
    item: {id: 'i-' + turnId, type, clientId: id, content: 'private text'},
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
