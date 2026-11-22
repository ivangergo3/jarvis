import {readFile} from 'node:fs/promises';
import prettier from 'prettier';
import options from '../../prettier.config.mjs';
import {sourceFiles} from './source-files.mjs';

export function isFormatted(source, filepath) {
  return prettier.check(source, {...options, filepath});
}

if (import.meta.main) {
  const files = sourceFiles();
  if (!files.length) throw new Error('No workspace sources found');
  for (const file of files) {
    if (!(await isFormatted(await readFile(file, 'utf8'), file))) {
      console.error('Formatting differs: ' + file);
      process.exitCode = 1;
    }
  }
}
