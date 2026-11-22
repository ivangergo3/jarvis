import {execFileSync} from 'node:child_process';
import {lstatSync, realpathSync} from 'node:fs';
import path from 'node:path';

// These eight files are data for the independent TypeScript skills evaluation.
const exerciseSources = new Set(
  [
    'case/apps/client/src/draft.ts',
    'case/apps/client/src/view.ts',
    'case/apps/server/src/submit.ts',
    'case/packages/contracts/src/index.ts',
    'result/apps/client/src/view.test.ts',
    'result/apps/client/src/view.ts',
    'result/apps/server/src/submit.test.ts',
    'result/apps/server/src/submit.ts',
  ].map((file) => 'evaluations/typescript-skills-113/' + file),
);

// Use git's source inventory so tracked files inside build directories still count.
export function sourceFiles() {
  const output = execFileSync(
    'git',
    ['ls-files', '-z', '--cached', '--others', '--exclude-standard'],
    {encoding: 'utf8'},
  );
  const root = realpathSync('.');
  return output.split('\0').filter((file) => {
    if (!/\.[cm]?[jt]sx?$/.test(file)) return false;
    if (exerciseSources.has(file)) return false;
    const entry = lstatSync(file, {throwIfNoEntry: false});
    if (!entry) return false;
    if (!entry.isFile() || realpathSync(file) !== path.join(root, file)) {
      throw new Error('Expected a regular workspace source file: ' + file);
    }
    return true;
  });
}
