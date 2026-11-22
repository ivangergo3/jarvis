import {spawnSync} from 'node:child_process';
import {
  mkdirSync, mkdtempSync, readdirSync, renameSync, rmSync,
} from 'node:fs';
import {dirname, join, relative} from 'node:path';
import {fileURLToPath} from 'node:url';

const compiler = fileURLToPath(import.meta.resolve('typescript/bin/tsc'));
const output = 'dist';
// Match dist's depth so relative TypeScript source-map paths survive publication.
const staging = mkdtempSync('.emit-');

function filesUnder(directory) {
  return readdirSync(directory, {recursive: true, withFileTypes: true})
    .filter(entry => entry.isFile())
    .map(entry => relative(directory, join(entry.parentPath, entry.name)));
}

try {
  const result = spawnSync(process.execPath, [
    compiler, '-p', 'tsconfig.json', '--outDir', staging, '--declarationDir', staging,
    '--incremental', 'false',
  ], {stdio: 'inherit'});
  if (result.error) throw result.error;
  if (result.status !== 0) {
    process.exitCode = result.status ?? 1;
  } else {
    const emitted = new Set(filesUnder(staging));
    for (const entry of ['index.js', 'index.d.ts']) {
      if (!emitted.has(entry)) throw new Error(`TypeScript did not emit the public ${entry}.`);
    }
    // Replace complete files so a concurrent fixture can still import its entry.
    for (const name of emitted) {
      const target = join(output, name);
      mkdirSync(dirname(target), {recursive: true});
      renameSync(join(staging, name), target);
    }
    for (const name of filesUnder(output)) {
      if (!emitted.has(name)) rmSync(join(output, name), {force: true});
    }
  }
} finally {
  rmSync(staging, {force: true, recursive: true});
}
