import {spawnSync} from 'node:child_process';
import {
  constants,
  lstatSync,
  mkdirSync,
  openSync,
  rmSync,
  statSync,
} from 'node:fs';
import {setTimeout as delay} from 'node:timers/promises';

const task = process.argv[2];
if (
  process.argv.length !== 3 ||
  !['build', 'fixture', 'typecheck'].includes(task)
) {
  throw new Error('Expected build, fixture or typecheck');
}
if (!['darwin', 'linux'].includes(process.platform)) {
  throw new Error(
    'Workspace commands currently support macOS and Linux with flock.',
  );
}

mkdirSync('.build', {recursive: true});
// Darwin <sys/fcntl.h>: O_EXLOCK takes the BSD file lock atomically at open.
// Node does not export this platform flag. Linux locks the inherited descriptor below.
const exclusiveOpen = process.platform === 'darwin' ? 0x20 : 0;
const lockFlags = constants.O_CREAT | constants.O_RDWR | exclusiveOpen;
const lock = openSync('.build/typescript-workspace.lock', lockFlags, 0o600);
const stdio = [lock, 'inherit', 'inherit'];

function run(command, args) {
  const result = spawnSync(command, args, {stdio});
  if (result.error) throw result.error;
  return result.status ?? 1;
}

if (process.platform === 'linux') {
  let status;
  // Nonblocking attempts leave no waiting child behind on cancellation.
  while ((status = run('flock', ['-n', '0'])) === 1) await delay(150);
  if (status !== 0) process.exit(status);
}

process.env.TURBO_TELEMETRY_DISABLED = '1';
if (task === 'typecheck') {
  const status = run('turbo', ['run', 'typecheck', '--cache=local:rw']);
  if (status !== 0) process.exit(status);
  const {checkSourceTypes} =
    await import('./typescript/check-source-types.mjs');
  const errors = checkSourceTypes();
  for (const error of errors) console.error(error);
  process.exit(errors.length ? 1 : 0);
}

// Turbo overlays cached files. Remove only the fixture's previous generated tree.
const library = 'fixtures/workspace-library';
if (
  lstatSync('fixtures').isSymbolicLink() ||
  lstatSync(library).isSymbolicLink()
) {
  throw new Error('Expected local fixture directories');
}
const dist = `${library}/dist`;
rmSync(dist, {recursive: true, force: true});
const filter = task === 'fixture' ? ['--filter=@jarvis/workspace-fixture'] : [];
const status = run('turbo', ['run', 'build', ...filter, '--cache=local:rw']);
if (status !== 0) process.exit(status);
for (const entry of ['index.js', 'index.d.ts']) {
  if (!statSync(`${dist}/${entry}`, {throwIfNoEntry: false})?.isFile()) {
    throw new Error(`TypeScript did not emit the public ${entry}.`);
  }
}
if (task === 'fixture')
  process.exit(run(process.execPath, ['fixtures/verify-workspace.mjs']));
