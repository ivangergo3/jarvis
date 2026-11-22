import {expect, test} from 'vitest';
import {findOriginalTurn} from '../src/turn-recovery.js';

const clientId = 'c57d44c9-667c-405f-91b9-a4f54fd101a3';
const threadId = 'thread-one';
const metadata = {thread: {id: threadId}};
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
    {
      data: [
        entry('other', 'userMessage', null),
        entry('tool', 'agentMessage'),
      ],
      nextCursor: 'next',
    },
    {data: [entry('original')], nextCursor: null},
  ]);
  expect(await findOriginalTurn(reader, threadId, clientId)).toEqual({
    kind: 'observed-turn',
    threadId,
    turnId: 'original',
  });
  expect(reader.requests).toEqual([
    {method: 'thread/read', params: {threadId, includeTurns: false}},
    ...[null, 'next'].map((cursor) => ({
      method: 'thread/items/list',
      params: {threadId, cursor, limit: 50, sortDirection: 'asc'},
    })),
  ]);
});

test('missing conflicting malformed or truncated history never authorizes a resend', async () => {
  const hit = {data: [entry('first')], nextCursor: 'after'};
  for (const pages of [
    [{thread: {id: 'foreign'}}],
    [metadata, {data: [entry('wrong', 'agentMessage')]}],
    [metadata, hit, {data: [entry('second')]}],
    [metadata, hit, new Error('private detail')],
    [metadata, hit, {data: [{turnId: null}]}],
    [metadata, hit, {data: [], nextCursor: 'after'}],
    [metadata, {data: Array.from({length: 51}, () => entry('wrong'))}],
    [
      metadata,
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
      queueMicrotask(() => late.abort());
      return {data: [entry('late')]};
    },
  };
  expect(
    await findOriginalTurn(revokedBeforeDelivery, threadId, clientId),
  ).toEqual({kind: 'unknown'});
});
