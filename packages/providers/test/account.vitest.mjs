import {expect, test} from 'vitest';
import {observeCodexAccount as observe} from '../src/index.ts';

const observeCodexAccount = (read, origin) =>
  observe(read, origin, new AbortController().signal);
const origin = 'https://example.invalid';
const auth = {requiresOpenaiAuth: true, authMethod: 'chatgpt', authToken: null};
const observed = {
  requiresOpenaiAuth: true,
  account: {type: 'chatgpt', email: 'unused@example.invalid'},
  userId: 'synthetic-user',
  workspaceRouting: {
    chatgptAccountId: 'synthetic-space',
    backendOrigin: origin,
  },
};

function worker(...replies) {
  const requests = [];
  return {
    requests,
    read: async (request) => {
      requests.push(request);
      if (!replies.length) throw Error('Unexpected method');
      return replies.shift();
    },
  };
}

test('reads ChatGPT identity and workspace from the same account response without requesting credentials', async () => {
  const fixture = worker(auth, observed);
  await expect(observeCodexAccount(fixture.read, origin)).resolves.toEqual({
    kind: 'observed-chatgpt-workspace',
    userId: 'synthetic-user',
    workspaceId: 'synthetic-space',
    backendOrigin: origin,
  });
  expect(fixture.requests).toEqual([
    {
      method: 'getAuthStatus',
      params: {includeToken: false, refreshToken: false},
    },
    {method: 'account/read', params: {refreshToken: false}},
  ]);
});

test('stops before account reads for signed-out, alternative or malformed login observations', async () => {
  for (const [response, kind] of [
    [{...auth, authMethod: null}, 'signed-out'],
    [{...auth, authMethod: ''}, 'unavailable'],
    [{...auth, authMethod: '  '}, 'unavailable'],
    [{...auth, authMethod: 'apikey'}, 'other-auth-method'],
    [{...auth, authMethod: 'future'}, 'other-auth-method'],
    [{...auth, authToken: 'fixture-only'}, 'unavailable'],
    [{...auth, requiresOpenaiAuth: false}, 'unavailable'],
    [{}, 'unavailable'],
  ]) {
    const fixture = worker(response);
    expect(await observeCodexAccount(fixture.read, origin)).toEqual({kind});
    expect(fixture.requests).toHaveLength(1);
  }
});

test('reports missing or mismatched routing and transport errors without exposing worker output', async () => {
  for (const response of [
    {...observed, account: null},
    {...observed, userId: null},
    {...observed, account: {type: 'apiKey'}},
    {...observed, workspaceRouting: null},
    {
      ...observed,
      workspaceRouting: {
        ...observed.workspaceRouting,
        backendOrigin: 'https://elsewhere.invalid',
      },
    },
  ]) {
    const fixture = worker(auth, response);
    expect(await observeCodexAccount(fixture.read, origin)).toEqual({
      kind: 'unavailable',
    });
    expect(fixture.requests).toHaveLength(2);
  }
  expect(
    await observeCodexAccount(async () => {
      throw Error('sensitive provider output');
    }, origin),
  ).toEqual({kind: 'unavailable'});
  for (const invalid of [
    'http://example.invalid',
    'https://u:p@example.invalid',
    'https://example.invalid/other',
    '',
  ]) {
    const unused = worker();
    expect(await observeCodexAccount(unused.read, invalid)).toEqual({
      kind: 'unavailable',
    });
    expect(unused.requests).toHaveLength(0);
  }
});

test('cancellation stops account reads and never publishes a late identity', async () => {
  const controller = new AbortController();
  const read = async (request, signal) => {
    expect(signal).toBe(controller.signal);
    if (request.method === 'getAuthStatus') return auth;
    controller.abort();
    return observed;
  };
  expect(await observe(read, origin, controller.signal)).toEqual({
    kind: 'cancelled',
  });
  const skipped = worker();
  expect(await observe(skipped.read, origin, controller.signal)).toEqual({
    kind: 'cancelled',
  });
  expect(skipped.requests).toHaveLength(0);

  const first = new AbortController();
  let requests = 0;
  expect(
    await observe(
      async () => {
        requests++;
        first.abort();
        return auth;
      },
      origin,
      first.signal,
    ),
  ).toEqual({kind: 'cancelled'});
  expect(requests).toBe(1);
  expect(
    await observeCodexAccount(async () => {
      throw new DOMException('sensitive', 'AbortError');
    }, origin),
  ).toEqual({kind: 'cancelled'});
});
