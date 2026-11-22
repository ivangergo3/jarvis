import {execFileSync} from 'node:child_process';
import {lstatSync, readFileSync, realpathSync} from 'node:fs';
import path from 'node:path';
import ts from 'typescript';

import {layers, workspaceMembers} from './package-graph.mjs';
import {ownedSource} from './source-paths.mjs';
import {preservesWorkspaceStrictness} from './strict-options.mjs';

// These change where a module spelling resolves or introduce an implicit module.
const redirects = [
  'baseUrl',
  'paths',
  'rootDirs',
  'moduleSuffixes',
  'customConditions',
  'jsxImportSource',
  'jsxFactory',
  'jsxFragmentFactory',
  'reactNamespace',
  'typeRoots',
];

function tracked(root, absolute, files) {
  return (
    files.has(path.relative(root, absolute)) &&
    lstatSync(absolute, {throwIfNoEntry: false})?.isFile() &&
    realpathSync(absolute) === absolute
  );
}

// A typed workspace member advertises one ordinary typecheck task. Its
// tsconfig lists every owned TS source as an input, including standalone files.
export function checkCompilerProfiles(root, owner, files) {
  if (owner === '.') return [];
  const folder = path.join(root, owner);
  const sources = [...files].filter(
    (name) => name.startsWith(owner + '/') && /\.[cm]?tsx?$/.test(name),
  );
  const relative = owner + '/tsconfig.json';
  const config = path.join(root, relative);
  const manifest = JSON.parse(
    readFileSync(path.join(folder, 'package.json'), 'utf8'),
  );
  const script = manifest.scripts?.typecheck ?? '';
  if (!sources.length && !script) return [];
  const errors = [];
  if (
    !/^tsc -p tsconfig\.json(?: --noEmit)?(?: --tsBuildInfoFile [\w./-]+)?$/.test(
      script,
    )
  )
    errors.push(owner + ': typecheck must invoke the package tsconfig.json');
  if (!tracked(root, config, files))
    return [...errors, relative + ': missing tracked compiler profile'];
  const invalid = () =>
    errors.push(relative + ': invalid or untracked compiler profile');
  const parsed = ts.getParsedCommandLineOfConfigFile(
    config,
    {},
    {
      ...ts.sys,
      onUnRecoverableConfigFileDiagnostic: invalid,
      readFile(file) {
        if (!tracked(root, file, files)) return undefined;
        return readFileSync(file, 'utf8');
      },
    },
  );
  if (!parsed || parsed.errors.length) {
    invalid();
    return errors;
  }
  const inputs = new Set(parsed.fileNames);
  // Electron's declarations bring Node globals into the entire compiler
  // project. Keep that profile exclusive to the two reviewed entry points.
  if (
    owner === 'apps/desktop' &&
    [...inputs].some(
      (file) =>
        !['src/main.mts', 'src/preload.cts'].includes(
          path.relative(folder, file),
        ),
    )
  )
    errors.push(
      relative +
        ': desktop compiler globals are restricted to main and preload',
    );

  for (const name of sources) {
    if (!inputs.has(path.join(root, name)))
      errors.push(name + ': missing from package typecheck inputs');
  }
  if ([...inputs].some((file) => !ownedSource(root, folder, file, files)))
    errors.push(
      relative + ': compiler input must be tracked within the package',
    );
  const options = parsed.options;
  const layer = layers.get(owner);
  const ambientType =
    layer === 'client' ? 'vite/client' : layer === 'pure' ? undefined : 'node';
  if (
    !Array.isArray(options.types) ||
    options.types.some((name) => {
      if (name !== ambientType) return true;
      const directive = ts.resolveTypeReferenceDirective(
        name,
        config,
        options,
        ts.sys,
      ).resolvedTypeReferenceDirective;
      return (
        directive?.packageId?.name !==
        (name === 'node' ? '@types/node' : 'vite')
      );
    })
  )
    errors.push(relative + ': ambient types must match the package runtime');
  if (options.libReplacement)
    errors.push(relative + ': use the pinned compiler libraries');
  if (
    !options.lib?.length ||
    options.lib.some(
      (lib) =>
        !/^lib\.(?:es[\w.]*|decorators(?:\.legacy)?)\.d\.ts$/.test(lib) &&
        !(
          layer === 'client' &&
          /^lib\.dom(?:\.(?:asynciterable|iterable))?\.d\.ts$/.test(lib)
        ),
    )
  )
    errors.push(
      relative + ': standard libraries must match the package runtime',
    );
  if (!preservesWorkspaceStrictness(options))
    errors.push(relative + ': preserve the workspace strict defaults');
  if (
    redirects.some((key) => options[key] !== undefined) ||
    options.preserveSymlinks ||
    !ts.getResolvePackageJsonExports(options) ||
    !ts.getResolvePackageJsonImports(options)
  )
    errors.push(
      relative + ': compiler module redirects need a reviewed boundary policy',
    );
  return errors;
}

if (import.meta.main) {
  const root = realpathSync('.');
  const files = new Set(
    execFileSync('git', ['ls-files', '-z', '--cached'], {encoding: 'utf8'})
      .split('\0')
      .filter(Boolean),
  );
  const errors = workspaceMembers(root).flatMap((member) =>
    checkCompilerProfiles(root, path.relative(root, member.path) || '.', files),
  );
  for (const error of errors) console.error(error);
  if (errors.length) process.exitCode = 1;
}
