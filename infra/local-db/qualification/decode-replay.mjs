import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {decodeEvent, readEventBatch} from '@jarvis/contracts';

const rows = readFileSync(process.argv[2], 'utf8').trim().split('\n');
assert.ok(rows[0], 'The database fixture returned no replay rows');
const streams = new Map();
const kinds = new Set();
for (const row of rows) {
  const decoded = decodeEvent(row);
  assert.equal(
    decoded.status,
    'ok',
    'An emitted database event cannot be decoded',
  );
  const event = decoded.event;
  const stream = streams.get(event.ownerId) ?? [];
  stream.push(event);
  streams.set(event.ownerId, stream);
  kinds.add(event.kind);
}
for (const [ownerId, events] of streams) {
  const after = '0';
  const result = readEventBatch(
    JSON.stringify({schemaVersion: 1, ownerId, after, events}),
    {ownerId, after, hasApplied: () => false},
  );
  assert.equal(
    result.status,
    'ok',
    'The database stream cannot advance its owner cursor',
  );
}
for (const kind of [
  'command.recorded',
  'run.output',
  'run.state',
  'session.binding',
  'project.created',
  'session.created',
])
  assert.ok(kinds.has(kind), kind);
