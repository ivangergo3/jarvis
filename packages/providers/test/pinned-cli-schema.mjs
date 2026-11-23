import {execFile} from 'node:child_process';
import {mkdir, mkdtemp, readFile, rm} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {promisify} from 'node:util';

// Pure schema generation by the lockfile-pinned devDependency. The CLI sees
// only an empty temporary profile, no account variables or existing workspace.
export async function readPinnedCliSchemas(names) {
  const directory = await mkdtemp(join(tmpdir(), 'jarvis-schema-fixture-'));
  try {
    const profile = join(directory, 'profile');
    const output = join(directory, 'schema');
    await mkdir(profile, {mode: 0o700});
    const entry = createRequire(import.meta.url).resolve(
      '@openai/codex/bin/codex.js',
    );
    await promisify(execFile)(
      process.execPath,
      [
        entry,
        'app-server',
        'generate-json-schema',
        '--experimental',
        '--out',
        output,
      ],
      {
        cwd: directory,
        env: {HOME: profile, CODEX_HOME: profile, PATH: '/usr/bin:/bin'},
        timeout: 15_000,
      },
    );
    return await Promise.all(
      names.map((name) => readFile(join(output, 'v2', name + '.json'))),
    );
  } finally {
    await rm(directory, {recursive: true, force: true});
  }
}
