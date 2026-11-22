import assert from 'node:assert/strict';
import {
  mkdirSync,
  mkdtempSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import {checkCompilerProfiles} from './compiler-profiles.mjs';

test('the effective project cannot redirect renderer imports or compile source from another package', (t) => {
  const root = realpathSync(
    mkdtempSync(path.join(os.tmpdir(), 'jarvis-ts-project-')),
  );
  t.after(() => rmSync(root, {recursive: true, force: true}));
  const files = new Set();
  function write(name, content) {
    files.add(name);
    const destination = path.join(root, name);
    mkdirSync(path.dirname(destination), {recursive: true});
    writeFileSync(
      destination,
      typeof content === 'string' ? content : JSON.stringify(content),
    );
  }
  const app = 'apps/client';
  write('package.json', {name: 'root'});
  const typecheck = 'tsc -p tsconfig.json';
  write(app + '/package.json', {name: 'renderer', scripts: {typecheck}});
  write(app + '/src/render.ts', 'export {};');
  write('packages/providers/package.json', {name: 'providers'});
  write('packages/providers/src/credentials.ts', 'export {};');
  const base = 'tsconfig.base.json';
  const profile = app + '/tsconfig.json';
  const defaults = {
    types: [],
    lib: ['es2023'],
    module: 'nodenext',
    moduleResolution: 'nodenext',
    strict: true,
    noUncheckedIndexedAccess: true,
    exactOptionalPropertyTypes: true,
  };
  const good = {extends: '../../' + base, files: ['src/render.ts']};
  write(base, {compilerOptions: defaults});
  write(profile, good);
  const check = (owner = app) => checkCompilerProfiles(root, owner, files);
  assert.deepEqual(check(), []);
  write(base, {
    compilerOptions: {
      ...defaults,
      types: ['../../packages/providers/src/credentials'],
    },
  });
  assert.match(check().join('\n'), /ambient types/);
  write('packages/domain/package.json', {
    name: 'domain',
    scripts: {typecheck: 'tsc -p tsconfig.json'},
  });
  write('packages/domain/model.ts', 'export {};');
  write('packages/domain/tsconfig.json', {
    extends: '../../' + base,
    files: ['model.ts'],
  });
  write(base, {compilerOptions: {...defaults, types: undefined}});
  assert.match(check('packages/domain').join('\n'), /ambient types/);
  write(base, {compilerOptions: {...defaults, lib: ['es2023', 'dom']}});
  assert.match(check('packages/domain').join('\n'), /standard libraries/);
  assert.deepEqual(check(), []);
  write(base, {compilerOptions: {...defaults, lib: ['es2023', 'scripthost']}});
  assert.match(check().join('\n'), /standard libraries/);
  write('packages/providers/package.json', {
    name: 'providers',
    scripts: {typecheck},
  });
  write('packages/providers/tsconfig.json', {
    extends: '../../' + base,
    include: ['src'],
  });
  write(base, {compilerOptions: {...defaults, lib: ['es2023', 'dom']}});
  assert.match(check('packages/providers').join('\n'), /standard libraries/);
  write(base, {compilerOptions: defaults});
  assert.deepEqual(check('packages/providers'), []);
  write(base, {compilerOptions: {...defaults, libReplacement: true}});
  assert.match(
    check('packages/domain').join('\n'),
    /pinned compiler libraries/,
  );
  assert.match(check().join('\n'), /pinned compiler libraries/);
  write('packages/ui/package.json', {name: 'ui', scripts: {typecheck}});
  write('packages/ui/src/index.js', 'export {};');
  write('packages/ui/tsconfig.json', {
    extends: '../../' + base,
    compilerOptions: {allowJs: true, checkJs: true, types: ['node']},
    include: ['src'],
  });
  assert.match(check('packages/ui').join('\n'), /ambient types/);
  write(base, {compilerOptions: {...defaults, types: ['vite/client']}});
  const viteManifest = app + '/node_modules/vite/package.json';
  write(app + '/node_modules/vite/client.d.ts', 'export {};');
  const vite = {
    name: 'vite',
    version: '1.0.0',
    exports: {'./client': './client.d.ts'},
  };
  write(viteManifest, {...vite, name: 'other-package'});
  assert.match(check().join('\n'), /ambient types/);
  write(viteManifest, vite);
  assert.deepEqual(check(), []);
  write(base, {compilerOptions: defaults});
  for (const override of [
    {module: 'commonjs', moduleResolution: 'node10', ignoreDeprecations: '6.0'},
    {paths: {zod: ['./packages/providers/src/credentials.ts']}},
    {jsx: 'react', reactNamespace: 'Privileged'},
    {
      moduleResolution: 'nodenext',
      module: 'nodenext',
      resolvePackageJsonExports: false,
    },
  ]) {
    write(base, {compilerOptions: {...defaults, ...override}});
    assert.match(check().join('\n'), /compiler module redirects/);
    write(base, {compilerOptions: defaults});
    assert.deepEqual(check(), []);
  }
  write(app + '/package.json', {
    name: 'renderer',
    scripts: {build: 'vite build'},
  });
  assert.match(check().join('\n'), /typecheck must invoke/);
  write(app + '/package.json', {name: 'renderer', scripts: {typecheck}});
  write(app + '/src/standalone.ts', 'export const count: number = 1;');
  write(app + '/tsconfig.other.json', {...good, files: ['src/standalone.ts']});
  assert.match(
    check().join('\n'),
    /standalone.ts: missing from package typecheck inputs/,
  );
  good.files.push('src/standalone.ts');
  write(profile, good);
  assert.deepEqual(check(), []);
  write(base, {compilerOptions: {...defaults, noImplicitAny: false}});
  assert.match(check().join('\n'), /strict defaults/);
  for (const override of [
    {skipLibCheck: true},
    {skipDefaultLibCheck: true},
    {allowJs: true, checkJs: false},
  ]) {
    write(base, {compilerOptions: {...defaults, ...override}});
    assert.match(check().join('\n'), /strict defaults/);
  }
  write(base, {compilerOptions: {...defaults, alwaysStrict: false}});
  assert.match(check().join('\n'), /strict defaults/);
  write(base, {compilerOptions: defaults});
  assert.deepEqual(check(), []);
  write(profile, {
    ...good,
    files: ['../../packages/providers/src/credentials.ts'],
  });
  assert.match(check().join('\n'), /within the package/);
  write(profile, good);
  assert.deepEqual(check(), []);
});
