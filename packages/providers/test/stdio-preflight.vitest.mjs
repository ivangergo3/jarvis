import {PassThrough} from 'node:stream';
import {expect, it} from 'vitest';
import {inspectCodexStdio} from '../src/stdio-preflight.ts';

const pin = {version: 'codex-cli 1.0.1', sha256: 'd'.repeat(64)};
const privateProfile = '/fixture/profile';
const hello = {
  userAgent: 'fixture',
  codexHome: privateProfile,
  platformFamily: 'unix',
  platformOs: 'macos',
};
const signedOut = {authToken: null, authMethod: null, requiresOpenaiAuth: true};
function exchange(handler) {
  const stdout = new PassThrough();
  const frames = [];
  return {
    observedBinary: pin,
    privateProfile,
    stdout,
    frames,
    async handOff(bytes, signal) {
      expect(signal.aborted).toBe(false);
      const frame = JSON.parse(Buffer.from(bytes).toString());
      frames.push(frame);
      await handler(frame, stdout);
    },
  };
}
const inspect = (exchange, parent = new AbortController(), approved = pin) =>
  inspectCodexStdio(exchange, approved, 'https://chatgpt.com', parent.signal);
it('uses only the pinned non-model handshake and correlates fragmented private RPC replies', async () => {
  const stream = exchange((frame, output) => {
    if (frame.method === 'initialized') return;
    const answer = Buffer.from(
      JSON.stringify({
        id: frame.id,
        result: frame.method === 'initialize' ? hello : signedOut,
      }) + '\n',
    );
    output.write(Buffer.from('{"method":"fixture/progress","params":{}}\n'));
    output.write(answer.subarray(0, 5));
    output.write(answer.subarray(5));
  });
  expect(await inspect(stream)).toEqual({kind: 'signed-out'});
  expect(stream.frames.map((f) => f.method)).toEqual([
    'initialize',
    'initialized',
    'getAuthStatus',
  ]);
  expect(stream.frames[2].params).toEqual({
    includeToken: false,
    refreshToken: false,
  });
  expect(stream.stdout.listenerCount('data')).toBe(0);
});
it('oversize, malformed or wrong-ID frames, private errors and partial trailing frames fail closed', async () => {
  for (const when of ['initialize', 'getAuthStatus']) {
    const stream = exchange((frame, output) => {
      if (frame.method === 'initialized') return;
      const result = frame.method === 'initialize' ? hello : signedOut;
      output.write(JSON.stringify({id: frame.id, result}) + '\n');
      if (frame.method === when)
        output.destroy(new Error('private pipe error'));
    });
    expect(await inspect(stream)).toEqual({kind: 'unavailable'});
    expect(stream.frames.at(-1).method).toBe(when);
  }
  for (const send of [
    (id, output) => output.write(Buffer.alloc(65537, 120)),
    (id, output) => output.write(Buffer.from([255, 10])),
    (id, output) =>
      output.write(JSON.stringify({id: id + 1, result: hello}) + '\n'),
    (id, output) =>
      output.write(JSON.stringify({id, error: {message: 'secret'}}) + '\n'),
    (id, output) => output.write('null\n'),
    (id, output) =>
      output.write(JSON.stringify({id, result: hello}) + '\n' + '{"id":'),
    (id, output) => output.end(),
  ]) {
    const stream = exchange(({id}, output) => send(id, output));
    expect(await inspect(stream)).toEqual({kind: 'unavailable'});
    expect(stream.stdout.listenerCount('data')).toBe(0);
  }
});
it('a rejected binary, revoked handoff and revocation during a stalled reply issue no later request', async () => {
  const no = exchange(() => {});
  expect(
    await inspect(no, new AbortController(), {...pin, sha256: 'c'.repeat(64)}),
  ).toEqual({kind: 'unsupported-build'});
  expect(no.frames).toHaveLength(0);
  for (const stallWriter of [true, false]) {
    const stop = new AbortController();
    const touched = Promise.withResolvers();
    const stream = exchange(async () => {
      touched.resolve();
      if (stallWriter) await new Promise(() => {});
    });
    const result = inspect(stream, stop);
    await touched.promise;
    stop.abort();
    expect(await result).toEqual({kind: 'cancelled'});
    expect(stream.frames).toHaveLength(1);
    expect(stream.stdout.listenerCount('data')).toBe(0);
    const closed = new Promise((resolve) =>
      stream.stdout.once('close', resolve),
    );
    stream.stdout.destroy(new Error('private delayed retirement'));
    await closed;
  }
});
