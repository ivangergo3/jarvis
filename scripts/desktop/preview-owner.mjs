import {execFileSync, spawn} from 'node:child_process';

// The fixture can terminate only the process group it leads while it is alive.
const group = execFileSync(
  '/bin/ps',
  ['-p', String(process.pid), '-o', 'pgid='],
  {
    encoding: 'utf8',
  },
).trim();
if (!process.send || Number(group) !== process.pid)
  throw new Error('Expected the isolated Jarvis Preview process group.');
function stopGroup() {
  process.kill(0, 'SIGKILL');
}
process.once('disconnect', stopGroup);
setTimeout(stopGroup, 100_000);
if (!process.connected) stopGroup();
process.once('message', (message) => {
  if (message !== 'start') stopGroup();
  const [executable, profile] = process.argv.slice(2);
  const app = spawn(
    executable,
    [
      '--remote-debugging-address=127.0.0.1',
      '--remote-debugging-port=0',
      '--jarvis-fixture-smoke=' + profile,
    ],
    {stdio: 'inherit'},
  );
  function finish(result) {
    if (process.connected) process.send(result, stopGroup);
    else stopGroup();
  }
  app.once('error', (error) => finish({error: error.message}));
  app.once('exit', (code, signal) => finish({code, signal}));
});
