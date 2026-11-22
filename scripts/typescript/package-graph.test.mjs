import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import {checkPackageGraph} from './package-graph.mjs';

const {packageManager} = JSON.parse(
  readFileSync(new URL('../../package.json', import.meta.url), 'utf8'),
);

test('the installed pnpm graph detects package direction, cycles and discovery drift', (t) => {
  const root = realpathSync(
    mkdtempSync(path.join(os.tmpdir(), 'jarvis-package-graph-')),
  );
  t.after(() => rmSync(root, {recursive: true, force: true}));
  function manifest(dir, name, fields = {}) {
    mkdirSync(path.join(root, dir), {recursive: true});
    writeFileSync(
      path.join(root, dir, 'package.json'),
      JSON.stringify({name, version: '1.0.0', private: true, packageManager, ...fields}),
    );
  }
  function resolve() {
    execFileSync(
      'pnpm',
      ['install', '--offline', '--ignore-scripts', '--no-frozen-lockfile'],
      {
        cwd: root,
        env: {...process.env, CI: 'true'},
        stdio: 'pipe',
      },
    );
    return checkPackageGraph(root);
  }
  writeFileSync(path.join(root, '.npmrc'), 'store-dir=.fixture-store\n');
  const workspace = "packages:\n  - 'apps/*'\n  - 'packages/*'\n";
  writeFileSync(path.join(root, 'pnpm-workspace.yaml'), workspace);
  manifest('.', 'fixture-root', {
    devDependencies: {'@fixture/domain': 'workspace:*'},
  });
  manifest('apps/desktop', '@fixture/desktop');
  manifest('packages/domain', '@fixture/domain');
  manifest('packages/providers', '@fixture/providers');
  assert.deepEqual(resolve(), []);

  manifest('apps/desktop', '@fixture/desktop', {
    devDependencies: {'@fixture/providers': 'workspace:*'},
  });
  assert.match(
    resolve().join('\n'),
    /apps\/desktop: forbidden workspace dependency on packages\/providers/,
  );
  manifest('apps/desktop', '@fixture/desktop');
  assert.deepEqual(resolve(), []);

  manifest('packages/domain', '@fixture/domain', {
    devDependencies: {'fixture-root': 'workspace:*'},
  });
  assert.match(resolve().join('\n'), /Workspace cycle/);
  manifest('packages/domain', '@fixture/domain');
  assert.deepEqual(resolve(), []);

  writeFileSync(
    path.join(root, 'pnpm-workspace.yaml'),
    workspace + "  - '!packages/providers'\n",
  );
  assert.match(
    resolve().join('\n'),
    /packages\/providers: classified package missing/,
  );
  writeFileSync(path.join(root, 'pnpm-workspace.yaml'), workspace);
  assert.deepEqual(resolve(), []);

  manifest('apps/desktop', '@fixture/desktop', {
    devDependencies: {
      '@fixture/providers': String.raw`file:..\..\packages\providers`,
    },
    peerDependencies: {'@fixture/providers': '^1.0.0'},
  });
  assert.match(
    resolve().join('\n'),
    /forbidden workspace dependency|Unsupported directory snapshot/,
  );
  manifest('apps/desktop', '@fixture/desktop');
  assert.deepEqual(resolve(), []);

  // The installed package name matches the local provider, but this copy is
  // resolved from an offline package tarball, the same store layout as npm.
  manifest('tarball-source', '@fixture/providers', {version: '1.0.0'});
  execFileSync('pnpm', ['pack', '--pack-destination', root], {
    cwd: path.join(root, 'tarball-source'),
    stdio: 'pipe',
  });
  manifest('apps/desktop', '@fixture/desktop', {
    dependencies: {
      '@fixture/providers': 'file:../../fixture-providers-1.0.0.tgz',
    },
  });
  assert.deepEqual(resolve(), []);

  const lock = readFileSync(path.join(root, 'pnpm-lock.yaml'), 'utf8');
  assert.ok(lock.includes('link:packages/domain'));
});
