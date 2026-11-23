import {fork, execFileSync} from 'node:child_process';
import {mkdir, mkdtemp, rm} from 'node:fs/promises';
import {renameSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {createInterface} from 'node:readline';
import {setTimeout as delay} from 'node:timers/promises';
import {fileURLToPath} from 'node:url';

async function confirmGroupExit(group) {
  if (!group) return;
  const until = performance.now() + 3000;
  for (;;) {
    const table = execFileSync('/bin/ps', ['-axo', 'pgid=,stat='], {
      encoding: 'utf8',
    });
    if (
      !table
        .trim()
        .split('\n')
        .some((line) => {
          const [pgid, status] = line.trim().split(/\s+/);
          return Number(pgid) === group && !status.includes('Z');
        })
    )
      return;
    if (performance.now() >= until)
      throw new Error('Preview helpers remain in group ' + group);
    await delay(75);
  }
}

export async function runPackagedSmoke(
  appPath,
  timeoutMs = 90_000,
  destination = process.env.JARVIS_SMOKE_EVIDENCE_DIR,
) {
  let owner;
  let closed;
  let checker;
  let checkerClosed;
  let closing = false;
  let scratch;
  let canceled;
  const until = performance.now() + timeoutMs;
  const interrupted = Promise.withResolvers();
  // Cancellation can arrive before the first fs call or the Promise.race.
  interrupted.promise.catch(() => {});
  function abort(reason) {
    if (canceled) return;
    canceled = reason;
    interrupted.reject(new Error(reason));
    stopOwner();
  }
  function stopOwner() {
    if (owner?.connected) owner.disconnect();
    if (owner && owner.exitCode === null && owner.signalCode === null)
      owner.kill('SIGCONT');
  }
  const signals = {SIGTERM: 143, SIGINT: 130, SIGHUP: 129};
  const listeners = Object.keys(signals).map((signal) => {
    const action = () => abort(signal);
    process.on(signal, action);
    return [signal, action];
  });
  const timer = setTimeout(() => abort('deadline'), timeoutMs);
  try {
    let evidence = destination;
    if (evidence) {
      if (!path.isAbsolute(evidence))
        throw new Error('Expected absolute evidence directory.');
      await mkdir(evidence, {mode: 0o700});
    } else {
      const parent = fileURLToPath(
        new URL('../../.build/desktop-smoke/', import.meta.url),
      );
      await mkdir(parent, {recursive: true});
      evidence = await mkdtemp(path.join(parent, 'run-'));
    }
    scratch = await mkdtemp(path.join(tmpdir(), 'jarvis-preview-smoke-run-'));
    let receipt;
    try {
      const profile = await mkdtemp(
        path.join(scratch, 'jarvis-preview-smoke-'),
      );
      if (canceled) throw new Error(canceled);
      owner = fork(
        fileURLToPath(new URL('./preview-owner.mjs', import.meta.url)),
        [path.join(appPath, 'Contents/MacOS/Jarvis Preview'), profile],
        {
          execArgv: [],
          detached: true,
          stdio: ['ignore', 'pipe', 'pipe', 'ipc'],
          env: {...process.env, TMPDIR: scratch},
        },
      );
      closed = new Promise((resolve) => {
        owner.once('exit', resolve);
        owner.once('error', resolve);
      });
      const finished = Promise.withResolvers();
      const ready = Promise.withResolvers();
      // Native child failure must fail the test even if UI checks have passed.
      owner.on('error', (error) => finished.reject(error));
      owner.on('message', (result) => {
        if (result?.code === 0 && result.signal === null) {
          finished.resolve();
          ready.reject(
            new Error('Packaged app exited before its window opened.'),
          );
        } else
          finished.reject(
            new Error('Packaged app failed: ' + JSON.stringify(result)),
          );
      });
      owner.on('disconnect', () =>
        finished.reject(
          new Error('Preview owner exited without a native result.'),
        ),
      );
      const state = {};
      function startChecks() {
        if (closing || canceled) throw new Error('Preview is stopping.');
        // The SDK only attaches. Keeping it in a direct child also lets us
        // cancel any in-flight Playwright assertion or hung renderer request.
        checker = fork(
          fileURLToPath(new URL('./check-shell.mjs', import.meta.url)),
          [profile, evidence],
          {
            execArgv: [],
            stdio: ['ignore', 'inherit', 'inherit', 'ipc'],
            env: {...process.env, TMPDIR: scratch},
          },
        );
        let result;
        checker.on('message', (message) => {
          result = message;
        });
        checkerClosed = new Promise((resolve, reject) => {
          checker.once('error', reject);
          checker.once('close', (code, signal) => {
            if (code === 0 && signal === null && result?.receipt)
              resolve(result.receipt);
            else
              reject(
                new Error(
                  result?.error ?? 'Packaged window checks did not finish.',
                ),
              );
          });
        });
        checker.send({start: state}, (error) => {
          if (error) finished.reject(error);
        });
        return checkerClosed;
      }
      const lines = (stream, action) =>
        createInterface({input: stream}).on('line', (line) => {
          try {
            action(line);
            if (state.endpoint && state.window) ready.resolve();
          } catch (error) {
            finished.reject(error);
          }
        });
      lines(owner.stderr, (line) => {
        const match =
          /^DevTools listening on (ws:\/\/127\.0\.0\.1:\d+\/devtools\/browser\/[a-f\d-]+)$/.exec(
            line,
          );
        if (match) state.endpoint = match[1];
      });
      lines(owner.stdout, (line) => {
        for (const [prefix, key] of [
          ['JARVIS_SMOKE_WINDOW ', 'window'],
          ['JARVIS_SMOKE_DENIED ', 'denied'],
          ['JARVIS_SMOKE_VISIBILITY ', 'visibility'],
        ]) {
          if (line.startsWith(prefix)) {
            state[key] = JSON.parse(line.slice(prefix.length));
            if (key !== 'window' && checker?.connected)
              checker.send({[key]: state[key]}, (error) => {
                if (error) finished.reject(error);
              });
          }
        }
      });
      owner.send('start');
      [receipt] = await Promise.race([
        Promise.all([ready.promise.then(startChecks), finished.promise]),
        interrupted.promise,
      ]);
    } finally {
      closing = true;
      if (checker && checker.exitCode === null && checker.signalCode === null)
        checker.kill('SIGKILL');
      stopOwner();
      if (closed) {
        const stop = setTimeout(() => owner.kill('SIGKILL'), 2000);
        try {
          await closed;
        } finally {
          clearTimeout(stop);
        }
        owner.stdout.destroy();
        owner.stderr.destroy();
      }
      if (checkerClosed) await checkerClosed.catch(() => {});
      try {
        await confirmGroupExit(owner?.pid);
      } catch (cause) {
        canceled = undefined;
        throw new Error(
          'Uncertain cleanup; retained ' + scratch + ': ' + cause.message,
        );
      }
      await rm(scratch, {recursive: true, force: true});
    }
    if (performance.now() >= until) abort('deadline');
    if (canceled) throw new Error(canceled);
    const pending = path.join(evidence, 'smoke.pending.json');
    writeFileSync(
      pending,
      JSON.stringify(
        {...receipt, nativeExitCode: 0, cleanupVerified: true},
        null,
        2,
      ) + '\n',
      {flag: 'wx'},
    );
    renameSync(pending, path.join(evidence, 'smoke.json'));
    console.log('Packaged fixture passed: ' + evidence);
    return 0;
  } catch (error) {
    console.error(error.message);
    return canceled === 'deadline' ? 124 : (signals[canceled] ?? 1);
  } finally {
    clearTimeout(timer);
    for (const [signal, action] of listeners) process.off(signal, action);
  }
}
