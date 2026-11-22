import {expect, test} from 'vitest';
import {
  DeliveryState,
  RequestMetadata,
  RunObservation,
  SessionBinding,
} from '../src/index.ts';

test('ambiguous setup, provider refusals, unsent runs and verified stops stay distinguishable', () => {
  for (const state of [
    {state: 'unknown', phase: 'thread_setup'},
    {state: 'cancel_requested', cutoff: 'pending'},
    {state: 'cancel_requested', cutoff: 'established'},
    {state: 'preparing_thread', setupHandoff: 'possibly_handed_off'},
    {state: 'unknown', phase: 'provider_effect', workerExit: 'verified_forced'},
    {state: 'completed', workerExit: 'verified_forced'},
    {state: 'failed', reason: 'execution_failed', workerExit: 'pending'},
    {state: 'terminal_unsent', setupFence: 'retained'},
    {
      state: 'interrupted',
      workerExit: 'pending',
      providerEffect: 'verified_interruption',
    },
    {
      state: 'interrupted',
      workerExit: 'unverified',
      providerEffect: 'verified_interruption',
    },
    {
      state: 'interrupted',
      workerExit: 'verified_forced',
      providerEffect: 'verified_interruption',
    },
    {state: 'failed', reason: 'provider_refused'},
  ]) {
    expect(RunObservation.parse(state)).toEqual(state);
  }
  expect(
    RunObservation.safeParse({
      state: 'unknown',
      phase: 'turn_handoff',
      retry: true,
    }).success,
  ).toBe(false);
  expect(RunObservation.safeParse({state: 'interrupted'}).success).toBe(false);
  expect(RunObservation.safeParse({state: 'cancel_requested'}).success).toBe(
    false,
  );
  for (const workerExit of [
    'unverified',
    'verified_forced',
    'verified_cooperative',
  ])
    expect(
      RunObservation.safeParse({
        state: 'interrupted',
        workerExit,
        providerEffect: 'unknown',
      }).success,
    ).toBe(false);
});

test('session binding and public request status omit live credentials and private answers', () => {
  expect(SessionBinding.parse('unresolved')).toBe('unresolved');
  expect(DeliveryState.parse('unknown')).toBe('unknown');
  expect(DeliveryState.safeParse('possibly_delivered').success).toBe(false);
  const retired = {
    kind: 'approval',
    status: 'unavailable',
    reason: 'session_changed',
  };
  expect(RequestMetadata.parse(retired)).toEqual(retired);
  expect(
    RequestMetadata.safeParse({kind: 'input', status: 'unavailable'}).success,
  ).toBe(false);
  expect(
    RequestMetadata.safeParse({...retired, channel: 'private'}).success,
  ).toBe(false);
  expect(
    RequestMetadata.safeParse({
      kind: 'input',
      status: 'resolved',
      answer: 'private',
    }).success,
  ).toBe(false);
});
