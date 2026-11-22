import assert from 'node:assert/strict';
import test from 'node:test';
import {ESLint} from 'eslint';

test('workspace lint rejects and restores unsafe JavaScript', async () => {
  const eslint = new ESLint();
  const filePath = 'fixtures/verify-workspace.mjs';
  const [invalid] = await eslint.lintText("var value = eval('0');", {filePath});
  assert.deepEqual(invalid.messages.map(message => message.ruleId), ['no-var', 'no-eval']);
  const [restored] = await eslint.lintText('export const value = 0;', {filePath});
  assert.deepEqual(restored.messages, []);
});

test('workspace lint rejects direct Array construction and accepts Array.from', async () => {
  const eslint = new ESLint();
  const filePath = 'fixtures/verify-workspace.mjs';
  const [invalid] = await eslint.lintText('Array(3); new Array(3);', {filePath});
  assert.deepEqual(invalid.messages.map(message => message.ruleId), [
    'no-restricted-syntax', 'no-restricted-syntax',
  ]);
  const [clean] = await eslint.lintText('export const items = Array.from([3]);', {filePath});
  assert.deepEqual(clean.messages, []);
});
