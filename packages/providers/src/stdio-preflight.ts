import type {Readable} from 'node:stream';
import {setImmediate as nextTurn} from 'node:timers/promises';
import {probeCodexWorker} from './preflight.js';
import type {BinaryPin} from './preflight.js';

/** A fresh, exclusively owned qualification stream. The supervisor authorizes
 * each newline-terminated frame at the actual write, enforces its own deadline
 * and retires this worker after the probe. No command or paths are accepted. */
export interface OwnedPreflightStream {
  readonly observedBinary: BinaryPin;
  readonly privateProfile: string;
  readonly stdout: Readable;
  handOff(frame: Uint8Array, signal: AbortSignal): Promise<void>;
}

const frameLimit = 64 * 1024;
const totalLimit = 4 * frameLimit;

// A retired probe owns its stream until the supervisor disposes of the worker.
// Errors during disposal must never escape as uncaught, private OS messages.
function ignoreRetiredError() {}

/** Qualify the wire protocol without exposing a general-purpose RPC writer. */
export async function inspectCodexStdio(
  stream: OwnedPreflightStream,
  approved: BinaryPin,
  origin: string,
  parent: AbortSignal,
) {
  // A rejected pin never attaches a data reader, but the supervisor still
  // retires its exclusive stream. Cover delayed disposal in that case too.
  if (!stream.stdout.listeners('error').includes(ignoreRetiredError))
    stream.stdout.on('error', ignoreRetiredError);
  const stop = new AbortController();
  const signal = AbortSignal.any([
    parent,
    stop.signal,
    AbortSignal.timeout(10_000),
  ]);
  const deadline = performance.now() + 10_000;
  const failure = new Error('Codex qualification stream unavailable');
  const line = Buffer.alloc(frameLimit);
  const decoder = new TextDecoder('utf-8', {fatal: true});
  let length = 0;
  let total = 0;
  let count = 0;
  let attached = false;
  let pending: {id: string; deliver: (response: unknown) => void} | undefined;
  const listener = new AbortController();
  const cancelled = new Promise<void>((resolve) => {
    if (signal.aborted) resolve();
    else
      signal.addEventListener('abort', () => resolve(), {
        once: true,
        signal: listener.signal,
      });
  });

  function ensureCurrent() {
    if (
      signal.aborted ||
      performance.now() >= deadline ||
      stream.stdout.destroyed ||
      stream.stdout.readableEnded
    )
      throw failure;
  }
  function fail() {
    stop.abort();
  }
  function receive(chunk: unknown) {
    if (
      !(chunk instanceof Uint8Array) ||
      (total += chunk.length) > totalLimit
    ) {
      fail();
      return;
    }
    try {
      ensureCurrent();
      let at = 0;
      while (at < chunk.length) {
        const lf = chunk.indexOf(10, at);
        const end = lf === -1 ? chunk.length : lf;
        if (length + end - at > frameLimit) throw failure;
        line.set(chunk.subarray(at, end), length);
        length += end - at;
        if (lf === -1) return;
        if (++count > 32) throw failure;
        const message: unknown = JSON.parse(
          decoder.decode(line.subarray(0, length)),
        );
        length = 0;
        if (!message || typeof message !== 'object' || Array.isArray(message))
          throw failure;
        if (!('id' in message)) {
          if (
            !('method' in message) ||
            typeof message.method !== 'string' ||
            'result' in message ||
            'error' in message
          )
            throw failure;
        } else {
          if (
            !pending ||
            message.id !== pending.id ||
            !('result' in message) ||
            'error' in message ||
            'method' in message
          )
            throw failure;
          const waiter = pending;
          pending = undefined;
          waiter.deliver(message.result);
        }
        at = end + 1;
      }
    } catch {
      fail();
    }
  }
  function listen() {
    if (attached) return;
    const input = stream.stdout;
    if (
      input.destroyed ||
      input.readableEnded ||
      input.readableEncoding ||
      input.readableLength !== 0
    )
      throw failure;
    attached = true;
    input.on('error', fail);
    input.once('end', fail);
    input.once('close', fail);
    input.on('data', receive);
  }
  async function send(message: object) {
    ensureCurrent();
    listen();
    ensureCurrent();
    const bytes = Buffer.from(JSON.stringify(message) + '\n');
    await Promise.race([stream.handOff(bytes, signal), cancelled]);
    // Stream EOF and close may follow the final bytes on Node's next tick.
    // Observe them before accepting this response or handing off another RPC.
    await nextTurn();
    ensureCurrent();
  }
  try {
    const result = await probeCodexWorker(
      {
        observedBinary: stream.observedBinary,
        privateProfile: stream.privateProfile,
        request: async (message) => {
          const id = crypto.randomUUID();
          const reply = new Promise<unknown>((deliver) => {
            pending = {id, deliver};
          });
          await send({id, ...message});
          const observed = await Promise.race([reply, cancelled]);
          ensureCurrent();
          return observed;
        },
        notify: send,
      },
      approved,
      origin,
      signal,
    );
    if (parent.aborted) return {kind: 'cancelled'} as const;
    if (
      signal.aborted ||
      performance.now() >= deadline ||
      (attached && (stream.stdout.destroyed || stream.stdout.readableEnded)) ||
      length !== 0
    )
      return {kind: 'unavailable'} as const;
    return result;
  } finally {
    listener.abort();
    pending = undefined;
    if (attached) {
      stream.stdout.off('data', receive);
      stream.stdout.off('close', fail);
      stream.stdout.off('end', fail);
      stream.stdout.off('error', fail);
    }
    stop.abort();
    line.fill(0);
  }
}
