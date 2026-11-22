import {z} from 'zod';

/** A worker exiting alone does not establish the provider's outcome. */
const WorkerExit = z.enum([
  'pending',
  'unverified',
  'verified_forced',
  'verified_cooperative',
]);
const workerExit = WorkerExit.optional();
export const RunObservation = z.discriminatedUnion('state', [
  z.strictObject({
    state: z.enum([
      'queued',
      'reserved_for_start',
      'parked_unsent',
      'dispatching',
      'running',
      'waiting',
    ]),
    workerExit,
  }),
  z.strictObject({
    state: z.literal('preparing_thread'),
    setupHandoff: z.enum(['not_sent', 'handed_off', 'possibly_handed_off']),
    workerExit,
  }),
  z.strictObject({
    state: z.literal('cancel_requested'),
    cutoff: z.enum(['pending', 'established']),
    workerExit,
  }),
  z.strictObject({
    state: z.literal('terminal_unsent'),
    setupFence: z.enum(['none', 'retained']),
    workerExit,
  }),
  z.strictObject({
    state: z.literal('completed'),
    workerExit,
  }),
  z.strictObject({
    state: z.literal('interrupted'),
    workerExit: WorkerExit,
    providerEffect: z.literal('verified_interruption'),
  }),
  z.strictObject({
    state: z.literal('failed'),
    workerExit,
    reason: z.enum([
      'provider_refused',
      'execution_failed',
      'destination_changed',
    ]),
  }),
  z.strictObject({
    state: z.literal('unknown'),
    workerExit,
    phase: z.enum(['thread_setup', 'turn_handoff', 'provider_effect']),
  }),
]);
export type RunObservation = z.infer<typeof RunObservation>;

export const SessionBinding = z.enum(['unbound', 'bound', 'unresolved']);
export const DeliveryState = z.enum([
  'pending',
  'delivered',
  'unknown',
  'expired',
  'canceled_before_handoff',
]);
export const RequestKind = z.enum(['approval', 'input']);
export const RequestStatus = z.enum([
  'awaiting_answer',
  'claimed',
  'resolved',
  'withdrawn',
  'unavailable',
]);
export const RequestMetadata = z.discriminatedUnion('status', [
  z.strictObject({
    kind: RequestKind,
    status: RequestStatus.exclude(['unavailable']),
  }),
  z.strictObject({
    kind: RequestKind,
    status: z.literal('unavailable'),
    reason: z.enum([
      'session_changed',
      'channel_lost',
      'scope_unverified',
      'run_ended',
    ]),
  }),
]);
export type RequestMetadata = z.infer<typeof RequestMetadata>;

export type SessionBinding = z.infer<typeof SessionBinding>;
export type DeliveryState = z.infer<typeof DeliveryState>;
export type RequestKind = z.infer<typeof RequestKind>;
export type RequestStatus = z.infer<typeof RequestStatus>;
