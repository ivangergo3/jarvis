import {expect, test} from 'vitest';
import {
  createSnapshotReader as createWireSnapshotReader,
  SnapshotPage,
  wireBytes,
} from '../src/index.ts';

const id = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const createSnapshotReader = (owner, snapshot) => {
  const read = createWireSnapshotReader(owner, snapshot);
  return (value) => read(JSON.stringify(value));
};
const session = {projectId: id(3), sessionId: id(4)};
const request = {
  ...session,
  runId: id(5),
  requestId: id(6),
  generationId: id(7),
  revision: '1',
};
const payload = {
  kind: 'approval',
  status: 'unavailable',
  reason: 'channel_lost',
};

test('snapshots page public records at a single owner-bound high-water mark', () => {
  const first = {
    kind: 'session',
    target: session,
    title: 'Planning',
    binding: 'bound',
  };
  const second = {...first, target: {...session, sessionId: id(8)}};
  const row = {kind: 'request', target: request, metadata: payload};
  const page = {
    schemaVersion: 1,
    ownerId: id(1),
    snapshotId: id(12),
    highWater: '9007199254740993',
    offset: '0',
    totalRecords: '3',
    records: [first, second, row],
    pageToken: null,
    next: null,
  };
  expect(SnapshotPage.parse(page)).toEqual(page);
  const rawReader = createWireSnapshotReader(page.ownerId, page.snapshotId);
  const compact = JSON.stringify(page);
  const unicode = compact.replace('Planning', '测试');
  const limit = 1024 * 1024;
  const withinLimit = unicode + ' '.repeat(limit - Buffer.byteLength(unicode));
  const aboveLimit = withinLimit + ' ';
  expect(aboveLimit.length).toBeLessThan(limit);
  expect(rawReader(aboveLimit)).toEqual({
    status: 'malformed',
  });
  expect(
    rawReader(
      compact.replace('"pageToken":', '"page\\u0054oken":"old","pageToken":'),
    ),
  ).toEqual({status: 'malformed'});
  expect(rawReader(withinLimit)).toEqual({
    status: 'ok',
    page: JSON.parse(unicode),
  });
  const finished = createSnapshotReader(page.ownerId, page.snapshotId);
  expect(finished({...page, schemaVersion: 2, ownerId: id(54)})).toEqual({
    status: 'malformed',
  });
  expect(finished({...page, schemaVersion: 2})).toEqual({
    status: 'unsupported_version',
  });
  expect(finished({...page, highWater: '0'})).toEqual({status: 'malformed'});
  expect(finished(page)).toEqual({status: 'ok', page});
  expect(finished(page)).toEqual({status: 'malformed'});
  expect(createSnapshotReader(id(55), page.snapshotId)(page)).toEqual({
    status: 'malformed',
  });
  expect(createSnapshotReader(page.ownerId, id(54))(page)).toEqual({
    status: 'malformed',
  });
  const subsequentRequests = (firstId) =>
    [firstId, firstId + 1, firstId + 2].map((n) => ({
      ...row,
      target: {...request, requestId: id(n)},
    }));
  const secondPage = {
    ...page,
    offset: '3',
    records: subsequentRequests(10),
    totalRecords: '9',
    pageToken: 'page-2',
    next: 'page-3',
  };
  const read = createSnapshotReader(page.ownerId, page.snapshotId);
  const start = {...page, totalRecords: '9', next: 'page-2'};
  expect(read(start)).toEqual({status: 'ok', page: start});
  const wrongContinuation = {...secondPage, pageToken: 'unrelated-token'};
  expect(SnapshotPage.safeParse(wrongContinuation).success).toBe(true);
  expect(read(wrongContinuation)).toEqual({status: 'malformed'});
  for (const changed of [
    {...secondPage, snapshotId: id(54)},
    {...secondPage, ownerId: id(55)},
    {...secondPage, highWater: '42'},
    {...secondPage, totalRecords: '12'},
    {...secondPage, offset: '2'},
    {...secondPage, next: 'page-2'},
    {...secondPage, records: [row, ...subsequentRequests(10).slice(1)]},
  ])
    expect(read(changed)).toEqual({status: 'malformed'});
  expect(read(secondPage)).toMatchObject({status: 'ok'});
  expect(read({...start, pageToken: 'page-3'})).toEqual({status: 'malformed'});
  expect(read({...secondPage, pageToken: 'page-3'})).toEqual({
    status: 'malformed',
  });
  expect(
    read({
      ...page,
      offset: '6',
      totalRecords: '9',
      records: subsequentRequests(20),
      pageToken: 'page-3',
    }),
  ).toMatchObject({status: 'ok'});
  expect(read(start)).toEqual({status: 'malformed'});
  for (const invalid of [
    {...page, next: undefined},
    {...start, records: []},
    {...start, offset: 'broken'},
    {...start, totalRecords: 'broken'},
    {...start, totalRecords: '2'},
    {...page, records: [second, first, row]},
    {...page, records: [first, {...first, title: 'Updated title'}, row]},
    {
      ...page,
      records: [
        first,
        second,
        {...row, metadata: {...payload, answer: 'private'}},
      ],
    },
  ]) {
    expect(SnapshotPage.safeParse(invalid).success).toBe(false);
  }
  const rows = Array.from({length: 101}, (_, i) => ({
    ...row,
    target: {...request, requestId: id(i + 1)},
  }));
  const pageOf = (records) => ({
    ...page,
    records,
    totalRecords: String(records.length),
  });
  expect(SnapshotPage.safeParse(pageOf(rows.slice(0, 100))).success).toBe(true);
  expect(SnapshotPage.safeParse(pageOf(rows)).success).toBe(false);
  expect(wireBytes({text: 'a☀🦊'})).toBe(19);
  expect(
    SnapshotPage.safeParse({...page, records: [], totalRecords: '0'}).success,
  ).toBe(true);
});
