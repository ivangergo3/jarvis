import {execFileSync, spawnSync} from 'node:child_process';
import {
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  realpathSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {expect, test} from 'vitest';

const root = fileURLToPath(new URL('../../', import.meta.url));
const compiler = path.join(root, 'node_modules/typescript/bin/tsc');

test('public contracts import in browser and Node consumers with branded destinations', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'jarvis-contract-import-'));
  try {
    const library = path.join(root, 'packages/contracts');
    const installed = path.join(directory, 'node_modules/@jarvis/contracts');
    mkdirSync(installed, {recursive: true});
    copyFileSync(
      path.join(library, 'package.json'),
      path.join(installed, 'package.json'),
    );
    symlinkSync(
      path.join(library, 'node_modules'),
      path.join(installed, 'node_modules'),
      'dir',
    );
    // Compile into a private consumer installation, independent of the workspace build lock.
    execFileSync(
      process.execPath,
      [compiler, '-p', library, '--outDir', path.join(installed, 'dist')],
      {timeout: 15000},
    );
    writeFileSync(
      path.join(directory, 'consumer.mts'),
      [
        "import {Command, ProjectId, Receipt, RunTarget, type EventBody} from '@jarvis/contracts';",
        "type CancelObservation = Extract<Receipt, {operation:'run.cancel'}>['observation'];",
        '// @ts-expect-error queued is not an accepted cancellation outcome',
        "const invalidCancel: CancelObservation = {state:'queued'};",
        "export const completedCancel: CancelObservation = {state:'completed'};",
        "export function messageReference(value: Extract<EventBody, {kind: 'run.output'}>) {",
        '  return value.payload.content;',
        '}',
        'export function owns(projectId: ProjectId, value: unknown): boolean {',
        '  return RunTarget.parse(value).projectId === projectId;',
        '}',
        'export function submittedSession(value: unknown) {',
        '  const command = Command.parse(value);',
        "  return command.operation === 'run.submit' ? command.target.sessionId : undefined;",
        '}',
      ].join('\n'),
    );
    // Prevent ambient packages on the machine from participating in either check.
    const config = {
      compilerOptions: {
        strict: true,
        target: 'ES2023',
        types: [],
        noEmit: true,
      },
      files: ['consumer.mts'],
    };
    writeFileSync(
      path.join(directory, 'tsconfig.json'),
      JSON.stringify(config),
    );
    for (const profile of [
      ['NodeNext', 'NodeNext', 'ES2023'],
      ['ESNext', 'Bundler', 'ES2023,DOM'],
    ]) {
      const [module, resolution, lib] = profile;
      execFileSync(
        process.execPath,
        [
          compiler,
          '-p',
          'tsconfig.json',
          '--module',
          module,
          '--moduleResolution',
          resolution,
          '--lib',
          lib,
        ],
        {cwd: directory, stdio: 'pipe', timeout: 10000},
      );
    }
    // Verify the public runtime graph loads only the built package and Zod.
    writeFileSync(
      path.join(directory, 'runtime.mjs'),
      [
        "import {registerHooks} from 'node:module';",
        "const entry = import.meta.resolve('@jarvis/contracts');",
        "const root = new URL('./', entry).href;",
        'const zodBase = ' +
          JSON.stringify(
            pathToFileURL(
              realpathSync(
                path.join(root, 'packages/contracts/node_modules/zod'),
              ) + path.sep,
            ).href,
          ) +
          ';',
        'let sawZod = false;',
        "registerHooks({resolve(s,c,next) {const r=next(s,c); if(r.url.startsWith(zodBase)) sawZod=true; else if(!r.url.startsWith(root)) throw Error('unexpected dependency: '+s); return r;}});",
        "const {RunTarget} = await import('@jarvis/contracts');",
        "if(!sawZod || RunTarget.safeParse(null).success) throw Error('invalid public runtime');",
      ].join('\n'),
    );
    execFileSync(process.execPath, ['runtime.mjs'], {
      cwd: directory,
      stdio: 'pipe',
      timeout: 5000,
    });
    writeFileSync(
      path.join(directory, 'consumer.mts'),
      "import type {ProjectId, RunId} from '@jarvis/contracts';\ndeclare const run: RunId; export const project: ProjectId = run;",
    );
    const invalid = spawnSync(
      process.execPath,
      [
        compiler,
        '-p',
        'tsconfig.json',
        '--module',
        'NodeNext',
        '--moduleResolution',
        'NodeNext',
        '--lib',
        'ES2023',
      ],
      {cwd: directory, encoding: 'utf8', timeout: 10000},
    );
    expect(invalid.status).toBe(2);
    expect(invalid.stdout).toContain('TS2322');
    expect(invalid.stdout).toContain('RunId');
  } finally {
    rmSync(directory, {recursive: true, force: true});
  }
}, 45000);
