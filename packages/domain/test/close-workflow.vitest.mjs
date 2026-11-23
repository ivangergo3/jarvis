import {expect, it} from 'vitest';
import {DesktopShutdown} from '../src/close-workflow.ts';
const id = '434adcec-c0b4-49e9-88d0-ec03ddb5b806';
const foreign = '88c41b0c-6c61-412e-942b-022dd6046936';
const complete = Object.freeze({
  editsFrozen: true,
  admissionClosed: true,
  decisionPersisted: true,
  draftsPersisted: true,
  outcomesPersisted: true,
  workersStopped: true,
  serviceStopped: true,
});
function started() {
  const shutdown = new DesktopShutdown();
  const ask = shutdown.request();
  expect(shutdown.answer(ask.prompt, true, id)).toEqual({
    action: 'start',
    shutdownId: id,
  });
  return shutdown;
}
it('overlapping native gestures share one dialog and Cancel leaves work running', () => {
  const shutdown = new DesktopShutdown();
  const ask = shutdown.request();
  expect(ask.action).toBe('ask');
  expect(shutdown.request().action).toBe('hold');
  expect(shutdown.answer(ask.prompt, false).action).toBe('hold');
  const another = shutdown.request();
  expect(another.prompt).not.toBe(ask.prompt);
  expect(shutdown.answer(ask.prompt, true, id).action).toBe('hold');
  expect(shutdown.state.phase).toBe('confirming');
  for (const response of [1, 'yes', false]) {
    const prompt = shutdown.request().prompt ?? shutdown.state.prompt;
    expect(shutdown.answer(prompt, response, id).action).toBe('hold');
    expect(shutdown.state.phase).toBe('running');
  }
});
it('one affirmative close starts exactly one shutdown and later gestures recheck its original identity', () => {
  const shutdown = started();
  expect(shutdown.answer(1, true, foreign).action).toBe('hold');
  expect(shutdown.request()).toEqual({action: 'recheck', shutdownId: id});
  shutdown.observe({shutdownId: foreign, revision: 500, observed: complete});
  expect(shutdown.request().action).toBe('recheck');
  const other = new DesktopShutdown();
  const ask = other.request();
  expect(other.answer(ask.prompt, true, 'invalid').action).toBe('hold');
  expect(other.state.phase).toBe('running');
});
it('every missing shutdown fact holds the window open until a newer complete snapshot', () => {
  for (const key of Object.keys(complete)) {
    const shutdown = started();
    shutdown.observe({
      shutdownId: id,
      revision: 1,
      observed: {...complete, [key]: false},
    });
    expect(shutdown.state.reasons).toHaveLength(1);
    expect(shutdown.request().action).toBe('recheck');
    shutdown.observe({shutdownId: id, revision: 2, observed: complete});
    expect(shutdown.request().action).toBe('allow');
  }
});
it('a late read or repeated close cannot lose a newer draft failure or reopen a verified shutdown', () => {
  const shutdown = started();
  const saved = {shutdownId: id, revision: 1, observed: complete};
  shutdown.observe({
    ...saved,
    revision: 2,
    observed: {...complete, draftsPersisted: false},
  });
  shutdown.observe(saved);
  shutdown.observe({...saved, revision: 2});
  expect(shutdown.state.reasons).toEqual(['Saved text and image drafts']);
  shutdown.unavailable(id);
  expect(shutdown.state.reasons).toContain('Saved text and image drafts');
  shutdown.observe({...saved, revision: 3});
  shutdown.unavailable(id);
  shutdown.observe({...saved, revision: 4, observed: {}});
  expect(shutdown.state.phase).toBe('verified');
});
it('unavailable, malformed or foreign evidence cannot grant permission to quit', () => {
  const shutdown = started();
  shutdown.unavailable(foreign);
  expect(shutdown.state.phase).toBe('stopping');
  shutdown.unavailable(id);
  shutdown.unavailable(id);
  expect(shutdown.state.reasons).toEqual(['Shutdown evidence is unavailable']);
  for (const revision of [NaN, -1, Number.MAX_SAFE_INTEGER + 1, 0.5])
    shutdown.observe({shutdownId: id, revision, observed: complete});
  expect(shutdown.state.phase).toBe('unresolved');
  shutdown.observe({
    shutdownId: id,
    revision: 1,
    observed: {...complete, draftsPersisted: 1},
  });
  expect(shutdown.state.reasons).toEqual(['Saved text and image drafts']);
  expect(() => shutdown.state.reasons.pop()).toThrow();
});
