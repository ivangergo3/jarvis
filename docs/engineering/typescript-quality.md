# TypeScript workspace quality

After a frozen pnpm install, run `pnpm check:packages` to verify the workspace package graph. The check reads pnpm’s resolved direct dependencies from the frozen lockfile and compares its importers with the discovered workspace. It verifies that classified packages are present and that local links respect the agreed client, server and pure package boundaries. It includes development dependencies and rejects cycles, including cycles through the workspace root.

For example, a desktop dependency on `packages/providers` is rejected even if it is declared as a development dependency. Use normal workspace links for local packages. Copied directory snapshots are rejected. An installed registry dependency with the same name as a workspace package is a separate node.

The local push gate and required CI integrations belong to [#111](https://github.com/ivangergo3/jarvis/issues/111) and [#112](https://github.com/ivangergo3/jarvis/issues/112).

## Compiler and typed lint

Run `pnpm typecheck` and `pnpm lint`. The compiler enforces strict null
checking, implicit-any checks, exact optional properties and checked indexed
access. ESLint requires strict equality and `const` where possible, and
rejects `var`, boxed primitives, dynamic evaluation and array constructors.
The TypeScript project service loads each source file's actual compiler project.
Typed rules reject explicit and propagated `any`, unhandled promises (including
`void`), unsafe member access/calls and non-null assertions. Type-only imports
communicate intent. Inline ESLint overrides and TypeScript suppression comments
cannot silence these checks.

The TypeScript skills evaluation owns its intentional input and expected-output examples in `evaluations/typescript-skills-113/{case,result}`. Its separate checks verify rejected and repaired programs. The evaluation runner itself stays in the normal JavaScript inventory.

## Formatting, React and review

Run `pnpm check:style` for all four checks and their negative fixtures.
`pnpm format:check` checks the owned JS, TS and JSX/TSX source inventory
without writing files. Prettier sets two spaces, semicolons, single quotes
and an 80-column target. Long strings and comments can exceed the target.
The React ESLint rules verify Hook call order and effect dependency arrays,
including in plain TypeScript Hook modules.

The [Google TypeScript guide](https://google.github.io/styleguide/tsguide.html)
is the style baseline. React component names use PascalCase, custom Hooks use
React's `use` prefix and JSX attribute strings use JSX quoting. Nest decorators
belong at framework boundaries when those packages arrive. NodeNext relative
ESM imports use the emitted file extension. Prettier owns layout, including
where its wrapping differs from guide examples. The selected typed ESLint,
Hooks and formatter configuration avoids importing the full Google `gts`
toolchain and its additional defaults.

Review still covers readable names, meaningful public APIs, error recovery,
runtime validation, privilege propagation and whether a type assertion is
justified. Passing static checks alone cannot establish those properties.


Standalone TypeScript tools belong in the root `tsconfig.json` files list.
`pnpm typecheck` runs the existing Turbo package tasks, then checks the root
tool project with the pinned compiler and `noEmit`. It reports owned TS files
outside a package typecheck task when the tool project does not cover them.
The tool project reads Git-owned files and installed dependencies. Move tools
that need project references or generated workspace declarations into a pnpm
package with its own native typecheck task.

## Package boundaries

`pnpm check:boundaries` runs the frozen package graph, the package TypeScript profile check and `pnpm check:imports`. The import check walks staged and committed JavaScript, TypeScript and JSX in the workspace. An import, re-export, type reference, dynamic import or direct require that crosses a package boundary must use the bare name of a declared, installed workspace dependency. Package-local relative imports stay with their owner. The import check uses the pinned ESLint parser’s scope information to limit references to the global CommonJS loaders to direct `require(...)` and `module.require(...)` calls. CommonJS files can use `module.exports` for their exports. Renderer and pure packages can use only the external entries approved for their layer. The negative fixtures restore valid imports after exercising server, process, credential, private and undeclared dependency violations.

Each typed workspace member runs `tsc -p tsconfig.json` through its `typecheck` script. Its tracked compiler profile includes all of its tracked TypeScript sources, preserves the explicit workspace strict defaults, and limits ambient types to its runtime. The source policy assumes the standard package resolver. Changes that redirect module names through compiler options require review.

The source check verifies the import spelling and dependency direction. Use `pnpm build` and `pnpm fixture` to verify Node resolves the published entry and the original consumer loads the compiled workspace library. Application bundling, HTML entry behavior and public asset serving belong to the [renderer integration](https://github.com/ivangergo3/jarvis/issues/119).
