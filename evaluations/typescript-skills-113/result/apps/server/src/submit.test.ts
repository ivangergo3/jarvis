import assert from 'node:assert/strict';
import test from 'node:test';
import type {Request} from '@example/contracts';
import {submit} from './submit.ts';

const owned: Request = {version: 1, projectId: 'project-a', sessionId: 'session-a', text: 'hello'};

function recordDispatch() {
  const lookups: string[][] = [];
  const enqueued: Request[] = [];
  return {
    lookups, enqueued,
    owns(projectId: string, sessionId: string) {
      lookups.push([projectId, sessionId]);
      return projectId === owned.projectId && sessionId === owned.sessionId;
    },
    enqueue(command: Request) {
      enqueued.push(command);
    },
  };
}

const malformed: [string, unknown][] = [
  ['null', null],
  ['future version', {...owned, version: 2}],
  ['missing text', {version: 1, projectId: owned.projectId, sessionId: owned.sessionId}],
  ['wrong text type', {...owned, text: 123}],
  ['empty project', {...owned, projectId: ''}],
  ['empty session', {...owned, sessionId: ''}],
  ['empty text', {...owned, text: ''}],
  ['oversize text', {...owned, text: 'a'.repeat(65)}],
  ['unknown field', {...owned, extra: true}],
];
for (const [name, raw] of malformed) {
  test(`rejects ${name} before any lookup or dispatch`, () => {
    const dispatch = recordDispatch();
    assert.equal(submit(raw, dispatch), 'invalid');
    assert.deepEqual(dispatch.lookups, []);
    assert.deepEqual(dispatch.enqueued, []);
  });
}

for (const raw of [{...owned, projectId: 'project-b'}, {...owned, sessionId: 'session-b'}]) {
  test(`denies inaccessible pair ${raw.projectId}/${raw.sessionId}`, () => {
    const dispatch = recordDispatch();
    assert.equal(submit(raw, dispatch), 'denied');
    assert.deepEqual(dispatch.lookups, [[raw.projectId, raw.sessionId]]);
    assert.deepEqual(dispatch.enqueued, []);
  });
}

test('dispatches the valid owned command once', () => {
  const dispatch = recordDispatch();
  const raw = {...owned, text: 'a'.repeat(64)};
  assert.equal(submit(JSON.parse(JSON.stringify(raw)), dispatch), 'accepted');
  assert.deepEqual(dispatch.lookups, [[raw.projectId, raw.sessionId]]);
  assert.deepEqual(dispatch.enqueued, [raw]);
});
