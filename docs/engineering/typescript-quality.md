# TypeScript workspace quality

After a frozen pnpm install, run `pnpm check:packages` to verify the workspace package graph. The check reads pnpm’s installed direct dependencies and the packages it discovers. It verifies that classified packages are present and that local links respect the agreed client, server and pure package boundaries. It includes development dependencies and rejects cycles, including cycles through the workspace root.

For example, a desktop dependency on `packages/providers` is rejected even if it is declared as a development dependency. Supported declarations are registry versions/ranges/tags, workspace links, and regular relative package tarballs for offline fixtures. Use the workspace protocol for local directories so pnpm keeps their package identity. An installed registry dependency with the same name as a workspace package is a separate node.

This command verifies the package graph. Source imports, public entry points, lint and formatting are separate increments of [#110](https://github.com/ivangergo3/jarvis/issues/110). The local push gate and required CI integrations belong to [#111](https://github.com/ivangergo3/jarvis/issues/111) and [#112](https://github.com/ivangergo3/jarvis/issues/112).
