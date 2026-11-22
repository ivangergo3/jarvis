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
export function sourceFiles(directory = process.cwd()) {
  const root = realpathSync(directory);
  const output = execFileSync(
    'git',
    ['ls-files', '-z', '--cached', '--others', '--exclude-standard'],
    {cwd: root, encoding: 'utf8'},
  );
  return output.split('\0').filter((file) => {
    if (!/\.[cm]?[jt]sx?$/.test(file)) return false;
    if (exerciseSources.has(file)) return false;
    const absolute = path.join(root, file);
    const entry = lstatSync(absolute, {throwIfNoEntry: false});
    if (!entry) return false;
    if (!entry.isFile() || realpathSync(absolute) !== absolute) {
      throw new Error('Expected a regular workspace source file: ' + file);
    }
    return true;
  });
}
