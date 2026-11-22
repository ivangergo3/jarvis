import {expect, it} from 'vitest';
import {probeCodexWorker} from '../src/index.ts';
const pin = {version: 'codex-cli 0.169.0-alpha.11.1', sha256: 'a'.repeat(64)};
const profile = '/synthetic/private';
const origin = 'https://example.invalid';
const hello = {
  platformFamily: 'unix',
  platformOs: 'macos',
  userAgent: 'sample',
  codexHome: profile,
};
function fixture(reply = hello) {
  const calls = [];
  return {
    calls,
    observedBinary: {...pin},
    privateProfile: profile,
    async request(message, signal) {
      calls.push(message);
      if (signal.aborted) throw new Error('Cancelled');
      if (message.method === 'initialize') return reply;
      return {authToken: null, authMethod: null, requiresOpenaiAuth: true};
    },
    async notify(message) {
      calls.push(message);
    },
  };
}
it('pins the measured binary before a read-only handshake on the same worker', async () => {
  for (const observedBinary of [
    {...pin, version: 'codex-cli 0.170.0'},
    {...pin, sha256: 'b'.repeat(64)},
  ]) {
    const worker = Object.assign(fixture(), {observedBinary});
    await expect(
      probeCodexWorker(worker, pin, origin, new AbortController().signal),
    ).resolves.toEqual({kind: 'unsupported-build'});
    expect(worker.calls).toHaveLength(0);
  }
  const worker = fixture();
  expect(
    await probeCodexWorker(worker, pin, origin, new AbortController().signal),
  ).toEqual({kind: 'signed-out'});
  expect(worker.calls.map((call) => call.method)).toEqual([
    'initialize',
    'initialized',
    'getAuthStatus',
  ]);
  expect(worker.calls[0].params.capabilities.experimentalApi).toBe(true);
  expect(worker.calls[2].params).toEqual({
    includeToken: false,
    refreshToken: false,
  });
});
it('stops before reading account data after a profile or platform mismatch or interrupted handshake', async () => {
  for (const reply of [
    {...hello, codexHome: '/different'},
    {...hello, platformOs: 'linux'},
    {...hello, platformFamily: 'other'},
    {...hello, userAgent: ''},
    {},
  ]) {
    const worker = fixture(reply);
    expect(
      await probeCodexWorker(worker, pin, origin, new AbortController().signal),
    ).toEqual({kind: 'incompatible-handshake'});
    expect(worker.calls.map((call) => call.method)).toEqual(['initialize']);
  }
  const worker = fixture();
  const abort = new AbortController();
  worker.notify = async (message) => {
    worker.calls.push(message);
    abort.abort();
  };
  expect(await probeCodexWorker(worker, pin, origin, abort.signal)).toEqual({
    kind: 'cancelled',
  });
  expect(worker.calls.map((call) => call.method)).toEqual([
    'initialize',
    'initialized',
  ]);
});
