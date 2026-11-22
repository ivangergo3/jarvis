import {expect, it} from 'vitest';
import {mapRunNotification} from '../src/run-notification.ts';
const binding = {
  ownerId: 'owner',
  target: {projectId: 'project', sessionId: 'session', runId: 'run'},
  generationId: 'g1',
  threadId: 'thread',
  turnId: 'turn',
};
const item = {type: 'agentMessage', id: 'one', text: 'hello'};
function completed(changes = {}, itemChanges = {}) {
  return {
    method: 'item/completed',
    params: {
      threadId: 'thread',
      turnId: 'turn',
      completedAtMs: 77,
      item: {...item, ...itemChanges},
      ...changes,
    },
  };
}
function map(frame) {
  return mapRunNotification(binding, 'g1', frame);
}
it('maps a finished assistant item to its original private destination and provider identity', () => {
  const write = {
    kind: 'private-assistant-text',
    binding,
    itemId: 'one',
    text: 'hello',
  };
  expect(map(completed())).toEqual(write);
  expect(map(completed({}, {id: 'two'}))).toEqual({...write, itemId: 'two'});
  expect(map(completed())).toEqual(write);
  for (const field of ['turnId', 'threadId'])
    expect(map(completed({[field]: 'foreign'}))).toEqual({kind: 'ignored'});
  expect(mapRunNotification(binding, 'g2', completed())).toEqual({
    kind: 'ignored',
  });
  for (const type of [
    'commandExecution',
    'userMessage',
    'reasoning',
    'fileChange',
  ])
    expect(map(completed({}, {type}))).toEqual({kind: 'ignored'});
});
it('withholds questions, restricted content and oversized items without copying their private text', () => {
  for (const fields of [
    {questions: [{question: 'fixture'}]},
    {delivery: 'async'},
    {moderation: {moderated: true}},
    {moderation: {moderated: false, display: {mode: 'hide'}}},
    {moderation: 'unknown'},
  ]) {
    expect(map(completed({}, fields))).toEqual({
      kind: 'private-item-withheld',
      binding,
      itemId: 'one',
    });
  }
  expect(map(completed({}, {text: '💡'.repeat(2 * 1024 * 1024 + 1)}))).toEqual({
    kind: 'private-item-too-large',
    binding,
    itemId: 'one',
  });
});
it('maps confirmed turn status and keeps interruption separate from verified process cleanup', () => {
  function event(method, status, id = 'turn') {
    return {
      method,
      params: {
        threadId: 'thread',
        turn: {id, status, error: {message: 'private diagnostic'}},
      },
    };
  }
  expect(map(event('turn/started', 'inProgress'))).toEqual({
    kind: 'run-state',
    binding,
    observation: {state: 'running'},
  });
  expect(map(event('turn/completed', 'failed'))).toEqual({
    kind: 'run-state',
    binding,
    observation: {state: 'failed', reason: 'execution_failed'},
  });
  expect(map(event('turn/completed', 'completed'))).toEqual({
    kind: 'run-state',
    binding,
    observation: {state: 'completed'},
  });
  expect(map(event('turn/completed', 'interrupted'))).toEqual({
    kind: 'provider-interrupted',
    binding,
  });
  expect(map(event('turn/completed', 'inProgress'))).toEqual({
    kind: 'malformed',
  });
  expect(map(event('turn/completed', 'completed', 'old'))).toEqual({
    kind: 'ignored',
  });
  expect(map({...completed(), id: 1})).toEqual({kind: 'malformed'});
});
