import assert from 'node:assert/strict';
import {test} from 'vitest';
import {qualifyCodexRecovery} from '../src/index.js';
import {readPinnedCliSchemas} from './pinned-cli-schema.mjs';
test('the pinned offline CLI schema qualifies real responses and rejects incomplete recovery evidence', async () => {
  const [metadataSchema, turnsSchema, itemsSchema] = await readPinnedCliSchemas(
    [
      'ThreadReadResponse',
      'ThreadTurnsListResponse',
      'ThreadItemsListResponse',
    ],
  );
  const lookup = qualifyCodexRecovery({
    'thread/read': metadataSchema,
    'thread/turns/list': turnsSchema,
    'thread/items/list': itemsSchema,
  });
  assert.ok(
    lookup,
    'The installed response schemas must match the approved build.',
  );
  const clientId = 'c57d44c9-667c-405f-91b9-a4f54fd101a3';
  const thread = {
    id: 'fixture-thread',
    sessionId: 'fixture-session',
    projectId: null,
    cliVersion: '0.171.0-alpha.13',
    createdAt: 0,
    updatedAt: 0,
    cwd: '/fixture',
    ephemeral: true,
    modelProvider: 'fixture',
    preview: '',
    source: 'cli',
    status: {type: 'idle'},
    turns: [],
  };
  const turn = {
    id: 'fixture-turn',
    items: [],
    status: 'completed',
    itemsView: 'notLoaded',
  };
  const user = {
    id: 'user',
    type: 'userMessage',
    content: [{type: 'text', text: 'fixture'}],
    clientId,
  };
  const assistant = {id: 'assistant', type: 'agentMessage', text: 'fixture'};
  function recover(metadata, items, turnSummary = turn) {
    const pages = [
      {thread: metadata},
      {data: [turnSummary]},
      {data: items.map((item) => ({turnId: turn.id, item}))},
    ];
    return lookup(
      {signal: new AbortController().signal, read: async () => pages.shift()},
      thread.id,
      clientId,
    );
  }
  assert.deepEqual(await recover(thread, [user, assistant]), {
    kind: 'observed-turn',
    threadId: thread.id,
    turnId: turn.id,
  });
  for (const field of Object.keys(thread)) {
    const incomplete = {...thread};
    delete incomplete[field];
    assert.deepEqual(
      await recover(incomplete, [user]),
      {kind: 'unknown'},
      'Missing ' + field,
    );
  }
  assert.deepEqual(
    await recover(thread, [user, {id: 'assistant', type: 'agentMessage'}]),
    {kind: 'unknown'},
  );

  const {itemsView, ...omittedView} = turn;
  assert.equal(itemsView, 'notLoaded');
  assert.deepEqual(await recover(thread, [user], omittedView), {
    kind: 'unknown',
  });
}, 20_000);
