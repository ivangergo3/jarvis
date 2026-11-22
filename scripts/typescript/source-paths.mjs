import {existsSync, lstatSync, realpathSync} from 'node:fs';
import path from 'node:path';

export function isTestFile(file) {
  return /(?:\/(?:__tests__|tests?)\/|\.(?:test|spec|vitest)\.(?:d\.)?[cm]?[jt]sx?$)/.test(
    file,
  );
}

export function ownedSource(root, owner, absolute, files) {
  if (
    !absolute.startsWith(owner + path.sep) ||
    !files.has(path.relative(root, absolute)) ||
    !lstatSync(absolute, {throwIfNoEntry: false})?.isFile() ||
    realpathSync(absolute) !== absolute
  )
    return false;
  for (
    let parent = path.dirname(absolute);
    parent !== owner;
    parent = path.dirname(parent)
  ) {
    if (existsSync(path.join(parent, 'package.json'))) return false;
  }
  return true;
}
