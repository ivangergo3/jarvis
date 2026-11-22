import path from 'node:path';
import {ESLint} from 'eslint';
import {sourceFiles} from './source-files.mjs';

const files = sourceFiles();
if (!files.length) throw new Error('No JavaScript workspace sources found');
const eslint = new ESLint({
  overrideConfigFile: path.resolve('eslint.config.mjs'),
  globInputPaths: false,
});
const results = await eslint.lintFiles(files);
const formatter = await eslint.loadFormatter('stylish');
const report = await formatter.format(results);
if (report) console.error(report);
if (results.some((result) => result.errorCount || result.warningCount)) {
  process.exitCode = 1;
}
