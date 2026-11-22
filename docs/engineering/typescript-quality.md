# TypeScript workspace quality

After a frozen pnpm install, run `pnpm check:packages` to verify the workspace package graph. The check reads pnpm’s resolved direct dependencies from the frozen lockfile and compares its importers with the discovered workspace. It verifies that classified packages are present and that local links respect the agreed client, server and pure package boundaries. It includes development dependencies and rejects cycles, including cycles through the workspace root.

For example, a desktop dependency on `packages/providers` is rejected even if it is declared as a development dependency. Use normal workspace links for local packages. Copied directory snapshots are rejected. An installed registry dependency with the same name as a workspace package is a separate node.

This command verifies the package graph. Source imports, public entry points, lint and formatting are separate increments of [#110](https://github.com/ivangergo3/jarvis/issues/110). The local push gate and required CI integrations belong to [#111](https://github.com/ivangergo3/jarvis/issues/111) and [#112](https://github.com/ivangergo3/jarvis/issues/112).

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
