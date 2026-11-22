import {spawn, spawnSync} from 'node:child_process';
import {once} from 'node:events';
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {expect, test} from 'vitest';

const runner = fileURLToPath(
  new URL('./run-synthetic-worker.mjs', import.meta.url),
);
const cases = [
  [
    'a missing packaged executable fails and removes its private profile',
    'missing',
    1,
  ],
  [
    'a packaged app exiting with code 17 cannot publish a passing receipt',
    'failed',
    1,
  ],
  [
    'a packaged app exiting zero before its window opens fails qualification',
    'early',
    1,
  ],
  [
    'a stopped preview owner resumes on cancellation and cleans its app and helper',
    'hangup',
    129,
  ],
  [
    'a stalled preview times out without leaving its app or helper running',
    'timeout',
    124,
  ],
  [
    'a crashed packaged app fails and its surviving helper is stopped',
    'crash',
    1,
  ],
  [
    'losing the owner while a helper survives retains scratch and fails qualification',
    'ownerCrash',
    1,
  ],
];
for (const [name, scenario, expected] of cases) {
  test(
    name,
    async () => {
      const temp = mkdtempSync(path.join(tmpdir(), 'jarvis-smoke-test-'));
      const app = path.join(temp, 'Test.app');
      const binaries = path.join(app, 'Contents/MacOS');
      const marker = path.join(temp, 'started');
      const evidence = path.join(temp, 'evidence');
      mkdirSync(binaries, {recursive: true});
      let controller;
      try {
        let source;
        if (scenario === 'failed' || scenario === 'early')
          source = 'exit ' + (scenario === 'failed' ? '17' : '0');
        else if (scenario !== 'missing')
          source =
            'sleep 8 &\nhelper=$!\nprintf "%s %s %s\\n" "$$" "$PPID" "$helper" > "$JARVIS_TEST_MARKER.tmp"\nmv "$JARVIS_TEST_MARKER.tmp" "$JARVIS_TEST_MARKER"\nwait "$helper"';
        if (source)
          writeFileSync(
            path.join(binaries, 'Jarvis Preview'),
            '#!/bin/sh\n' + source + '\n',
            {mode: 0o700},
          );
        controller = spawn(
          process.execPath,
          [runner, app, scenario === 'timeout' ? '1900' : '12000'],
          {
            stdio: ['ignore', 'pipe', 'pipe'],
            env: {
              ...process.env,
              TMPDIR: temp,
              JARVIS_SMOKE_EVIDENCE_DIR: evidence,
              JARVIS_TEST_MARKER: marker,
            },
          },
        );
        let output = '';
        for (const stream of [controller.stdout, controller.stderr])
          stream.on('data', (chunk) => {
            output += chunk.toString();
          });
        const closed = once(controller, 'close');
        let appPid, ownerPid, helperPid;
        const field = (pid, column) =>
          spawnSync('/bin/ps', ['-p', String(pid), '-o', column + '='], {
            encoding: 'utf8',
          }).stdout.trim();
        if (!['missing', 'early', 'failed'].includes(scenario)) {
          await expect
            .poll(() => existsSync(marker), {timeout: 5000})
            .toBe(true);
          [appPid, ownerPid, helperPid] = readFileSync(marker, 'utf8')
            .trim()
            .split(' ')
            .map(Number);
          expect(Number(field(ownerPid, 'ppid'))).toBe(controller.pid);
          expect(Number(field(ownerPid, 'pgid'))).toBe(ownerPid);
          expect(Number(field(appPid, 'pgid'))).toBe(ownerPid);
          expect(Number(field(helperPid, 'pgid'))).toBe(ownerPid);
          if (scenario === 'hangup') {
            process.kill(ownerPid, 'SIGSTOP');
            controller.kill('SIGHUP');
          }
          if (scenario === 'crash') process.kill(appPid, 'SIGKILL');
          if (scenario === 'ownerCrash') {
            process.kill(ownerPid, 'SIGKILL');
            process.kill(appPid, 'SIGKILL');
          }
        }
        expect(await closed, output).toEqual([expected, null]);
        expect(existsSync(path.join(evidence, 'smoke.json'))).toBe(false);
        const retained = readdirSync(temp).filter((name) =>
          name.startsWith('jarvis-preview-smoke-run-'),
        );
        if (scenario === 'ownerCrash') {
          expect(output).toContain('Uncertain cleanup; retained');
          expect(retained).toHaveLength(1);
          await expect
            .poll(() => field(helperPid, 'stat'), {timeout: 8000})
            .toMatch(/^(?:$|Z)/);
        } else {
          expect(retained).toHaveLength(0);
          if (appPid)
            for (const pid of [appPid, ownerPid, helperPid])
              expect(field(pid, 'stat')).toMatch(/^(?:$|Z)/);
        }
        if (scenario === 'missing') expect(output).toContain('ENOENT');
        if (scenario === 'failed') expect(output).toContain('"code":17');
      } finally {
        if (
          controller &&
          controller.exitCode === null &&
          controller.signalCode === null
        )
          controller.kill('SIGTERM');
        rmSync(temp, {recursive: true, force: true});
      }
    },
    20000,
  );
}
