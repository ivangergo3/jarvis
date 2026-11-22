import {execFileSync} from 'node:child_process';
import {existsSync, readFileSync, realpathSync} from 'node:fs';
import path from 'node:path';
import {parse} from 'yaml';

export const layers = new Map(
  Object.entries({
    '.': 'tool',
    'apps/client': 'client',
    'apps/desktop': 'client',
    'apps/mobile': 'client',
    'apps/server': 'server',
    'apps/worker': 'server',
    'packages/contracts': 'pure',
    'packages/domain': 'pure',
    'fixtures/workspace-library': 'pure',
    'packages/api-client': 'client',
    'packages/features': 'client',
    'packages/platform': 'client',
    'packages/ui': 'client',
    'packages/execution': 'server',
    'packages/persistence': 'server',
    'packages/providers': 'server',
    'packages/skills': 'server',
    'packages/quality': 'tool',
  }),
);

export function allows(from, to) {
  if (from === '.') return true;
  if (to === '.' || to.startsWith('apps/') || layers.get(to) === 'tool')
    return false;
  return layers.get(to) === 'pure' || layers.get(from) === layers.get(to);
}

export function packageGraphErrors(root, projects, lock) {
  if (lock?.lockfileVersion !== '9.0' || !lock.importers)
    return ['Expected a frozen pnpm v9 lockfile'];
  const errors = [];
  const members = new Set(
    projects.map(
      (p) => path.relative(root, p.path).split(path.sep).join('/') || '.',
    ),
  );
  const edges = new Map();
  for (const name of layers.keys()) {
    if (
      existsSync(path.join(root, name, 'package.json')) &&
      !members.has(name)
    ) {
      errors.push(name + ': classified package missing from pnpm discovery');
    }
  }
  // pnpm normally represents local members as linker edges. Copied/injected
  // directory snapshots have different identity and need their own policy.
  for (const pkg of Object.values(lock.packages ?? {})) {
    if (pkg.resolution?.directory || pkg.resolution?.type === 'directory') {
      errors.push(
        'Unsupported directory snapshot; use workspace links for local packages',
      );
    }
  }
  for (const owner of members) {
    if (!layers.has(owner))
      errors.push(owner + ': unclassified pnpm workspace package');
    if (!Object.hasOwn(lock.importers, owner))
      errors.push(owner + ': missing from frozen lockfile');
  }
  for (const [owner, importer] of Object.entries(lock.importers)) {
    if (!members.has(owner)) {
      errors.push(owner + ': frozen importer missing from pnpm discovery');
      continue;
    }
    const local = new Set();
    edges.set(owner, local);
    for (const group of [
      importer.dependencies,
      importer.devDependencies,
      importer.optionalDependencies,
    ]) {
      for (const {version} of Object.values(group ?? {})) {
        if (typeof version !== 'string')
          throw new Error('Expected a pnpm v9 importer version');
        // The pinned package manager resolves aliases, ranges, overrides and
        // OS path syntax before recording this portable relative link.
        if (!version.startsWith('link:')) continue;
        const target = path.posix.normalize(
          path.posix.join(owner, version.slice(5)),
        );
        if (!members.has(target))
          errors.push(owner + ': link target outside the discovered workspace');
        else {
          local.add(target);
          if (!allows(owner, target))
            errors.push(
              owner + ': forbidden workspace dependency on ' + target,
            );
        }
      }
    }
  }

  const visited = new Set();
  const active = new Set();
  function visit(owner, trail) {
    if (active.has(owner)) {
      errors.push(
        'Workspace cycle: ' +
          [...trail.slice(trail.indexOf(owner)), owner].join(' -> '),
      );
      return;
    }
    if (visited.has(owner)) return;
    visited.add(owner);
    active.add(owner);
    for (const target of edges.get(owner) ?? [])
      visit(target, [...trail, owner]);
    active.delete(owner);
  }
  for (const owner of edges.keys()) visit(owner, []);
  return errors;
}

export function workspaceMembers(root) {
  const output = execFileSync(
    'pnpm',
    ['--recursive', 'list', '--depth=-1', '--json'],
    {cwd: root, encoding: 'utf8'},
  );
  return JSON.parse(output);
}

export function checkPackageGraph(directory) {
  const root = realpathSync(directory);
  return packageGraphErrors(
    root,
    workspaceMembers(root),
    parse(readFileSync(path.join(root, 'pnpm-lock.yaml'), 'utf8')),
  );
}

if (import.meta.main) {
  const errors = checkPackageGraph(process.cwd());
  for (const error of errors) console.error(error);
  if (errors.length) process.exitCode = 1;
}
