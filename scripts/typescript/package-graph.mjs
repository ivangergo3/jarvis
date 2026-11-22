import {execFileSync} from 'node:child_process';
import {existsSync, readFileSync, realpathSync, statSync} from 'node:fs';
import path from 'node:path';

const layers = new Map(
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

function allows(from, to) {
  if (from === '.') return true;
  if (to === '.' || to.startsWith('apps/') || layers.get(to) === 'tool')
    return false;
  return layers.get(to) === 'pure' || layers.get(from) === layers.get(to);
}

// pnpm distinguishes installed workspace links from registry packages of the
// same name. Do not infer a local edge from a dependency's name or version.
export function packageGraphErrors(root, projects) {
  const errors = [];
  const members = new Map(
    projects.map((project) => [
      path.resolve(project.path),
      path.relative(root, project.path).split(path.sep).join('/') || '.',
    ]),
  );
  const edges = new Map();
  for (const name of layers.keys()) {
    const location = path.resolve(root, name);
    if (
      existsSync(path.join(location, 'package.json')) &&
      !members.has(location)
    ) {
      errors.push(name + ': classified package missing from pnpm discovery');
    }
  }
  for (const project of projects) {
    const owner = members.get(path.resolve(project.path));
    if (!layers.has(owner)) {
      errors.push(owner + ': unclassified pnpm workspace package');
      continue;
    }
    const manifestPath = path.join(project.path, 'package.json');
    if (realpathSync(manifestPath) !== manifestPath) {
      errors.push(
        owner + ': linked workspace manifest requires explicit review',
      );
      continue;
    }
    const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
    const local = new Set();
    edges.set(owner, local);
    const required = {...manifest.dependencies, ...manifest.devDependencies};
    // pnpm supports the same name in multiple sections. Check every declared
    // specifier before deduplicating local edges in the set.
    const declarations = [
      manifest.dependencies,
      manifest.devDependencies,
      manifest.peerDependencies,
      manifest.optionalDependencies,
    ];
    for (const [name, spec] of declarations.flatMap((group) =>
      Object.entries(group ?? {}),
    )) {
      // Jarvis uses workspace: links for local packages. The only allowed
      // file: input is a regular relative package tarball, used by offline
      // fixtures. Treat other forms as unsupported rather than emulate pnpm's
      // tilde, platform-path and directory normalization.
      const archive = /^file:((?:\.\.?\/)*(?:[\w.-]+\/)*[\w.-]+\.tgz)$/.exec(
        spec,
      );
      const registry = /^(?:[\d^~<>=*][\w.^~<>=+* |\-]*|[a-zA-Z][\w.-]*)$/.test(
        spec,
      );
      if (
        !spec.startsWith('workspace:') &&
        !registry &&
        !(
          archive &&
          statSync(path.resolve(project.path, archive[1]), {
            throwIfNoEntry: false,
          })?.isFile()
        )
      ) {
        errors.push(
          owner +
            ': unsupported dependency source; use the workspace protocol for local directories',
        );
        continue;
      }
      // pnpm 10 can omit local-only edges from "list --depth=0". Its installed
      // package directory still resolves to the actual target for every name.
      const link = path.join(project.path, 'node_modules', name);
      if (!existsSync(link)) {
        if (
          Object.hasOwn(required, name) &&
          !Object.hasOwn(manifest.optionalDependencies ?? {}, name)
        ) {
          errors.push(
            owner + ': missing required dependency; run a frozen pnpm install',
          );
        }
        continue;
      }
      const target = members.get(realpathSync(link));
      if (target === undefined) {
        if (spec.startsWith('workspace:'))
          errors.push(owner + ': unresolved required workspace link');
        continue;
      }
      local.add(target);
      if (!allows(owner, target))
        errors.push(owner + ': forbidden workspace dependency on ' + target);
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

export function checkPackageGraph(directory) {
  const root = realpathSync(directory);
  const output = execFileSync(
    'pnpm',
    ['--recursive', 'list', '--depth=-1', '--json'],
    {cwd: root, encoding: 'utf8'},
  );
  return packageGraphErrors(root, JSON.parse(output));
}

if (import.meta.main) {
  const errors = checkPackageGraph(process.cwd());
  for (const error of errors) console.error(error);
  if (errors.length) process.exitCode = 1;
}
