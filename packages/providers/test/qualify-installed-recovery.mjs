// Run after building @jarvis/providers. Pass the v2 directory produced by
// the pinned CLI's app-server generate-json-schema command.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {join} from 'node:path';
import {qualifyCodexRecovery} from '@jarvis/providers';

const [directory] = process.argv.slice(2);
assert.ok(directory, 'Pass the directory of generated v2 schemas.');
const schema = (name) => readFile(join(directory, name + '.json'));
const lookup = qualifyCodexRecovery({
  'thread/read': await schema('ThreadReadResponse'),
  'thread/turns/list': await schema('ThreadTurnsListResponse'),
  'thread/items/list': await schema('ThreadItemsListResponse'),
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
function recover(metadata, items) {
  const pages = [
    {thread: metadata},
    {data: [turn]},
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
console.log(
  'Pinned recovery schemas accepted complete evidence and rejected every incomplete record.',
);
