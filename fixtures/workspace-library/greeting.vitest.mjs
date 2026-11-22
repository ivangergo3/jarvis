import {expect, test} from 'vitest';
import {workspaceGreeting} from './src/index.ts';

test('includes the supplied workspace name in the greeting', () => {
  expect(workspaceGreeting('Orbital')).toBe('Hello from Orbital.');
});
