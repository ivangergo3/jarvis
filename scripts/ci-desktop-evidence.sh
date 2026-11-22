#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
evidence=${1:?Expected the validated Vitest evidence directory}
case "$evidence" in /*) ;; *) echo 'Use an absolute evidence path.' >&2; exit 1 ;; esac
umask 077
head=${GITHUB_SHA:?Expected the CI checkout revision}
test "$(git rev-parse HEAD)" = "$head"
test -s "$evidence/vitest/qualified.json"
pnpm desktop:package | tee "$evidence/desktop-build.log"
app=$(tail -n 1 "$evidence/desktop-build.log")
identifier=$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$app/Contents/Info.plist")
test "$identifier" = dev.greg.jarvis.preview
/usr/bin/codesign --verify --deep --strict "$app"
test "$(git rev-parse HEAD)" = "$head"
test -z "$(git status --porcelain --untracked-files=all)"
# Publish a single allowlisted success artifact. Raw reporter files can contain assertion values.
jq -e --arg revision "$head" --arg bundle "$identifier" --arg arch "$(uname -m)" '
  select(.process.revision == $revision and (.passedCaseSHA256 | length > 0))
  | . + {desktop: {bundle: $bundle, architecture: $arch, signature: "verified"}}
' "$evidence/vitest/qualified.json" > "$evidence/hosted-summary.tmp"
mv "$evidence/hosted-summary.tmp" "$evidence/hosted-summary.json"
