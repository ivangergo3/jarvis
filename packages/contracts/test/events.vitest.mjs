import {expect, test, vi} from 'vitest';
import {
  Cursor,
  decodeEvent as decodeWireEvent,
  Event,
  EventBatch,
  readEventBatch as readBoundBatch,
} from '../src/index.ts';

const id = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const decodeEvent = (value) => decodeWireEvent(JSON.stringify(value));
const readWireBatch = (wire, stream) =>
  readBoundBatch(wire, {hasApplied: () => false, ...stream});
const readEventBatch = (value, stream) =>
  readWireBatch(JSON.stringify(value), stream);
const envelope = {
  schemaVersion: 1,
  ownerId: id(1),
  eventId: id(2),
  occurredAt: '2026-10-01T12:00:00.000Z',
  sequence: '9007199254740993',
};
const project = {projectId: id(3)};
const session = {...project, sessionId: id(4)};
const run = {...session, runId: id(5)};
const request = {...run, requestId: id(6), generationId: id(7), revision: '1'};
const payload = {
  kind: 'approval',
  status: 'unavailable',
  reason: 'channel_lost',
};
const event = {...envelope, kind: 'request.status', target: request, payload};

test('a project event has a project target; requests retain their originating run even when selection changes', () => {
  const created = {
    ...envelope,
    kind: 'project.created',
    target: project,
    payload: {commandId: id(9), title: 'Jarvis'},
  };
  expect(Event.parse(created)).toEqual(created);
  expect(Event.safeParse({...created, target: run}).success).toBe(false);
  const originalTarget = {...request};
  const selected = {...event, target: originalTarget};
  const decoded = Event.parse(selected);
  originalTarget.sessionId = id(10);
  expect(decoded.target).toEqual(request);
  expect(Event.safeParse({...event, target: session}).success).toBe(false);
});

test('unknown protocol messages stop replay without constructing an actionable event', () => {
  expect(decodeEvent(event)).toEqual({status: 'ok', event});
  expect(decodeEvent({...event, kind: 'future'})).toEqual({
    status: 'unsupported_event',
  });
  expect(decodeEvent({...event, schemaVersion: 2})).toEqual({
    status: 'unsupported_version',
  });
  expect(decodeEvent({...event, schemaVersion: 2, target: undefined})).toEqual({
    status: 'malformed',
  });
  expect(decodeEvent({...event, schemaVersion: 2, target: project})).toEqual({
    status: 'malformed',
  });
  const future = {...event, kind: 'future'};
  const stream = {
    ownerId: event.ownerId,
    after: String(BigInt(event.sequence) - 1n),
  };
  const batch = {schemaVersion: 1, ...stream};
  for (const invalid of [
    {...future, target: undefined},
    {...future, target: {runId: id(5)}},
    {...future, payload: undefined},
    {...future, payload: {toJSON: () => 'string'}},
    {...future, payload: {toJSON: () => undefined}},
    {...future, payload: {value: 'é'.repeat(33_000)}},
  ]) {
    expect(decodeEvent(invalid)).toEqual({status: 'malformed'});
    expect(readEventBatch({...batch, events: [invalid]}, stream)).toEqual({
      status: 'malformed',
    });
  }
  const events = Array.from({length: 20}, (_, index) => ({
    ...future,
    eventId: id(index + 100),
    sequence: String(BigInt(future.sequence) + BigInt(index)),
    payload: {value: 'x'.repeat(60_000)},
  }));
  expect(readEventBatch({...batch, events}, stream)).toEqual({
    status: 'malformed',
  });
  const encodeFuture = (opaque) =>
    JSON.stringify({...future, payload: 'OPAQUE'}).replace('"OPAQUE"', opaque);
  const encodeBatch = (frame) =>
    JSON.stringify({...batch, events: ['FRAME']}).replace('"FRAME"', frame);
  const deep = encodeFuture(
    '{"nested":' + '['.repeat(12_000) + '0' + ']'.repeat(12_000) + '}',
  );
  expect(decodeWireEvent(deep)).toEqual({status: 'unsupported_event'});
  expect(readWireBatch(encodeBatch(deep), stream)).toEqual({
    status: 'unsupported_event',
  });
  const escaped = encodeFuture('{"x":"' + '\\u0061'.repeat(11_000) + '"}');
  expect(decodeWireEvent(escaped)).toEqual({status: 'malformed'});
  expect(readWireBatch(encodeBatch(escaped), stream)).toEqual({
    status: 'malformed',
  });
  const oversizedBatch = encodeBatch(escaped);
  const parse = vi.spyOn(JSON, 'parse');
  try {
    for (const wire of [
      oversizedBatch,
      oversizedBatch.slice(0, -2),
      encodeBatch(JSON.stringify(future) + '\u00a0'.repeat(33_000)),
    ]) {
      expect(readWireBatch(wire, stream)).toEqual({status: 'malformed'});
      expect(parse).not.toHaveBeenCalledWith(wire);
    }
  } finally {
    parse.mockRestore();
  }
  const separator = ' \t\r\n'.repeat(17_000);
  expect(readWireBatch(encodeBatch(separator), stream)).toEqual({
    status: 'ok',
    batch: {...batch, events: []},
  });
  expect(
    readWireBatch(
      encodeBatch(separator + JSON.stringify(future) + separator),
      stream,
    ),
  ).toEqual({
    status: 'unsupported_event',
  });
  const runFrame = {
    ...event,
    kind: 'run.state',
    target: run,
    payload: {revision: '1', observation: {}},
  };
  const futureFrames = [
    encodeBatch(JSON.stringify({...runFrame, schemaVersion: 2})),
    JSON.stringify({...batch, schemaVersion: 2, events: [runFrame]}),
  ];
  const nativeParse = JSON.parse;
  const readObservation = vi.fn(() => {
    throw new Error('Future observation decoded');
  });
  const parseOpaque = vi.spyOn(JSON, 'parse').mockImplementation((text) => {
    const value = nativeParse(text);
    if (futureFrames.includes(text)) {
      Object.defineProperty(value.events[0].payload, 'observation', {
        get: readObservation,
      });
    }
    return value;
  });
  try {
    for (const wire of futureFrames) {
      expect(readWireBatch(wire, stream)).toEqual({
        status: 'unsupported_version',
      });
      expect(parseOpaque).toHaveBeenCalledWith(wire);
    }
    expect(readObservation).not.toHaveBeenCalled();
  } finally {
    parseOpaque.mockRestore();
  }
  const quoted = encodeFuture(
    JSON.stringify({text: 'braces [{}] and escaped " and ,'}),
  );
  expect(
    readWireBatch(
      encodeBatch(quoted).replace('"events"', '"ev\\u0065nts"'),
      stream,
    ),
  ).toEqual({
    status: 'unsupported_event',
  });
  expect(decodeWireEvent('{invalid')).toEqual({status: 'malformed'});
  const ambiguous = JSON.stringify(event).replace(
    '"kind":',
    '"k\\u0069nd":"future","kind":',
  );
  expect(decodeWireEvent(ambiguous)).toEqual({status: 'malformed'});
  expect(readWireBatch(encodeBatch(ambiguous), stream)).toEqual({
    status: 'malformed',
  });
  expect(
    decodeWireEvent(encodeFuture('{"allowed":false,"allowed":true}')),
  ).toEqual({status: 'malformed'});
  const duplicateArray = encodeBatch(quoted).replace(
    '"events":',
    '"events":[],"events":',
  );
  expect(readWireBatch(duplicateArray, stream)).toEqual({status: 'malformed'});
  const empty = encodeFuture('{"text":""}');
  const exact = encodeFuture(
    JSON.stringify({text: 'a'.repeat(65536 - empty.length)}),
  );
  expect(readWireBatch(encodeBatch(exact), stream)).toEqual({
    status: 'unsupported_event',
  });
  expect(
    readWireBatch(encodeBatch(exact.replace('aaa', 'aaaa')), stream),
  ).toEqual({status: 'malformed'});
  for (const invalid of [
    null,
    {...event, ownerId: undefined},
    {...event, sequence: 42},
    {...event, sequence: '0'},
    {...event, occurredAt: 'yesterday'},
    {...event, payload: {...payload, prompt: 'private'}},
  ]) {
    expect(decodeEvent(invalid)).toEqual({status: 'malformed'});
  }
  expect(Cursor.parse('9223372036854775807')).toBe('9223372036854775807');
  for (const invalid of ['9223372036854775808', '00', '-1', ' 1', 7, null])
    expect(Cursor.safeParse(invalid).success).toBe(false);
});

test('a replay batch rejects reordered, duplicated and foreign-owner events above the safe integer range', () => {
  const after = String(BigInt(event.sequence) - 1n);
  const next = {
    ...event,
    eventId: id(11),
    sequence: String(BigInt(event.sequence) + 1n),
  };
  const batch = {
    schemaVersion: 1,
    ownerId: envelope.ownerId,
    after,
    events: [event, next],
  };
  expect(EventBatch.parse(batch)).toEqual(batch);
  const stream = {ownerId: event.ownerId, after};
  const applied = new Set();
  const original = readEventBatch(
    {...batch, events: [event]},
    {...stream, hasApplied: (id) => applied.has(id)},
  );
  expect(original.status).toBe('ok');
  for (const item of original.batch.events) applied.add(item.eventId);
  const continuation = {ownerId: event.ownerId, after: event.sequence};
  for (const version of [1, 2]) {
    const replay = {
      schemaVersion: version,
      ...continuation,
      events: [{...next, eventId: event.eventId}],
    };
    expect(
      readEventBatch(replay, {
        ...continuation,
        hasApplied: (id) => applied.has(id),
      }),
    ).toEqual({status: 'malformed'});
  }
  const futureBatch = {...batch, schemaVersion: 2};
  for (const invalid of [
    {...futureBatch, ownerId: id(20)},
    {...futureBatch, after: '0'},
    {...futureBatch, events: [{...event, schemaVersion: 2, target: undefined}]},
    {
      ...futureBatch,
      events: [{...event, kind: 'future', payload: {text: 'x'.repeat(65536)}}],
    },
  ])
    expect(readEventBatch(invalid, stream)).toEqual({status: 'malformed'});
  for (const changed of [
    {...next, kind: 'future', ownerId: id(20)},
    {...next, kind: 'future', eventId: event.eventId},
    {...next, schemaVersion: 2, sequence: event.sequence},
  ])
    expect(
      readEventBatch({...batch, events: [event, changed]}, stream),
    ).toEqual({status: 'malformed'});
  for (const incompatible of [
    {...batch, schemaVersion: 2},
    {...batch, events: [event, {...next, schemaVersion: 2}]},
  ])
    expect(readEventBatch(incompatible, stream)).toEqual({
      status: 'unsupported_version',
    });
  expect(
    readEventBatch(
      {...batch, events: [event, {...next, kind: 'new_kind'}]},
      stream,
    ),
  ).toEqual({status: 'unsupported_event'});
  expect(readEventBatch(batch, {ownerId: event.ownerId, after})).toEqual({
    status: 'ok',
    batch,
  });
  expect(readEventBatch(batch, {ownerId: id(20), after})).toEqual({
    status: 'malformed',
  });
  expect(readEventBatch(batch, {ownerId: event.ownerId, after: '0'})).toEqual({
    status: 'malformed',
  });
  for (const invalid of [
    {...batch, after: 'invalid'},
    {...batch, events: [{...event, sequence: 'invalid'}]},
  ])
    expect(EventBatch.safeParse(invalid).success).toBe(false);
  for (const events of [
    [next, event],
    [event, event],
    [event, {...next, eventId: event.eventId}],
    [event, {...next, ownerId: id(19)}],
    Array.from({length: 101}, () => event),
  ]) {
    expect(EventBatch.safeParse({...batch, events}).success).toBe(false);
    expect(readEventBatch({...batch, events}, stream)).toEqual({
      status: 'malformed',
    });
  }
});
