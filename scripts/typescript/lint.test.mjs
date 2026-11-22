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
  const linkedTypeScript = path.join(owner, 'unrelated.ts');
  symlinkSync(topLevel, linkedTypeScript);
  assert.match(lint().stderr, /Expected a regular workspace source file/);
  rmSync(linkedTypeScript);
  const typed = path.join(owner, 'input.ts');
  writeFileSync(
    path.join(owner, 'tsconfig.json'),
    JSON.stringify({compilerOptions: {strict: true}, files: ['input.ts']}),
  );
  writeFileSync(typed, 'export const input: any = 1;');
  const invalidType = lint();
  assert.equal(invalidType.status, 1, invalidType.stderr);
  assert.match(invalidType.stderr, /no-explicit-any/);
  writeFileSync(typed, 'export const input = 1;');
  assert.equal(lint().status, 0);
  const additionalSource = path.join(
    root,
    'evaluations/typescript-skills-113/case/runner.js',
  );
  mkdirSync(path.dirname(additionalSource), {recursive: true});
  writeFileSync(additionalSource, 'eval("1");');
  assert.match(lint().stderr, /no-eval/);
  rmSync(additionalSource);
  const built = path.join(root, 'build/private.js');
  mkdirSync(path.dirname(built));
  writeFileSync(built, 'Array(1);');
  execFileSync('git', ['add', '-f', built], {cwd: root});
  assert.match(lint().stderr, /private\.js/);
  writeFileSync(built, 'Array.from([1]);');
  assert.equal(lint().status, 0);
  writeFileSync(
    path.join(owner, 'tsconfig.json'),
    JSON.stringify({
      compilerOptions: {
        strict: true,
        module: 'NodeNext',
        verbatimModuleSyntax: true,
      },
      files: ['input.ts', 'hook.cts', 'controls.cts'],
    }),
  );
  writeFileSync(
    path.join(owner, 'controls.cts'),
    'const read = (n: number) => n; export = read;',
  );
  const hook = path.join(owner, 'hook.cts');
  const commonJS = `import read = require('./controls.cjs');
declare function useState(n: number): number;
declare function useEffect(f: () => void, deps: readonly unknown[]): void;
function usePanel(value: number) { useEffect(() => { read(value); }, [value]); return useState(value); }
export = usePanel;`;
  writeFileSync(
    hook,
    commonJS
      .replace('[value]', '[]')
      .replace(
        'return useState(value)',
        'if (value) return useState(value); return 0',
      ),
  );
  const brokenHook = lint();
  assert.match(brokenHook.stderr, /react-hooks\/rules-of-hooks/);
  assert.match(brokenHook.stderr, /react-hooks\/exhaustive-deps/);
  writeFileSync(hook, commonJS);
  const restoredHook = lint();
  assert.equal(restoredHook.status, 0, restoredHook.stderr);
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

test('typed lint distinguishes unsafe data and floating promises from handled operations', async () => {
  const eslint = workspaceESLint();
  const filePath = 'fixtures/workspace-library/src/index.ts';
  const compare = (operator) =>
    `export const same = (left: number, right: number) => left ${operator} right;`;
  const [loose] = await eslint.lintText(compare('=='), {filePath});
  assert.ok(loose.messages.some((message) => message.ruleId === 'eqeqeq'));
  const [strict] = await eslint.lintText(compare('==='), {filePath});
  assert.deepEqual(strict.messages, []);
  for (const [code, rule] of [
    ['export const input: any = 1;', 'no-explicit-any'],
    ["export const input: string = JSON.parse('1');", 'no-unsafe-assignment'],
    ['Promise.resolve(1);', 'no-floating-promises'],
    ['void Promise.resolve(1);', 'no-floating-promises'],
    ['// @ts-ignore\nexport const value = 1;', 'ban-ts-comment'],
  ]) {
    const [result] = await eslint.lintText(code, {filePath});
    assert.ok(
      result.messages.some(
        (message) => message.ruleId === '@typescript-eslint/' + rule,
      ),
      JSON.stringify(result.messages),
    );
  }
  const [clean] = await eslint.lintText(
    'export const value: number = await Promise.resolve(1);',
    {filePath},
  );
  assert.deepEqual(clean.messages, []);
});

test('React lint checks Hook call order and effect dependencies', async () => {
  const eslint = workspaceESLint();
  for (const filePath of [
    'apps/client/src/fixture.cjs',
    'packages/ui/src/example.cts',
    'fixtures/workspace-library/example.cjs',
  ]) {
    const config = await eslint.calculateConfigForFile(filePath);
    assert.equal(config.rules['react-hooks/rules-of-hooks'][0], 2);
    assert.equal(config.rules['react-hooks/exhaustive-deps'][0], 2);
  }
  const filePath = 'scripts/example.cjs';
  for (const [code, rule] of [
    ['function View({show}) { if (show) { useState(1); } }', 'rules-of-hooks'],
    [
      'function View({name}) { useEffect(() => render(name), []); }',
      'exhaustive-deps',
    ],
  ]) {
    const [result] = await eslint.lintText(code, {filePath});
    assert.ok(
      result.messages.some(
        (message) => message.ruleId === 'react-hooks/' + rule,
      ),
      JSON.stringify(result.messages),
    );
  }
  const [clean] = await eslint.lintText(
    'function View({name}) { useEffect(() => render(name), [name]); }',
    {filePath},
  );
  assert.deepEqual(clean.messages, []);
});
