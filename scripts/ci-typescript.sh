#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
evidence=${1:?Expected a new evidence directory}
case "$evidence" in /*) ;; *) echo 'Use an absolute evidence path.' >&2; exit 1 ;; esac
umask 077
mkdir "$evidence"
head=$(git rev-parse HEAD)
test "$head" = "${GITHUB_SHA:?Expected the CI checkout revision}"
printf '%s\n' "$head" > "$evidence/source-revision.txt"
test "$(node -p 'process.versions.node')" = "$(cat .nvmrc)"
test "pnpm@$(pnpm --version)" = "$(node -p 'require("./package.json").packageManager')"
test -z "$(git status --porcelain --untracked-files=all)"
bash scripts/check-typescript.sh
swift run --jobs 2 quality-gate hosted-vitest "$head" "$evidence/vitest"
