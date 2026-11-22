import {z} from 'zod';

const identifier = z
  .string()
  .min(1)
  .max(512)
  .regex(/^[^\s\p{C}]+$/u);
const status = z.object({
  authMethod: identifier.nullable(),
  authToken: z.null().optional(),
  requiresOpenaiAuth: z.literal(true),
});
const accountRecord = z.object({
  requiresOpenaiAuth: z.literal(true),
  account: z.object({type: z.string()}).nullable(),
  userId: identifier.nullable().optional(),
  workspaceRouting: z
    .object({
      chatgptAccountId: identifier,
      backendOrigin: z.string(),
    })
    .nullable()
    .optional(),
});

type AccountObservation =
  | {kind: 'signed-out' | 'other-auth-method' | 'unavailable' | 'cancelled'}
  | {
      kind: 'observed-chatgpt-workspace';
      userId: string;
      workspaceId: string;
      backendOrigin: string;
    };

type AccountRead =
  | {
      method: 'getAuthStatus';
      params: {includeToken: false; refreshToken: false};
    }
  | {method: 'account/read'; params: {refreshToken: false}};

/** Read account identity from a single, already-initialized worker. This
 * observation does not establish current model access or authorize a turn. */
export async function observeCodexAccount(
  read: (request: AccountRead, signal: AbortSignal) => Promise<unknown>,
  expectedOrigin: string,
  signal: AbortSignal,
): Promise<AccountObservation> {
  if (signal.aborted) return {kind: 'cancelled'};
  if (!URL.canParse(expectedOrigin)) return {kind: 'unavailable'};
  const origin = new URL(expectedOrigin);
  if (origin.protocol !== 'https:' || expectedOrigin !== origin.origin)
    return {kind: 'unavailable'};

  try {
    const auth = status.safeParse(
      await read(
        {
          method: 'getAuthStatus',
          params: {includeToken: false, refreshToken: false},
        },
        signal,
      ),
    );
    if (signal.aborted) return {kind: 'cancelled'};
    if (!auth.success) return {kind: 'unavailable'};
    if (auth.data.authMethod === null) return {kind: 'signed-out'};
    if (auth.data.authMethod !== 'chatgpt') return {kind: 'other-auth-method'};

    const observed = accountRecord.safeParse(
      await read(
        {
          method: 'account/read',
          params: {refreshToken: false},
        },
        signal,
      ),
    );
    if (signal.aborted) return {kind: 'cancelled'};
    if (!observed.success) return {kind: 'unavailable'};
    const {account, userId, workspaceRouting} = observed.data;
    if (
      account?.type !== 'chatgpt' ||
      !userId ||
      workspaceRouting?.backendOrigin !== expectedOrigin
    )
      return {kind: 'unavailable'};
    return {
      kind: 'observed-chatgpt-workspace',
      userId,
      workspaceId: workspaceRouting.chatgptAccountId,
      backendOrigin: workspaceRouting.backendOrigin,
    };
  } catch (error) {
    if (
      signal.aborted ||
      (error instanceof Error && error.name === 'AbortError')
    )
      return {kind: 'cancelled'};
    // Transport errors may contain raw provider output. Expose only the outcome.
    return {kind: 'unavailable'};
  }
}

export {mapRunNotification} from './run-notification.js';
export type {CodexRunBinding} from './run-notification.js';
export {findOriginalTurn} from './turn-recovery.js';
export type {CodexRecoveryReader} from './turn-recovery.js';
