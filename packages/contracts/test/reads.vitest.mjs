import {expect, test} from 'vitest';
import {
  CloseAdmissionEpoch,
  ClosedEpochPage,
  ContentChunk,
  Event,
  HistoryContent,
  ProjectPage,
  ReadRequest,
  SessionPage,
} from '../src/index.ts';

const id = (n) => '00000000-0000-4000-8000-' + String(n).padStart(12, '0');
const session = {projectId: id(1), sessionId: id(2)};
const request = {
  ...session,
  runId: id(3),
  requestId: id(4),
  generationId: id(5),
  revision: '1',
  authSessionId: id(6),
  channelId: id(7),
};
const part = {contentId: id(8), offset: 0};
const header = {schemaVersion: 1};

test('bind the initial snapshot and each continuation to the same requested identity', () => {
  const initial = {
    ...header,
    operation: 'snapshot.read',
    snapshotId: id(30),
    continuation: null,
  };
  expect(ReadRequest.parse(initial)).toEqual(initial);
  const resumed = {
    ...initial,
    continuation: {highWater: '5', offset: '3', pageToken: 'page-2'},
  };
  expect(ReadRequest.parse(resumed)).toEqual(resumed);
  expect(
    ReadRequest.safeParse({
      ...resumed,
      continuation: {...resumed.continuation, highWater: '0'},
    }).success,
  ).toBe(false);
  expect(
    ReadRequest.safeParse({...initial, snapshotId: undefined}).success,
  ).toBe(false);
  expect(
    ReadRequest.safeParse({
      ...resumed,
      continuation: {...resumed.continuation, offset: '0'},
    }).success,
  ).toBe(false);
});

test('history updates reference authorized retained content and command observations never contain private bodies', () => {
  const envelope = {
    ...header,
    ownerId: id(20),
    eventId: id(21),
    sequence: '3',
    occurredAt: '2026-10-01T12:00:00.000Z',
  };
  const output = {
    ...envelope,
    kind: 'run.output',
    target: {...session, runId: id(3)},
    payload: {
      entryId: id(22),
      entryRevision: '1',
      content: {kind: 'removed', contentId: id(8)},
    },
  };
  const acknowledgement = {
    ...envelope,
    kind: 'command.recorded',
    target: {commandId: id(23)},
    payload: {status: 'accepted'},
  };
  expect(Event.parse(output)).toEqual(output);
  expect(Event.parse(acknowledgement)).toEqual(acknowledgement);
  expect(
    Event.safeParse({...output, payload: {text: 'private prompt'}}).success,
  ).toBe(false);
});

test('request-content reads bind every component to the original live channel while history reads use an entry revision', () => {
  const live = {...header, operation: 'request.content', target: request, part};
  const history = {
    ...header,
    operation: 'history.content',
    target: {...session, entryId: id(9), entryRevision: '1'},
    part,
  };
  for (const read of [live, history])
    expect(ReadRequest.parse(read)).toEqual(read);
  for (const invalid of [
    {...live, target: history.target},
    {...history, target: request},
    {...live, target: {...request, channelId: undefined}},
    {...live, part: {...part, offset: -1}},
  ])
    expect(ReadRequest.safeParse(invalid).success).toBe(false);
  const range = {
    ...header,
    ...part,
    sha256: 'e'.repeat(64),
    totalBytes: 65537,
    bytes: 65536,
  };
  expect(ContentChunk.parse(range)).toEqual(range);
  const empty = {
    ...range,
    totalBytes: 0,
    bytes: 0,
    sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
  };
  expect(ContentChunk.parse(empty)).toEqual(empty);
  for (const invalid of [
    {...empty, sha256: range.sha256},
    {...range, bytes: 0},
    {...range, bytes: 65537},
    {...range, offset: 2},
  ])
    expect(ContentChunk.safeParse(invalid).success).toBe(false);
  expect(
    HistoryContent.safeParse({kind: 'removed', contentId: id(10)}).success,
  ).toBe(true);
  expect(
    HistoryContent.safeParse({kind: 'retained_text', text: 'private decision'})
      .success,
  ).toBe(false);
});

test('controller recovery fences one epoch and reads bounded receipt ledgers', () => {
  const closed = {
    ...header,
    originatingSessionId: id(9),
    operation: 'controller.close_epoch',
    commandId: id(11),
    expectedEpoch: id(12),
  };
  expect(CloseAdmissionEpoch.parse(closed)).toEqual(closed);
  expect(
    CloseAdmissionEpoch.safeParse({...closed, originatingSessionId: undefined})
      .success,
  ).toBe(false);
  expect(
    CloseAdmissionEpoch.safeParse({...closed, expectedEpoch: undefined})
      .success,
  ).toBe(false);
  const page = {
    ...header,
    ownerId: id(13),
    through: 'fixed-inventory',
    after: null,
    ledgers: [{epoch: id(12), highWater: '4'}],
    next: null,
  };
  expect(ClosedEpochPage.parse(page)).toEqual(page);
  expect(
    ClosedEpochPage.safeParse({
      ...page,
      ledgers: [...page.ledgers, {...page.ledgers[0], highWater: '3'}],
    }).success,
  ).toBe(false);
  expect(
    ClosedEpochPage.safeParse({
      ...page,
      ledgers: Array.from({length: 101}, () => page.ledgers[0]),
    }).success,
  ).toBe(false);
  const ledger = {
    ...header,
    operation: 'controller.receipts',
    epoch: id(12),
    page: {highWater: '4', after: null, limit: 100},
  };
  expect(ReadRequest.parse(ledger)).toEqual(ledger);
  expect(
    ReadRequest.safeParse({...ledger, page: {...ledger.page, limit: 101}})
      .success,
  ).toBe(false);
});

test('project and session listings bind bounded selection records to their owner and destination', () => {
  const target = {projectId: id(31)};
  const row = {kind: 'project', target, title: 'Project'};
  const base = {schemaVersion: 1, ownerId: id(20), after: null, next: null};
  const page = {...base, records: [row]};
  expect(ProjectPage.parse(page)).toEqual(page);
  for (const invalid of [
    {...page, records: [row, row]},
    {...page, records: [], next: 'bad'},
    {...page, after: 'loop', next: 'loop'},
  ]) {
    expect(ProjectPage.safeParse(invalid).success).toBe(false);
  }
  const chat = {
    kind: 'session',
    target: {...target, sessionId: id(32)},
    title: 'Chat',
    binding: 'unbound',
  };
  const sessions = {...base, target, records: [chat]};
  expect(SessionPage.parse(sessions)).toEqual(sessions);
  expect(
    SessionPage.safeParse({...sessions, target: {projectId: id(33)}}).success,
  ).toBe(false);
  expect(
    SessionPage.safeParse({
      ...sessions,
      records: Array.from({length: 101}, () => chat),
    }).success,
  ).toBe(false);
});
