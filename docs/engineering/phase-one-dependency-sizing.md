# Phase-one dependency sizing

This measured preflight covers the dependency-size criterion in [issue #108](https://github.com/ivangergo3/jarvis/issues/108). It records a resolution-only experiment for the desktop rewrite. A shipping PR still measures its complete change against current main.

## PR size preflight

Use complete committed pnpm lockfiles. Before installing any dependency increment, resolve its metadata in a disposable copy of the actual manifests and lockfile, with scripts disabled. Count both additions and deletions against main, including manifests, config, verification fixtures and documentation. Warn at 2,000 changed lines. Split before publishing if the total exceeds 2,500. If the smallest useful increment still cannot fit, bring the actual diff to the owner. Keep failed measurements.

Select Node 24.19.0, pnpm 10.7.1, TypeScript 6.0.3 and Turbo 2.11.13 for the initial workspace. Typed ESLint 8.73.0 declares a TypeScript peer range below 6.1. The other pins below reproduce a sizing experiment and require a support/security check when their ticket starts.

On November 21, 2026, start from an empty directory on macOS with a single package.json containing `{"name":"jarvis-current-tools-probe","private":true}`. Use the default public npm registry, peer auto-install enabled and pnpm lockfile format 9. With the pinned Node and pnpm, run `pnpm add --lockfile-only --ignore-scripts --save-exact` plus the arguments in each row, in order, in the same directory. Each row inherits all preceding manifests and the full preceding lockfile. Save a copy of each lockfile to compare using `git diff --no-index --numstat`. This replay used exact package versions and installed no packages, browsers or Electron runtime.

| Step | Arguments | Lockfile lines before → after | Added + deleted |
| ---: | --- | ---: | ---: |
| 1 | `-D typescript@6.0.3 turbo@2.11.13` | 0 → 88 | 88 + 0 |
| 2 | `-D eslint@10.15.0` | 88 → 699 | 611 + 0 |
| 3 | `-D typescript-eslint@8.73.0` | 699 → 930 | 231 + 0 |
| 4 | `-D eslint-plugin-react-hooks@7.1.1` | 930 → 1286 | 356 + 0 |
| 5 | `-D vite@8.3.8` | 1286 → 1735 | 449 + 0 |
| 6 | `-D vitest@5.1.1` | 1735 → 1903 | 168 + 0 |
| 7 | `-D prettier@3.10.1` | 1903 → 1913 | 10 + 0 |
| 8 | `zod@4.6.7` | 1913 → 1917 | 4 + 0 |
| 9 | `@nestjs/common@11.2.11 @nestjs/core@11.2.11 reflect-metadata@0.2.2 rxjs@7.8.2` | 1917 → 2098 | 183 + 2 |
| 10 | `@nestjs/platform-express@11.2.11` | 2098 → 2726 | 630 + 2 |
| 11 | `-D @playwright/test@1.65.1` | 2726 → 2754 | 28 + 0 |
| 12 | `-D electron@45.4.1` | 2754 → 2842 | 96 + 8 |
| 13 | `react@19.3.1 react-dom@19.3.1` | 2842 → 2869 | 27 + 0 |
| 14 | `@tanstack/react-router@1.170.46 @tanstack/react-query@5.108.2` | 2869 → 2981 | 112 + 0 |
| 15 | `-D @electron/packager@20.3.0` | 2981 → 3239 | 258 + 0 |

Final lockfile SHA-256: `cc79f680957130ed74957de0f38f0fd564688d718c6f9dc039b2a49e61762255`. Future registry snapshots can resolve different transitive versions. Rerun on the actual workspace and include all changed manifests, fixtures, source and tests in the candidate’s size check.

The measured lockfile increments can ship together when they support one outcome and the complete diff fits the current budget. Measure a combined lint bootstrap with its compiler, ESLint and Hooks checks before publishing. The 630-line HTTP adapter increment also merits its own working smoke test. Treat the table as a sequence for measuring dependency cost; it does not change issue dependencies or authorize installing unrelated packages early.
