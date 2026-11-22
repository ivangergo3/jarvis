import {execFileSync} from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import ts from 'typescript';

import {sourceFiles} from './source-files.mjs';

// Package tasks own their native compiler projects. Everything else must be
// checked by the root tool project, including new files that Git has not staged.
export function checkSourceTypes() {
  const root = process.cwd();
  const sources = new Set(sourceFiles().map((file) => path.resolve(file)));
  const files = new Set(
    execFileSync(
      'git',
      ['ls-files', '-z', '--cached', '--others', '--exclude-standard'],
      {encoding: 'utf8'},
    )
      .split('\0')
      .filter(Boolean)
      .map((file) => path.resolve(file)),
  );
  const members = JSON.parse(
    execFileSync('pnpm', ['--recursive', 'list', '--depth=-1', '--json'], {
      encoding: 'utf8',
    }),
  );
  const packages = members
    .filter(({path: dir}) => dir !== root)
    .map(({path: dir}) => {
      const manifest = path.join(dir, 'package.json');
      const typecheck =
        files.has(manifest) &&
        fs.realpathSync(manifest) === manifest &&
        JSON.parse(fs.readFileSync(manifest, 'utf8')).scripts?.typecheck;
      return {directory: dir + path.sep, typecheck};
    })
    .sort((left, right) => right.directory.length - left.directory.length);
  const standalone = new Set(
    [...sources].filter(
      (file) =>
        /\.[cm]?tsx?$/.test(file) &&
        !packages.find(({directory}) => file.startsWith(directory))?.typecheck,
    ),
  );
  const modules = path.join(root, 'node_modules');
  const installed =
    fs.existsSync(modules) && fs.realpathSync(modules) === modules;
  const stdlib = path.dirname(ts.getDefaultLibFilePath({}));
  function allowed(file) {
    if (!ts.sys.fileExists(file)) return false;
    const real = fs.realpathSync(file);
    if (/\.[cm]?tsx?$/.test(real) && files.has(real))
      return (
        standalone.has(real) ||
        (sources.has(real) && /\.d\.[cm]?ts$/.test(real))
      );
    if (files.has(real))
      return !/\.[cm]?[jt]sx?$/.test(real) || sources.has(real);
    return (
      (installed && real.startsWith(modules + path.sep)) ||
      (path.dirname(real) === stdlib &&
        /^lib\..*d\.ts$/.test(path.basename(real)))
    );
  }
  const system = {
    ...ts.sys,
    fileExists: allowed,
    readFile: (file) => (allowed(file) ? ts.sys.readFile(file) : undefined),
    // Tool roots are explicitly listed. Imports resolve by name and the base
    // config specifies types: []; there is no implicit directory discovery.
    readDirectory: () => [],
    getDirectories: () => [],
  };
  const config = path.join(root, 'tsconfig.json');
  const errors = [];
  const report = (diagnostic) =>
    errors.push(
      ts
        .formatDiagnostic(diagnostic, {
          getCurrentDirectory: () => root,
          getCanonicalFileName: (name) => name,
          getNewLine: () => '\n',
        })
        .trimEnd(),
    );
  const parsed = ts.getParsedCommandLineOfConfigFile(
    config,
    {},
    {...system, onUnRecoverableConfigFileDiagnostic: report},
  );
  if (!parsed) return errors;
  // TS18002 is expected when the explicit manifest is empty. The coverage
  // check below still rejects any standalone source omitted from that manifest.
  parsed.errors
    .filter((diagnostic) => diagnostic.code !== 18002)
    .forEach(report);
  if (
    !Array.isArray(parsed.raw.files) ||
    parsed.raw.include ||
    parsed.projectReferences?.length
  )
    errors.push(
      'List tool entry points in root tsconfig.json files; use a workspace package for a project reference build.',
    );
  const options = parsed.options;
  if (
    !options.noEmit ||
    options.noCheck ||
    options.skipLibCheck ||
    options.skipDefaultLibCheck ||
    options.allowJs ||
    !options.exactOptionalPropertyTypes ||
    !options.noUncheckedIndexedAccess ||
    [
      'alwaysStrict',
      'noImplicitAny',
      'noImplicitThis',
      'strictBindCallApply',
      'strictBuiltinIteratorReturn',
      'strictFunctionTypes',
      'strictNullChecks',
      'strictPropertyInitialization',
      'useUnknownInCatchVariables',
    ].some((key) => !ts.getStrictOptionValue(options, key))
  )
    errors.push('Keep the root tool project strictly typed with noEmit.');
  if (parsed.fileNames.some((file) => !standalone.has(file)))
    errors.push('Root tool entries must be owned standalone TypeScript files.');
  const program = ts.createProgram(
    parsed.fileNames,
    options,
    ts.createIncrementalCompilerHost(options, system),
  );
  const diagnostics = ts.getPreEmitDiagnostics(program);
  diagnostics.forEach(report);
  if (diagnostics.some(({code}) => [2307, 2688, 6053, 7016].includes(code)))
    errors.push(
      'Tools that depend on workspace package implementation sources or generated declarations need a workspace package with a native typecheck task.',
    );
  const covered = new Set(
    program.getSourceFiles().map((file) => file.fileName),
  );
  for (const file of standalone) {
    if (!covered.has(file))
      errors.push(
        path.relative(root, file) +
          ': include this standalone source in root tsconfig.json',
      );
  }
  return errors;
}
