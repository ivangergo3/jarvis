#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
evidence=${1:?Expected a new evidence directory}
case "$evidence" in /*) ;; *) echo 'Use an absolute evidence path.' >&2; exit 1 ;; esac
umask 077
mkdir "$evidence"
head=$(git rev-parse HEAD)
test "$head" = "${GITHUB_SHA:?Expected the CI checkout revision}"
test "$(node -p 'process.versions.node')" = "$(cat .nvmrc)"
test "pnpm@$(pnpm --version)" = "$(node -p 'require("./package.json").packageManager')"
test -z "$(git status --porcelain --untracked-files=all)"
bash scripts/check-typescript.sh
swift build --jobs 2 --product quality-gate
binary="$(swift build --show-bin-path)/quality-gate"
# Make the signal-aware native gate the Actions step entry process during Vitest.
exec "$binary" hosted-vitest "$head" "$evidence/vitest"
