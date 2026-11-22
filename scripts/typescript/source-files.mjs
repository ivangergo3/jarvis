import {execFileSync} from 'node:child_process';
import {lstatSync, realpathSync} from 'node:fs';
import path from 'node:path';

// Use git's source inventory so tracked files inside build directories still count.
export function sourceFiles() {
  const output = execFileSync(
    'git',
    ['ls-files', '-z', '--cached', '--others', '--exclude-standard'],
    {encoding: 'utf8'},
  );
  const root = realpathSync('.');
  return output.split('\0').filter((file) => {
    if (!/\.[cm]?jsx?$/.test(file)) return false;
    const entry = lstatSync(file, {throwIfNoEntry: false});
    if (!entry) return false;
    if (!entry.isFile() || realpathSync(file) !== path.join(root, file)) {
      throw new Error('Expected a regular workspace source file: ' + file);
    }
    return true;
  });
}
