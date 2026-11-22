import {isAbsolute, normalize} from 'node:path';
import {z} from 'zod';
import {observeCodexAccount} from './account.js';

export interface BinaryPin {
  readonly version: string;
  readonly sha256: string;
}

const hello = {
  method: 'initialize',
  params: {
    clientInfo: {name: 'jarvis', title: 'Jarvis', version: '0.1.0'},
    capabilities: {experimentalApi: true},
  },
} as const;

type AccountMessage = Parameters<Parameters<typeof observeCodexAccount>[0]>[0];

/** The supervisor measures the binary, supplies its private profile, and owns
 * the worker lifetime, including the read deadline. Every call uses that child. */
export interface PreflightWorker {
  readonly observedBinary: BinaryPin;
  readonly privateProfile: string;
  request(
    message: typeof hello | AccountMessage,
    signal: AbortSignal,
  ): Promise<unknown>;
  notify(message: {method: 'initialized'}, signal: AbortSignal): Promise<void>;
}

const initialized = z.object({
  userAgent: z.string().trim().min(1).max(2048),
  codexHome: z.string(),
  platformFamily: z.literal('unix'),
  platformOs: z.literal('macos'),
});
const versionPattern = /^codex-cli \d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/;

/** Non-model read on an already supervised worker. A matching version string
 * alone is insufficient; only the measured executable reviewed for this
 * installation may be probed. No return value is a grant to run a task. */
export async function probeCodexWorker(
  worker: PreflightWorker,
  approved: BinaryPin,
  expectedOrigin: string,
  signal: AbortSignal,
) {
  if (signal.aborted) return {kind: 'cancelled'} as const;
  if (
    !versionPattern.test(approved.version) ||
    approved.version.trim() !== approved.version ||
    !/^[0-9a-f]{64}$/.test(approved.sha256) ||
    approved.sha256.length !== 64 ||
    worker.observedBinary.version !== approved.version ||
    worker.observedBinary.sha256 !== approved.sha256
  )
    return {kind: 'unsupported-build'} as const;
  const profile = worker.privateProfile;
  if (
    !isAbsolute(profile) ||
    normalize(profile) !== profile ||
    profile === '/' ||
    profile.endsWith('/') ||
    /[\p{C}]/u.test(profile)
  )
    return {kind: 'unavailable'} as const;
  try {
    const response = initialized.safeParse(await worker.request(hello, signal));
    if (signal.aborted) return {kind: 'cancelled'} as const;
    if (!response.success || response.data.codexHome !== profile)
      return {kind: 'incompatible-handshake'} as const;
    await worker.notify({method: 'initialized'}, signal);
    return await observeCodexAccount(
      (message, token) => worker.request(message, token),
      expectedOrigin,
      signal,
    );
  } catch (error) {
    if (
      signal.aborted ||
      (error instanceof Error && error.name === 'AbortError')
    )
      return {kind: 'cancelled'} as const;
    return {kind: 'unavailable'} as const;
  }
}
