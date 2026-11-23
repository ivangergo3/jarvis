import {expect, it, vi} from 'vitest';
import {acceptTurnReceipt, mapRunNotification} from '../src/index.ts';

const target = {projectId: 'project-A', sessionId: 'session-A', runId: 'run-A'};
const source = {channelId: 'channel-A', generationId: 'worker-A'};
const intent = {
  ...source,
  rpcId: 'start-1',
  clientUserMessageId: 'f785ebe6-11e9-41b4-83fe-59da66bfb99e',
  ownerId: 'owner-A',
  target,
  threadId: 'thread-A',
};
const response = {
  id: 'start-1',
  result: {turn: {id: 'turn-A', status: 'inProgress', items: []}},
};
const signal = () => new AbortController().signal;
it('binds the original turn before the existing notification mapper can expose its output', async () => {
  const persisted = Promise.withResolvers();
  const started = Promise.withResolvers();
  const stop = signal();
  let delivered = false;
  const confirm = vi.fn(() => {
    started.resolve();
    return persisted.promise;
  });
  const mutable = {...intent, target: {...target}};
  const result = acceptTurnReceipt(
    mutable,
    source,
    response,
    stop,
    confirm,
  ).then((reply) => {
    delivered = true;
    return reply;
  });
  await started.promise;
  expect(delivered).toBe(false);
  expect(confirm).toHaveBeenCalledWith(intent, 'turn-A', stop);
  mutable.target.runId = 'run-B';
  mutable.threadId = 'thread-B';
  mutable.ownerId = 'owner-B';
  persisted.resolve(true);
  const {kind, binding} = await result;
  expect(kind).toBe('bound');
  const completed = (threadId, turnId) => ({
    method: 'turn/completed',
    params: {threadId, turn: {id: turnId, status: 'completed'}},
  });
  expect(
    mapRunNotification(
      binding,
      source.generationId,
      completed('thread-A', 'turn-A'),
    ),
  ).toMatchObject({
    kind: 'run-state',
    observation: {state: 'completed'},
    binding: {target, ownerId: intent.ownerId},
  });
  expect(
    mapRunNotification(
      binding,
      source.generationId,
      completed('thread-B', 'turn-A'),
    ),
  ).toEqual({kind: 'ignored'});
});
it('foreign channels, numeric or replayed RPC identities and malformed matching replies cannot bind a run', async () => {
  const confirm = vi.fn(async () => true);
  for (const changed of [
    {...source, channelId: 'B'},
    {...source, generationId: 'B'},
  ])
    expect(
      await acceptTurnReceipt(intent, changed, response, signal(), confirm),
    ).toEqual({kind: 'ignored'});
  for (const id of ['previous', 1, undefined])
    expect(
      await acceptTurnReceipt(
        intent,
        source,
        {...response, id},
        signal(),
        confirm,
      ),
    ).toEqual({kind: 'ignored'});
  for (const bad of [
    {error: {message: 'private'}},
    {...response, method: 'turn/started'},
    {result: {turn: {id: 'turn-A', status: 'unknown', items: []}}},
    {result: {turn: {id: 'turn-A', status: 'completed'}}},
  ])
    expect(
      await acceptTurnReceipt(
        intent,
        source,
        {id: intent.rpcId, ...bad},
        signal(),
        confirm,
      ),
    ).toEqual({kind: 'unknown'});
  expect(confirm).not.toHaveBeenCalled();
});
it('a conflicting binding, lost persistence response or revoked original run stays uncertain', async () => {
  for (const confirm of [
    async () => false,
    async () => {
      throw new Error('private storage details');
    },
  ])
    expect(
      await acceptTurnReceipt(intent, source, response, signal(), confirm),
    ).toEqual({kind: 'unknown'});
  const owner = new AbortController();
  const confirm = vi.fn(async () => {
    owner.abort();
    return true;
  });
  expect(
    await acceptTurnReceipt(intent, source, response, owner.signal, confirm),
  ).toEqual({kind: 'unknown'});
  expect(
    await acceptTurnReceipt(intent, source, response, owner.signal, confirm),
  ).toEqual({kind: 'unknown'});
  expect(confirm).toHaveBeenCalledTimes(1);
  expect(
    await acceptTurnReceipt(
      intent,
      source,
      {...response, id: 'other'},
      owner.signal,
      confirm,
    ),
  ).toEqual({kind: 'ignored'});
});
