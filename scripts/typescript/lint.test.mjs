import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import {workspaceESLint} from './workspace-eslint.mjs';

test('normal command checks tracked sources using the workspace config', (t) => {
  const root = mkdtempSync(path.join(os.tmpdir(), 'jarvis-eslint-'));
  t.after(() => rmSync(root, {recursive: true, force: true}));
  execFileSync('git', ['init', '-q', root]);
  copyFileSync('eslint.config.mjs', path.join(root, 'eslint.config.mjs'));
  symlinkSync(path.resolve('node_modules'), path.join(root, 'node_modules'));
  const owner = path.join(root, 'packages/sample');
  mkdirSync(path.join(owner, 'node_modules'), {recursive: true});
  writeFileSync(path.join(owner, 'eslint.config.mjs'), 'export default [];');
  writeFileSync(path.join(root, '.gitignore'), 'node_modules/\nbuild/\n');
  const input = path.join(owner, 'node_modules/example.js');
  const removed = path.join(owner, 'removed.js');
  writeFileSync(input, 'Array(2);');
  writeFileSync(removed, 'Array(3);');
  execFileSync('git', ['add', '-f', input, removed], {cwd: root});
  rmSync(removed);
  function lint() {
    return spawnSync(
      process.execPath,
      [path.resolve('scripts/typescript/lint.mjs')],
      {cwd: root, encoding: 'utf8'},
    );
  }
  const invalid = lint();
  assert.equal(invalid.status, 1, invalid.stderr);
  assert.match(invalid.stderr, /no-restricted-syntax/);
  writeFileSync(input, 'Array.from([2]);');
  const restored = lint();
  assert.equal(restored.status, 0, restored.stderr);
  const topLevel = path.join(root, 'vite.config.mjs');
  writeFileSync(topLevel, 'Array(3);');
  assert.match(lint().stderr, /vite\.config\.mjs/);
  writeFileSync(topLevel, 'Array.from([3]);');
  assert.equal(lint().status, 0);
  symlinkSync(topLevel, path.join(owner, 'unrelated.ts'));
  const built = path.join(root, 'build/private.js');
  mkdirSync(path.dirname(built));
  writeFileSync(built, 'Array(1);');
  execFileSync('git', ['add', '-f', built], {cwd: root});
  assert.match(lint().stderr, /private\.js/);
  writeFileSync(built, 'Array.from([1]);');
  assert.equal(lint().status, 0);
  rmSync(input);
  symlinkSync(path.join(root, 'eslint.config.mjs'), input);
  assert.match(lint().stderr, /Expected a regular workspace source file/);
  rmSync(input);
  mkdirSync(input);
  assert.match(lint().stderr, /Expected a regular workspace source file/);
});

test('workspace lint rejects and restores unsafe JavaScript', async () => {
  const eslint = workspaceESLint();
  const filePath = 'fixtures/verify-workspace.mjs';
  const [invalid] = await eslint.lintText("var value = eval('0');", {filePath});
  assert.deepEqual(
    invalid.messages.map((message) => message.ruleId),
    ['no-var', 'no-eval'],
  );
  const [restored] = await eslint.lintText('export const value = 0;', {
    filePath,
  });
  assert.deepEqual(restored.messages, []);
});

test('workspace lint rejects direct Array construction and accepts Array.from', async () => {
  const eslint = workspaceESLint();
  const filePath = 'fixtures/verify-workspace.mjs';
  const [invalid] = await eslint.lintText('Array(3); new Array(3);', {
    filePath,
  });
  assert.deepEqual(
    invalid.messages.map((message) => message.ruleId),
    ['no-restricted-syntax', 'no-restricted-syntax'],
  );
  const [clean] = await eslint.lintText(
    'export const items = Array.from([3]);',
    {filePath},
  );
  assert.deepEqual(clean.messages, []);
});
