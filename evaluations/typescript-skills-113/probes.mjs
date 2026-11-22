import assert from 'node:assert/strict';
import test from 'node:test';
import {submit} from './apps/server/src/submit.ts';
import {View} from './apps/client/src/view.ts';

const command = {version: 1, projectId: 'A', sessionId: '1', text: 'Inspect'};

test('only a parsed command for an owned destination reaches the queue', () => {
  const lookups = [];
  const queued = [];
  const dispatch = {
    owns(project, session) {
      lookups.push([project, session]);
      return project === 'A' && session === '1';
    },
    enqueue(value) {
      queued.push(value);
    },
  };
  for (const input of [
    null,
    {...command, version: 2},
    {...command, text: 'x'.repeat(65)},
    {...command, sessionId: 1},
    {...command, token: 'synthetic'},
  ]) {
    assert.equal(submit(input, dispatch), 'invalid');
  }
  assert.deepEqual(lookups, []);
  assert.deepEqual(queued, []);
  assert.equal(submit({...command, projectId: 'B'}, dispatch), 'denied');
  assert.deepEqual(queued, []);
  assert.equal(submit(command, dispatch), 'accepted');
  assert.deepEqual(queued, [command]);
  assert.deepEqual(lookups, [
    ['B', '1'],
    ['A', '1'],
  ]);
});

test('a late completion leaves the selected conversation visible', async () => {
  const view = new View();
  const first = Promise.withResolvers();
  const second = Promise.withResolvers();
  const early = view.select('first', () => first.promise);
  const recent = view.select('second', () => second.promise);
  second.resolve('second reply');
  await recent;
  first.resolve('first reply');
  await early;
  assert.equal(view.selected, 'second');
  assert.equal(view.message, 'second reply');
});
