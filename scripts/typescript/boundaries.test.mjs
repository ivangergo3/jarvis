import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {
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
import {checkBoundaries} from './boundaries.mjs';

test('workspace packages enforce their runtime, public entry and graph direction', (t) => {
  const root = mkdtempSync(path.join(os.tmpdir(), 'jarvis-import-policy-'));
  t.after(() => rmSync(root, {recursive: true, force: true}));
  execFileSync('git', ['init', '--quiet', root]);

  function checked() {
    execFileSync('git', ['add', '-A'], {cwd: root});
    return checkBoundaries(root);
  }
  function write(file, content) {
    const target = path.join(root, file);
    mkdirSync(path.dirname(target), {recursive: true});
    writeFileSync(target, content);
  }
  const {packageManager} = JSON.parse(
    readFileSync(new URL('../../package.json', import.meta.url), 'utf8'),
  );
  write(
    'package.json',
    JSON.stringify({
      name: 'root-fixture',
      private: true,
      packageManager,
      devDependencies: {vitest: '*'},
    }),
  );
  write('pnpm-workspace.yaml', "packages:\n  - 'apps/*'\n  - 'packages/*'\n");
  for (const owner of [
    'packages/domain',
    'packages/contracts',
    'packages/providers',
    'apps/client',
  ]) {
    write(
      owner + '/package.json',
      JSON.stringify({name: '@jarvis/' + path.basename(owner)}),
    );
    write(owner + '/src/index.ts', 'export {};');
  }

  write('.git/info/exclude', 'node_modules/\n');
  const clientManifest = {
    name: '@jarvis/client',
    type: 'module',
    dependencies: {
      '@jarvis/contracts': 'workspace:*',
      react: '*',
      'react-dom': '*',
    },
  };
  write('apps/client/package.json', JSON.stringify(clientManifest));
  write(
    'apps/client/node_modules/react-dom/package.json',
    JSON.stringify({name: 'react-dom'}),
  );
  write('apps/client/src/mount.ts', "import 'react-dom/client';");
  function installLink(owner, name, target) {
    mkdirSync(path.join(root, owner, 'node_modules/@jarvis'), {
      recursive: true,
    });
    symlinkSync(
      path.join(root, target),
      path.join(root, owner, 'node_modules/@jarvis', name),
    );
  }
  installLink('apps/client', 'contracts', 'packages/contracts');
  installLink('apps/client', 'providers', 'packages/providers');
  installLink('packages/contracts', 'client', 'apps/client');
  installLink('packages/providers', 'root', '.');
  const contracts = {
    name: '@jarvis/contracts',
    type: 'module',
    exports: './src/index.mjs',
    dependencies: {'@jarvis/workspace-fixture': 'workspace:*'},
  };
  const fixture = 'fixtures/workspace-library';
  const fixtureManifest = readFileSync(
    new URL('../../fixtures/workspace-library/package.json', import.meta.url),
    'utf8',
  );
  write(fixture + '/package.json', fixtureManifest);
  write(fixture + '/src/index.ts', 'export {};');
  installLink('packages/contracts', 'workspace-fixture', fixture);
  // Its exported dist files have not been generated on a fresh checkout.
  write(
    'packages/contracts/src/library.ts',
    "export * from '@jarvis/workspace-fixture';",
  );
  write('packages/contracts/package.json', JSON.stringify(contracts));
  write('packages/contracts/src/index.mjs', 'export {};');
  write('packages/contracts/src/self.ts', "import '@jarvis/contracts';");
  write(
    'packages/contracts/src/helper.test.d.ts',
    'export type Example = number;',
  );
  write('apps/client/src/theme.css', ':root { color: cyan; }');
  write('apps/client/src/app.ts', "import './theme.css';");
  const rootManifest = JSON.parse(
    readFileSync(path.join(root, 'package.json'), 'utf8'),
  );
  write(
    'package.json',
    JSON.stringify({
      ...rootManifest,
      type: 'module',
      dependencies: {'@jarvis/contracts': 'workspace:*'},
    }),
  );
  installLink('.', 'contracts', 'packages/contracts');
  write(
    'packages/domain/package.json',
    JSON.stringify({name: 'jarvis-domain'}),
  );
  write('fixtures/verify-workspace.mjs', "import 'jarvis-domain';");
  assert.match(checked().join('\n'), /unknown workspace or indirect import/);
  write(
    'fixtures/verify-workspace.mjs',
    "import(('@jarvis/contracts/src/private'));",
  );
  assert.match(checked().join('\n'), /use the public package root/);
  write(
    'fixtures/verify-workspace.mjs',
    "import('@jarvis/contracts' + '/private');",
  );
  assert.match(checked().join('\n'), /specifier must be a literal/);
  write('fixtures/verify-workspace.mjs', "import '@jarvis/contracts';");
  write('.git/info/exclude', 'node_modules/\nfixtures/generated.mjs\n');
  write('fixtures/generated.mjs', 'export {};');
  write('fixtures/verify-workspace.mjs', "import './generated.mjs';");
  assert.match(checked().join('\n'), /relative target must be tracked/);
  write('fixtures/verify-workspace.mjs', "import '@jarvis/contracts';");
  write('packages/contracts/src/check.cjs', "require('./local');");
  assert.match(checked().join('\n'), /relative target must be tracked/);
  write('packages/contracts/src/local/index.js', 'export {};');
  const desktop = 'apps/desktop';
  write(
    desktop + '/package.json',
    JSON.stringify({
      name: '@jarvis/desktop',
      devDependencies: {
        electron: '*',
        '@jarvis/workspace-fixture': 'workspace:*',
      },
    }),
  );
  write(desktop + '/node_modules/electron/package.json', '{"name":"electron"}');
  installLink(desktop, 'workspace-fixture', fixture);
  const main = desktop + '/src/main.mts';
  const preload = desktop + '/src/preload.cts';
  const sibling = desktop + '/src/view.ts';
  write(main, "import 'electron'; import 'node:path';");
  write(preload, "import electron = require('electron');");
  write(sibling, 'export {};');
  assert.deepEqual(checked(), []);
  for (const [file, statement, reason] of [
    [main, "import 'node:child_process';", 'unapproved external dependency'],
    [
      main,
      "import '@jarvis/workspace-fixture';",
      'unapproved external dependency',
    ],
    [preload, "import 'node:fs';", 'unapproved external dependency'],
    [sibling, "import 'electron';", 'unapproved external dependency'],
    [sibling, "import './preload.cjs';", 'privileged Electron entry points'],
    [preload, "import './main.mjs';", 'privileged Electron entry points'],
    [main, "import './view.js';", 'cannot import local implementation'],
    [
      'apps/client/src/electron.ts',
      "import 'electron';",
      'unapproved external dependency',
    ],
  ]) {
    write(file, statement);
    assert.ok(
      checked().some(
        (message) => message.includes(file) && message.includes(reason),
      ),
    );
    write(file, 'export {};');
  }
  assert.deepEqual(checked(), []);
  write('packages/contracts/src/no-extension', 'module.exports = {};');
  write('packages/contracts/src/check.cjs', "require('./no-extension');");
  assert.match(checked().join('\n'), /relative target must be tracked/);
  write('packages/contracts/src/check.cjs', "require('./local/index.js');");
  assert.deepEqual(checked(), []);
  write(
    'fixtures/root.ts',
    '/// <reference path="../packages/contracts/src/index.mjs" />',
  );
  assert.match(checked().join('\n'), /triple-slash references/);
  write('fixtures/root.ts', 'export {};');
  write('node_modules/vitest/package.json', JSON.stringify({name: 'vitest'}));
  assert.deepEqual(checked(), []);
  write(
    'packages/contracts/src/library.cts',
    [
      'import type {workspaceGreeting} from "@jarvis/workspace-fixture" with {"resolution-mode": "import"};',
      'export type {workspaceGreeting as Greeting} from "@jarvis/workspace-fixture" with {"resolution-mode": "import"};',
    ].join('\n'),
  );
  assert.deepEqual(checked(), []);
  write(
    'packages/contracts/src/library.cts',
    "void import('@jarvis/workspace-fixture');",
  );
  assert.deepEqual(checked(), []);
  write('apps/client/package.json', JSON.stringify(clientManifest));
  symlinkSync(
    path.join(root, 'packages/contracts'),
    path.join(root, 'apps/client/node_modules/fs'),
  );
  write(
    'apps/client/package.json',
    JSON.stringify({
      ...clientManifest,
      dependencies: {
        ...clientManifest.dependencies,
        fs: 'workspace:@jarvis/contracts@*',
      },
    }),
  );
  write('apps/client/src/builtin.ts', "import 'fs';");
  assert.match(checked().join('\n'), /unapproved external/);
  write('apps/client/src/builtin.ts', "import '@jarvis/contracts';");
  write('apps/client/package.json', JSON.stringify(clientManifest));
  assert.deepEqual(checked(), []);
  for (const source of [
    "new require('fs');",
    "require.call(null, 'fs');",
    'const load = require;',
    "new module.require('fs');",
    'const {require: load} = module;',
  ]) {
    write('packages/contracts/src/loader.cjs', source);
    assert.match(checked().join('\n'), /use a direct require call/, source);
    write(
      'packages/contracts/src/loader.cjs',
      "module.exports = require('./local/index.js');",
    );
    assert.deepEqual(checked(), []);
  }
  write(
    'packages/contracts/src/loader.cjs',
    'function select(require, module, key) { return require(module.require(key)); }',
  );
  assert.deepEqual(checked(), []);
  write('packages/contracts/src/export.js', 'module.exports = {};');
  assert.match(checked().join('\n'), /CommonJS globals are unavailable/);
  write(
    'packages/contracts/package.json',
    JSON.stringify({...contracts, type: 'commonjs'}),
  );
  assert.deepEqual(checked(), []);
  write('packages/contracts/src/export.js', 'export default {};');
  write('packages/contracts/package.json', JSON.stringify(contracts));
  assert.deepEqual(checked(), []);
  write(
    'packages/contracts/src/ambient.cts',
    "declare const module: { require(id: string): unknown }; module.require('node:fs');",
  );
  assert.match(
    checked().join('\n'),
    /do not redeclare CommonJS runtime bindings/,
  );
  write(
    'packages/contracts/src/ambient.cts',
    'function select(module: { require(id: string): unknown }) { return module.require("local"); }',
  );
  assert.deepEqual(checked(), []);
  write(
    'packages/contracts/src/loader.cjs',
    "var require; require('node:path');",
  );
  assert.match(
    checked().join('\n'),
    /do not redeclare CommonJS runtime bindings/,
  );
  write(
    'packages/contracts/src/loader.cjs',
    "module.exports = require('./local/index.js');",
  );
  for (const suffix of ['mts', 'mjs']) {
    const file = 'packages/providers/src/environment.' + suffix;
    write(file, "module.require('node:path');");
    assert.match(checked().join('\n'), /CommonJS globals are unavailable/);
    write(file, "import 'node:path';");
    assert.deepEqual(checked(), []);
  }
  const valid = "import type {Job} from '@jarvis/contracts';";
  for (const [owner, source, diagnostic] of [
    [
      'packages/providers',
      "require('fixture/../other');",
      'noncanonical package import',
    ],
    [
      'apps/client',
      "export * from '@jarvis/providers';",
      'forbidden dependency direction',
    ],
    [
      'packages/providers',
      "import '@jarvis/root';",
      'forbidden dependency direction',
    ],
    [
      'packages/contracts',
      "import type {Example} from './helper.test.d.ts';",
      'production import of test code',
    ],
    ['apps/client', "import('node:child_process');", 'unapproved external'],
    ['apps/client', "import token from 'keytar';", 'unapproved external'],
    ['apps/client', "import 'react-dom/server.node';", 'unapproved external'],
    ['apps/client', 'import(window.name);', 'specifier must be a literal'],
    ['apps/client', "require('electron');", 'unapproved external'],
    ['apps/client', "(require)('node:fs');", 'unapproved external'],
    ['apps/client', "(module).require(('node:fs'));", 'unapproved external'],
    ['apps/client', "module[('require')]('node:fs');", 'unapproved external'],
    [
      'apps/client',
      "import type {Secret} from '@jarvis/contracts/src/private';",
      'public package root',
    ],
    [
      'packages/contracts',
      "type P = import('child_process').ChildProcess;",
      'unapproved external',
    ],
    [
      'packages/contracts',
      "import vault = require('keytar');",
      'unapproved external',
    ],
    [
      'packages/contracts',
      "export * from '../../../apps/client/src/index.js';",
      'public workspace package',
    ],
    [
      'packages/contracts',
      "import '@jarvis/client';",
      'forbidden dependency direction',
    ],
    [
      'packages/contracts',
      '/// <reference lib="dom" />',
      'triple-slash references',
    ],
    ['packages/contracts', "import 'react';", 'unapproved external'],
    ['packages/contracts', "import 'vitest';", 'unapproved external'],
    [
      'packages/contracts',
      "import './secret.test.js';",
      'production import of test code',
    ],
    [
      'packages/providers',
      "import 'file:///workspace/apps/client/index.js';",
      'indirect import',
    ],
    [
      'packages/contracts',
      '/// <reference types="node" />',
      'triple-slash references',
    ],
  ]) {
    const file = owner + '/src/example.ts';
    write(file, source);
    assert.ok(
      checked().some((error) => error.includes(diagnostic)),
      source,
    );
    write(file, owner === 'apps/client' ? valid : 'export {};');
    assert.deepEqual(checked(), []);
  }

  write(
    'apps/client/src/nested/package.json',
    JSON.stringify({name: 'nested'}),
  );
  write('apps/client/src/nested/private.ts', 'export {};');
  write('apps/client/src/inner.ts', "import './nested/private.js';");
  assert.match(
    checked().join('\n'),
    /relative target must be tracked within its package/,
  );
  rmSync(path.join(root, 'apps/client/src/nested'), {recursive: true});
  write('apps/client/src/inner.ts', 'export {};');
  assert.deepEqual(checked(), []);
  const jsFile = 'apps/client/src/jsdoc.js';
  for (const directive of [
    '/** @import {Provider} from "@jarvis/providers" */',
    '/** @typedef {import("@jarvis/providers").Provider} P */',
  ]) {
    write(jsFile, directive + '\nexport {};');
    assert.match(checked().join('\n'), /forbidden dependency direction/);
    write(jsFile, 'export {};');
    assert.deepEqual(checked(), []);
  }

  write('.gitignore', 'dist/\n');
  write('apps/client/dist/generated.js', "import 'node:fs';");
  write(jsFile, "import '../dist/generated.js';");
  assert.match(
    checked().join('\n'),
    /relative target must be tracked within its package/,
  );
  write(jsFile, "import './index.ts';");
  assert.deepEqual(checked(), []);
  write(
    jsFile,
    "import 'https://example.invalid/code?token=sample-redaction';",
  );
  const diagnostic = checked().join('\n');
  assert.match(diagnostic, /indirect import/);
  assert.doesNotMatch(diagnostic, /sample-redaction/);
  write(jsFile, 'export {};');
  assert.deepEqual(checked(), []);

  write('apps/client/src/types.d.ts', 'export interface Job {}');
  write('apps/client/src/view.ts', "import type {Job} from './types.js';");
  assert.deepEqual(checked(), []);
  const reactManifest = 'apps/client/node_modules/react/package.json';
  write(reactManifest, JSON.stringify({name: 'other'}));
  write('apps/client/src/example.tsx', 'export const view = <main />;');
  assert.match(checked().join('\n'), /installed external package/);
  write(reactManifest, JSON.stringify({name: 'react'}));
  write(
    'apps/client/package.json',
    JSON.stringify({
      ...clientManifest,
      dependencies: {'@jarvis/contracts': 'workspace:*'},
    }),
  );
  assert.match(
    checked().join('\n'),
    /external import must be a declared dependency/,
  );
  write('apps/client/package.json', JSON.stringify(clientManifest));
  assert.deepEqual(checked(), []);
  write(
    'apps/client/src/example.tsx',
    '/** @jsxImportSource other */\nexport const view = <main />;',
  );
  assert.match(checked().join('\n'), /JSX import source overrides/);
  write('apps/client/src/example.tsx', 'export const view = <main />;');
  write('packages/contracts/schema.vitest.ts', "import {test} from 'vitest';");
  assert.deepEqual(checked(), []);

  write('apps/client/package.json', JSON.stringify({name: '@jarvis/client'}));
  assert.match(
    checked().join('\n'),
    /workspace import must be a declared installed dependency/,
  );
  write('apps/client/package.json', JSON.stringify(clientManifest));
  assert.deepEqual(checked(), []);
  installLink('apps/client/src', 'contracts', 'packages/providers');
  assert.match(checked().join('\n'), /forbidden dependency direction/);
  rmSync(path.join(root, 'apps/client/src/node_modules'), {recursive: true});
  assert.deepEqual(checked(), []);
});
