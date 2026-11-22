import {execFileSync} from 'node:child_process';
import {lstatSync, readFileSync, realpathSync} from 'node:fs';
import {createRequire, findPackageJSON, isBuiltin} from 'node:module';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import ts from 'typescript';

import {allows, layers} from './package-graph.mjs';
import {isTestFile, ownedSource} from './source-paths.mjs';
import {sourceFiles} from './source-files.mjs';

const externals = {
  pure: new Set(['zod']),
  client: new Set([
    'zod',
    'react',
    'react/jsx-runtime',
    'react/jsx-dev-runtime',
    'react-dom',
    'react-dom/client',
    '@tanstack/react-router',
    '@tanstack/react-query',
  ]),
};

function packageRoot(file) {
  return /^(?:apps|packages)\//.test(file) ||
    file.startsWith('fixtures/workspace-library/')
    ? file.split('/').slice(0, 2).join('/')
    : '.';
}

function dependencyName(specifier) {
  const parts = specifier.split('/');
  return parts.slice(0, specifier.startsWith('@') ? 2 : 1).join('/');
}

// The static boundary is the bare package name. Package builds and the root
// executable fixture exercise what the declared public entry actually loads.
function declaresRoot(exports) {
  if (typeof exports === 'string') return exports.startsWith('./');
  if (!exports || typeof exports !== 'object') return false;
  if (Object.keys(exports).some((key) => key.startsWith('.'))) {
    return (
      Object.keys(exports).every((key) => key.startsWith('.')) &&
      Object.hasOwn(exports, '.') &&
      declaresRoot(exports['.'])
    );
  }
  return Object.entries(exports).some(
    ([condition, value]) => !condition.startsWith('.') && declaresRoot(value),
  );
}

function moduleReference(node) {
  if (
    ts.isImportDeclaration(node) ||
    ts.isExportDeclaration(node) ||
    ts.isJSDocImportTag(node)
  ) {
    return node.moduleSpecifier;
  }
  if (ts.isImportTypeNode(node)) return node.argument.literal;
  if (ts.isExternalModuleReference(node)) return node.expression;
  if (ts.isCallExpression(node)) {
    const callee = ts.skipOuterExpressions(node.expression);
    if (
      callee.kind === ts.SyntaxKind.ImportKeyword ||
      (ts.isIdentifier(callee) && callee.text === 'require')
    )
      return node.arguments[0] ?? node;
    if (
      ts.isPropertyAccessExpression(callee) ||
      ts.isElementAccessExpression(callee)
    ) {
      const receiver = ts.skipOuterExpressions(callee.expression);
      if (!ts.isIdentifier(receiver) || receiver.text !== 'module') return;
      if (ts.isPropertyAccessExpression(callee)) {
        if (callee.name.text !== 'require') return;
      } else {
        const key = ts.skipOuterExpressions(callee.argumentExpression);
        if (!ts.isStringLiteralLike(key) || key.text !== 'require') return;
      }
      return node.arguments[0] ?? node;
    }
  }
}

export function checkBoundaries(root) {
  root = realpathSync(root);
  const files = execFileSync('git', ['ls-files', '-z', '--cached'], {
    cwd: root,
    encoding: 'utf8',
  })
    .split('\0')
    .filter(Boolean);
  const inventory = new Set(files);
  const errors = [];
  const manifests = new Map();
  for (const owner of layers.keys()) {
    const file = owner === '.' ? 'package.json' : owner + '/package.json';
    const filename = path.join(root, file);
    if (
      inventory.has(file) &&
      lstatSync(filename, {throwIfNoEntry: false})?.isFile() &&
      realpathSync(filename) === filename
    )
      manifests.set(
        owner,
        JSON.parse(readFileSync(path.join(root, file), 'utf8')),
      );
  }

  const workspaceNames = new Set(
    [...manifests.values()].map((manifest) => manifest.name),
  );

  function check(specifier, file, location) {
    const owner = packageRoot(file);
    const layer = layers.get(owner);
    const fail = (reason) => errors.push(location + ': ' + reason);
    if (specifier.startsWith('.')) {
      const target = path.posix.join(path.posix.dirname(file), specifier);
      if (
        /[%?#\\]/.test(specifier) ||
        target.startsWith('../') ||
        packageRoot(target) !== owner ||
        target.split('/').includes('node_modules')
      ) {
        fail('use the public workspace package');
        return;
      }
      if (isTestFile(target) && !isTestFile(file))
        fail('production import of test code');
      // The skills evaluation copies these two probe templates into case/
      // before executing them. Other relative imports use their source path.
      const probe =
        /^evaluations\/typescript-skills-113\/(?:renderer-probe|probes)\.mjs$/.test(
          file,
        ) && /^\.\/apps\/(?:client|server)\/src\//.test(specifier);
      const importer = probe
        ? path.join(root, path.dirname(file), 'case', path.basename(file))
        : path.join(root, file);
      const resolved = ts.resolveModuleName(
        specifier,
        importer,
        {
          moduleResolution: ts.ModuleResolutionKind.NodeNext,
          allowJs: true,
        },
        ts.sys,
      ).resolvedModule;
      const targets = new Set(resolved ? [resolved.resolvedFileName] : []);
      try {
        targets.add(createRequire(importer).resolve(specifier));
      } catch (error) {
        if (error.code !== 'MODULE_NOT_FOUND')
          fail('invalid relative module reference');
      }
      const folder = probe
        ? path.join(
            root,
            path.dirname(file),
            'case',
            ...specifier.slice(2).split('/').slice(0, 2),
          )
        : path.join(root, owner);
      if (
        !targets.size ||
        [...targets].some(
          (name) =>
            (!/\.(?:[cm]?[jt]sx?|json)$/.test(name) &&
              !(layer === 'client' && name.endsWith('.css'))) ||
            !ownedSource(root, folder, name, inventory) ||
            (isTestFile(path.relative(root, name)) && !isTestFile(file)),
        )
      )
        fail('relative target must be tracked within its package');
      return;
    }
    if (
      /[%\\]/.test(specifier) ||
      specifier.split('/').some((part) => part === '.' || part === '..')
    ) {
      fail('noncanonical package import');
      return;
    }
    if (
      isTestFile(file) &&
      ['node:test', 'node:assert/strict'].includes(specifier)
    )
      return;
    if (isBuiltin(specifier)) {
      if (externals[layer]) fail('unapproved external dependency');
      return;
    }
    const name = dependencyName(specifier);
    const manifest = manifests.get(owner);
    const declared = [
      manifest.dependencies,
      manifest.devDependencies,
      manifest.peerDependencies,
      manifest.optionalDependencies,
    ].some((group) => Object.hasOwn(group ?? {}, name));
    let installedManifest;
    try {
      installedManifest = realpathSync(
        findPackageJSON(name, pathToFileURL(path.join(root, file))),
      );
    } catch {
      // Built-ins and unresolved dependencies have no package manifest.
    }
    const target =
      installedManifest &&
      (path
        .relative(root, path.dirname(installedManifest))
        .split(path.sep)
        .join('/') ||
        '.');
    if (target && manifests.has(target)) {
      if (specifier !== name) fail('use the public package root');
      if (!declaresRoot(manifests.get(target).exports))
        fail('workspace dependency does not declare a public package root');
      if (target === owner && name === manifest.name && manifest.exports)
        return;
      if (!allows(owner, target)) fail('forbidden dependency direction');
      const direct = path.join(
        root,
        owner,
        'node_modules',
        name,
        'package.json',
      );
      if (
        !lstatSync(direct, {throwIfNoEntry: false}) ||
        realpathSync(direct) !== installedManifest ||
        !declared
      )
        fail('workspace import must be a declared installed dependency');
      return;
    }
    if (
      (!installedManifest && workspaceNames.has(name)) ||
      name.startsWith('@jarvis/') ||
      specifier.startsWith('#') ||
      path.isAbsolute(specifier) ||
      (/^[a-z][a-z+.-]*:/i.test(specifier) && !specifier.startsWith('node:'))
    ) {
      fail('unknown workspace or indirect import');
      return;
    }
    if (externals[layer]) {
      if (
        !externals[layer].has(specifier) &&
        !(isTestFile(file) && specifier === 'vitest')
      ) {
        fail('unapproved external dependency');
        return;
      }
      // Vitest is the centrally pinned workspace runner used by package tests.
      const workspaceTestRunner =
        isTestFile(file) &&
        specifier === 'vitest' &&
        Object.hasOwn(manifests.get('.')?.devDependencies ?? {}, 'vitest');
      if (!declared && !workspaceTestRunner)
        fail('external import must be a declared dependency');
      if (
        !installedManifest ||
        JSON.parse(readFileSync(installedManifest, 'utf8')).name !== name
      )
        fail('installed external package must match its allowed import name');
    }
  }

  for (const file of sourceFiles(root).filter((file) => inventory.has(file))) {
    if (!manifests.has(packageRoot(file))) {
      errors.push(file + ': source has no workspace manifest');
      continue;
    }
    const absolute = path.join(root, file);
    if (
      packageRoot(file) !== '.' &&
      !ownedSource(
        root,
        path.join(root, packageRoot(file)),
        absolute,
        inventory,
      )
    ) {
      errors.push(file + ': expected a regular tracked source');
      continue;
    }
    const source = ts.createSourceFile(
      file,
      readFileSync(path.join(root, file), 'utf8'),
      ts.ScriptTarget.Latest,
    );
    if (packageRoot(file) !== '.' && source.pragmas.has('jsximportsource')) {
      errors.push(
        file + ': JSX import source overrides need an explicit source policy',
      );
    }
    if (
      source.referencedFiles.length ||
      source.typeReferenceDirectives.length ||
      source.libReferenceDirectives.length ||
      source.hasNoDefaultLib
    ) {
      errors.push(
        file + ': use module imports instead of triple-slash references',
      );
    }
    let checkedJsx = false;
    function visit(node) {
      if (
        !checkedJsx &&
        (ts.isJsxElement(node) ||
          ts.isJsxSelfClosingElement(node) ||
          ts.isJsxFragment(node))
      ) {
        checkedJsx = true;
        check('react/jsx-runtime', file, file);
      }
      const reference = moduleReference(node);
      if (reference) {
        const ref = ts.skipOuterExpressions(reference);
        const location =
          file +
          ':' +
          (source.getLineAndCharacterOfPosition(ref.getStart(source)).line + 1);
        if (ts.isStringLiteralLike(ref)) check(ref.text, file, location);
        else errors.push(location + ': module specifier must be a literal');
      }
      node.jsDoc?.forEach(visit);
      ts.forEachChild(node, visit);
    }
    visit(source);
  }
  return errors;
}

if (import.meta.main) {
  const errors = checkBoundaries(process.cwd());
  for (const message of errors) console.error(message);
  if (errors.length) process.exitCode = 1;
}
