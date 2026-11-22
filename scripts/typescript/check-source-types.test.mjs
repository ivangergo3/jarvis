import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

test('public typecheck covers owned standalone tools and keeps package tasks', (t) => {
  const root = mkdtempSync(path.join(os.tmpdir(), 'jarvis-public-typecheck-'));
  t.after(() => rmSync(root, {recursive: true, force: true}));
  execFileSync('git', ['init', '-q', root]);
  for (const name of [
    'package.json',
    'pnpm-workspace.yaml',
    'pnpm-lock.yaml',
    'turbo.json',
    'tsconfig.base.json',
    'fixtures/workspace-library/package.json',
    'fixtures/workspace-library/tsconfig.json',
    'fixtures/workspace-library/src/index.ts',
    'scripts/run-workspace.mjs',
    'scripts/typescript/check-source-types.mjs',
    'scripts/typescript/source-files.mjs',
  ]) {
    const target = path.join(root, name);
    mkdirSync(path.dirname(target), {recursive: true});
    copyFileSync(name, target);
  }
  symlinkSync(path.resolve('node_modules'), path.join(root, 'node_modules'));
  const config = path.join(root, 'tsconfig.json');
  writeFileSync(
    config,
    JSON.stringify({
      extends: './tsconfig.base.json',
      compilerOptions: {noEmit: true},
      files: [],
    }),
  );
  writeFileSync(
    path.join(root, '.gitignore'),
    'node_modules/\n.build/\n.turbo/\n.private/\n',
  );
  const run = () => {
    const result = spawnSync('pnpm', ['typecheck'], {
      cwd: root,
      encoding: 'utf8',
    });
    assert.ifError(result.error);
    return result;
  };
  const initial = run();
  assert.equal(initial.status, 0, initial.stdout + initial.stderr);
  const source = path.join(root, 'scripts/demo.ts');
  writeFileSync(source, "export const value: number = 'broken';");
  assert.match(run().stderr, /include this standalone source/);
  const project = JSON.parse(readFileSync(config, 'utf8'));
  project.files = ['scripts/demo.ts'];
  writeFileSync(config, JSON.stringify(project));
  assert.match(run().stderr, /TS2322/);
  mkdirSync(path.join(root, '.private'));
  writeFileSync(
    path.join(root, '.private/private.ts'),
    "export const value: never = 'private fixture marker';",
  );
  writeFileSync(
    source,
    "import {value} from '../.private/private.js'; export {value};",
  );
  const hidden = run();
  assert.notEqual(hidden.status, 0);
  assert.match(hidden.stderr, /TS2307/);
  assert.doesNotMatch(hidden.stderr, /private fixture marker/);
  writeFileSync(
    source,
    "export * from '../fixtures/workspace-library/src/index.js';",
  );
  const packageSource = run();
  assert.notEqual(packageSource.status, 0);
  assert.match(packageSource.stderr, /TS2307/);
  writeFileSync(
    source,
    '/// <reference path="../fixtures/workspace-library/dist/index.d.ts" />\nexport {};',
  );
  const generated = run();
  assert.match(generated.stderr, /TS6053/);
  assert.match(generated.stderr, /native typecheck task/);
  writeFileSync(source, 'export const value: number = 42;');
  writeFileSync(
    config,
    JSON.stringify({
      ...project,
      compilerOptions: {...project.compilerOptions, noCheck: true},
    }),
  );
  assert.match(run().stderr, /strictly typed with noEmit/);
  writeFileSync(
    config,
    JSON.stringify({
      ...project,
      references: [{path: './fixtures/workspace-library'}],
    }),
  );
  assert.match(run().stderr, /use a workspace package/);
  writeFileSync(config, JSON.stringify(project));
  const restored = run();
  assert.equal(restored.status, 0, restored.stdout + restored.stderr);
  assert.equal(existsSync(path.join(root, 'scripts/demo.js')), false);
  const nested = 'fixtures/workspace-library/nested';
  mkdirSync(path.join(root, nested));
  writeFileSync(
    path.join(root, nested, 'package.json'),
    JSON.stringify({name: '@jarvis/nested-tool', private: true}),
  );
  writeFileSync(
    path.join(root, nested, 'tool.ts'),
    "export const count: number = 'wrong';",
  );
  const workspace = path.join(root, 'pnpm-workspace.yaml');
  writeFileSync(
    workspace,
    readFileSync(workspace, 'utf8') +
      "  - 'fixtures/workspace-library/nested'\n",
  );
  assert.match(
    run().stderr,
    /nested\/tool\.ts: include this standalone source/,
  );
});
