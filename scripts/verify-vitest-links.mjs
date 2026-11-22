import {execFileSync} from 'node:child_process';
import {realpathSync} from 'node:fs';
import path from 'node:path';

// Run before installing packages so only tracked Git links need inspection.
const root = realpathSync('.');
const index = execFileSync('git', ['ls-files', '--stage', '-z'], {
  encoding: 'utf8',
});
for (const entry of index.split('\0')) {
  if (!entry.startsWith('120000 ')) continue;
  const name = entry.slice(entry.indexOf('\t') + 1);
  const relative = path.relative(root, realpathSync(name));
  if (
    relative === '..' ||
    relative.startsWith('..' + path.sep) ||
    path.isAbsolute(relative)
  ) {
    throw new Error(
      'Tracked symbolic link leaves the verified checkout: ' + name,
    );
  }
}
