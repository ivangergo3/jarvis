import {expect, it, vi} from 'vitest';
import {qualifyNewThreadReceipt} from '../src/index.js';
import {readPinnedCliSchemas} from './pinned-cli-schema.mjs';

it('durably binds only the exact idle new thread with its frozen checkout and permissions', async () => {
  const [schema] = await readPinnedCliSchemas(['ThreadStartResponse']);
  const receive = qualifyNewThreadReceipt(schema);
  expect(receive).toBeTypeOf('function');
  expect(qualifyNewThreadReceipt(Buffer.from('{}'))).toBeUndefined();
  const cwd = '/synthetic/checkout';
  const target = {projectId: 'project', sessionId: 'session', runId: 'run'};
  const worker = {channelId: 'owned-channel', generationId: 'worker-1'};
  const source = {
    ...worker,
    confinement: {
      ...worker,
      cwd,
      mode: 'workspaceWrite',
      profile: null,
      readableRoots: [cwd],
      writableRoots: [cwd],
      networkAccess: false,
    },
  };
  const intent = {
    ...worker,
    target,
    ownerId: 'owner',
    rpcId: 'original',
    setupId: 'unique-setup',
    model: 'fixture-model',
    cwd,
    cliVersion: '0.171.0-alpha.13',
    profile: null,
    mode: 'workspaceWrite',
  };
  const valid = {
    id: 'original',
    result: {
      approvalPolicy: 'on-request',
      approvalsReviewer: 'user',
      cwd,
      model: 'fixture-model',
      modelProvider: 'openai',
      runtimeWorkspaceRoots: [cwd],
      sandbox: {
        type: 'workspaceWrite',
        writableRoots: [],
        networkAccess: false,
        excludeSlashTmp: true,
        excludeTmpdirEnvVar: true,
      },
      thread: {
        id: 'new-thread',
        cliVersion: intent.cliVersion,
        createdAt: 100,
        updatedAt: 100,
        cwd,
        ephemeral: false,
        modelProvider: 'openai',
        preview: '',
        projectId: null,
        sessionId: 'provider-session',
        source: 'appServer',
        status: {type: 'idle'},
        turns: [],
      },
    },
  };
  const live = () => new AbortController().signal;
  const persist = vi.fn(async () => true);
  expect(await receive(intent, source, valid, live(), persist)).toEqual({
    kind: 'bound',
    threadId: 'new-thread',
  });
  expect(persist.mock.calls[0].slice(0, 2)).toEqual([intent, 'new-thread']);
  for (const mutate of [
    (r) => {
      r.cwd = '/other';
    },
    (r) => {
      r.thread.cwd = '/other';
    },
    (r) => {
      r.model = 'fallback';
    },
    (r) => {
      r.modelProvider = 'other';
    },
    (r) => {
      r.thread.modelProvider = 'other';
    },
    (r) => {
      r.thread.cliVersion = 'other';
    },
    (r) => {
      r.activePermissionProfile = {id: 'unexpected'};
    },
    (r) => {
      r.runtimeWorkspaceRoots.push('/outside');
    },
    (r) => {
      r.sandbox.networkAccess = true;
    },
    (r) => {
      r.sandbox.writableRoots = ['/'];
    },
    (r) => {
      r.approvalsReviewer = 'auto_review';
    },
    (r) => {
      r.thread.ephemeral = true;
    },
    (r) => {
      r.thread.status = {type: 'notLoaded'};
    },
    (r) => {
      delete r.thread.sessionId;
    },
    (r) => {
      r.thread.turns = [{id: 'implicit', items: [], status: 'inProgress'}];
    },
    (r) => {
      r.thread.forkedFromId = 'another';
    },
  ]) {
    const testFrame = structuredClone(valid);
    mutate(testFrame.result);
    expect(await receive(intent, source, testFrame, live(), persist)).toEqual({
      kind: 'unknown',
    });
  }
  for (const [from, packet] of [
    [{...source, generationId: 'other'}, valid],
    [{...source, channelId: 'other'}, valid],
    [source, {...valid, id: 'late'}],
  ]) {
    expect(await receive(intent, from, packet, live(), persist)).toEqual({
      kind: 'ignored',
    });
  }
  expect(persist).toHaveBeenCalledTimes(1);
  expect(
    await receive(intent, source, valid, live(), async () => false),
  ).toEqual({kind: 'unknown'});
  const unobservedNetwork = {...source.confinement};
  delete unobservedNetwork.networkAccess;
  for (const confinement of [
    undefined,
    unobservedNetwork,
    {...source.confinement, networkAccess: null},
    {...source.confinement, generationId: 'previous'},
    {...source.confinement, readableRoots: ['/']},
    {...source.confinement, writableRoots: [cwd, '/tmp']},
    {...source.confinement, networkAccess: true},
  ]) {
    const before = persist.mock.calls.length;
    expect(
      await receive(intent, {...worker, confinement}, valid, live(), persist),
    ).toEqual({kind: 'unknown'});
    expect(persist).toHaveBeenCalledTimes(before);
  }
  const readOnly = {...intent, mode: 'readOnly', profile: ':read-only'};
  const ro = structuredClone(valid);
  ro.result.activePermissionProfile = {id: ':read-only'};
  ro.result.sandbox = {type: 'readOnly', networkAccess: false};
  const broad = {
    ...source.confinement,
    mode: 'readOnly',
    profile: ':read-only',
    readableRoots: ['/'],
    writableRoots: [],
  };
  expect(
    await receive(
      readOnly,
      {...worker, confinement: broad},
      ro,
      live(),
      persist,
    ),
  ).toEqual({kind: 'unknown'});
  expect(
    await receive(
      readOnly,
      {...worker, confinement: {...broad, readableRoots: [cwd]}},
      ro,
      live(),
      async () => true,
    ),
  ).toEqual({kind: 'bound', threadId: 'new-thread'});
  const stalled = new AbortController();
  const write = Promise.withResolvers();
  const pending = receive(
    intent,
    source,
    valid,
    stalled.signal,
    () => write.promise,
  );
  stalled.abort();
  expect(await pending).toEqual({kind: 'unknown'});
  write.reject(new Error('late storage failure'));
  const revoked = new AbortController();
  expect(
    await receive(intent, source, valid, revoked.signal, async (saved) => {
      intent.target.sessionId = 'switched';
      expect(saved.target.sessionId).toBe('session');
      revoked.abort();
      return true;
    }),
  ).toEqual({kind: 'unknown'});
  expect(await receive(intent, source, valid, revoked.signal, persist)).toEqual(
    {kind: 'unknown'},
  );
  expect(persist).toHaveBeenCalledTimes(1);
}, 20_000);
