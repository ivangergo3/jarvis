import {execFileSync} from 'node:child_process';
import {existsSync} from 'node:fs';

// Use git's source inventory so tracked files inside build directories still count.
export function sourceFiles() {
  const output = execFileSync(
    'git',
    [
      'ls-files', '-z', '--cached', '--others', '--exclude-standard', '--',
      'apps', 'packages', 'fixtures/workspace-library', 'fixtures/verify-workspace.mjs',
      'scripts', 'eslint.config.mjs',
    ],
    {encoding: 'utf8'},
  );
  return output.split('\0').filter(file => /\.[cm]?[jt]sx?$/.test(file) && existsSync(file));
}
