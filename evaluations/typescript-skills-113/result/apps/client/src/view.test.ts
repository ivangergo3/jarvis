import assert from 'node:assert/strict';
import test from 'node:test';
import {View} from './view.ts';

test('select retains the latest conversation after a late reply', async () => {
  const first = {id: 'chat-a', name: 'Design'};
  const second = {id: 'chat-b', name: 'Design'};
  const older = Promise.withResolvers<string>();
  const newer = Promise.withResolvers<string>();
  const reads: string[] = [];
  const read = (id: string) => {
    reads.push(id);
    return id === first.id ? older.promise : newer.promise;
  };
  const view = new View();
  const pendingFirst = view.select(first.id, read);
  const pendingSecond = view.select(second.id, read);
  newer.resolve('message B');
  await pendingSecond;
  assert.equal(view.selected, second.id);
  assert.equal(view.message, 'message B');
  older.resolve('message A');
  await pendingFirst;
  assert.deepEqual(reads, [first.id, second.id]);
  assert.equal(view.selected, second.id);
  assert.equal(view.message, 'message B');
});

test('select clears the previous message while a different selection loads', async () => {
  const view = new View();
  await view.select('chat-a', async () => 'message A');
  const next = Promise.withResolvers<string>();
  const pending = view.select('chat-b', () => next.promise);
  assert.equal(view.selected, 'chat-b');
  assert.equal(view.message, '');
  next.resolve('message B');
  await pending;
  assert.equal(view.message, 'message B');
});

test('select ignores the first read after reopening the same conversation', async () => {
  const view = new View();
  const old = Promise.withResolvers<string>();
  const pending = view.select('chat-a', () => old.promise);
  await view.select('chat-b', async () => 'message B');
  await view.select('chat-a', async () => 'current A');
  old.resolve('stale A');
  await pending;
  assert.equal(view.selected, 'chat-a');
  assert.equal(view.message, 'current A');
});
