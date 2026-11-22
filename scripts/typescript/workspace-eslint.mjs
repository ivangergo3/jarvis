import path from 'node:path';
import {ESLint} from 'eslint';

export function workspaceESLint() {
  return new ESLint({
    overrideConfigFile: path.resolve('eslint.config.mjs'),
    globInputPaths: false,
  });
}
