import {expect, test} from 'vitest';
import {parseReadPage} from '../src/index.ts';

const id = (n) => '00000000-0000-4000-8000-' + String(n).padStart(12, '0');
const ownerId = id(1);
const target = {projectId: id(2), sessionId: id(3)};
const header = {schemaVersion: 1, ownerId};
const page = {after: null, limit: 1};

test('catalog readers bind the original owner, project, continuation and limit', () => {
  const project = {kind: 'project', target: {projectId: id(2)}, title: 'One'};
  const catalog = {...header, after: null, next: null, records: [project]};
  const projects = {schemaVersion: 1, operation: 'project.list', page};
  const sessions = {
    ...projects,
    operation: 'session.list',
    target: project.target,
  };
  const rows = {...catalog, target: project.target, records: []};
  const read = (request, value, owner = ownerId) =>
    parseReadPage(JSON.stringify(value), owner, request);
  expect(read(projects, catalog)).toEqual(catalog);
  expect(read(sessions, rows)).toEqual(rows);
  expect(read(projects, catalog, id(4))).toBeUndefined();
  expect(read(sessions, rows, id(4))).toBeUndefined();
  expect(read(sessions, {...rows, target: {projectId: id(4)}})).toBeUndefined();
  expect(read(projects, {...catalog, after: 'unexpected'})).toBeUndefined();
  expect(
    read(projects, {
      ...catalog,
      records: [project, {...project, target: {projectId: id(5)}}],
    }),
  ).toBeUndefined();
});

test('recovery pages check the original wire byte budget and requested scope', () => {
  const base = {
    ...header,
    highWater: '2',
    offset: '0',
    totalRecords: '0',
    pageToken: null,
    next: null,
  };
  const epoch = id(6);
  const fixtures = [
    [
      {
        operation: 'controller.receipts',
        epoch,
        page: {...page, highWater: '2'},
      },
      {...base, epoch, receipts: []},
      {epoch: id(8)},
    ],
    [
      {operation: 'draft.list', target, page: null},
      {...base, target, drafts: []},
      {target: {...target, sessionId: id(8)}},
    ],
    [
      {operation: 'history.read', target, page: null},
      {...base, target, entries: []},
      {target: {...target, projectId: id(8)}},
    ],
    [
      {operation: 'controller.closed_epochs', through: 'closed-1', page},
      {...header, through: 'closed-1', ledgers: [], next: null},
      {through: 'closed-2'},
    ],
  ];
  for (const [read, response, different] of fixtures) {
    const request = {schemaVersion: 1, ...read};
    const wire = JSON.stringify(response);
    expect(parseReadPage(wire, ownerId, request)).toEqual(response);
    expect(parseReadPage(wire, id(7), request)).toBeUndefined();
    expect(
      parseReadPage(wire + ' '.repeat(1024 * 1024), ownerId, request),
    ).toBeUndefined();
    expect(
      parseReadPage(wire, ownerId, {...request, ...different}),
    ).toBeUndefined();
  }
});
