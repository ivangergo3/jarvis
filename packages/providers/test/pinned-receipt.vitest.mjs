import assert from 'node:assert/strict';
import {test} from 'vitest';
import {qualifyCodexTurnReceipt} from '../src/index.js';
import {readPinnedCliSchemas} from './pinned-cli-schema.mjs';
test('the qualified turn receipt validates every item using the real pinned offline CLI schema', async () => {
  const [schema] = await readPinnedCliSchemas(['TurnStartResponse']);
  const accept = qualifyCodexTurnReceipt(schema);
  assert.ok(accept, 'Installed CLI must match the approved reply schema');
  const source = {channelId: 'channel', generationId: 'worker'};
  const intent = {
    ...source,
    rpcId: 'request',
    clientUserMessageId: 'original',
    ownerId: 'owner',
    target: {projectId: 'project', sessionId: 'session', runId: 'run'},
    threadId: 'thread',
  };
  const signal = new AbortController().signal;
  let writes = 0;
  async function receipt(item) {
    const frame = {
      id: 'request',
      result: {turn: {id: 'turn', status: 'inProgress', items: [item]}},
    };
    return accept(intent, source, frame, signal, async () => {
      writes++;
      return true;
    });
  }
  assert.equal(
    (await receipt({type: 'agentMessage', id: 'item', text: 'example'})).kind,
    'bound',
  );
  for (const item of [
    null,
    {},
    {type: 'agentMessage', id: 'item'},
    {type: 'userMessage', id: 'item'},
  ]) {
    assert.equal((await receipt(item)).kind, 'unknown');
  }
  assert.equal(writes, 1);
}, 20_000);
