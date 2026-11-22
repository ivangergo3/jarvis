#!/bin/bash
# Run against a disposable copy with a caller-supplied Zod installation.
set -euo pipefail
suite=$(cd "$(dirname "$0")" && pwd)
zod=$(cd "${1:?Pass the path to an installed zod@4.6.7 package}" && pwd)
node --input-type=commonjs -e '
  if (process.versions.node !== "24.19.0" || require(process.argv[1]).version !== "4.6.7") {
    throw new Error("Expected Node 24.19.0 and Zod 4.6.7");
  }
' "$zod/package.json"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
cp -R "$suite/case/." "$scratch/"
cp "$suite/probes.mjs" "$suite/renderer-probe.mjs" "$scratch/"
cd "$scratch"
mkdir -p node_modules/@example
ln -s ../../packages/contracts node_modules/@example/contracts
ln -s "$zod" node_modules/zod

for app in client server; do
  cp "$suite/result/apps/$app/src/"*.test.ts "apps/$app/src/"
done

# Require the observed failure count as well as the exit code. A broken
# dependency or unusable test runner must not be mistaken for the expected red.
red() {
  local count=$1
  shift
  if node --test --test-reporter=tap "$@" > red.tap; then
    echo "Expected $count failing cases" >&2
    exit 1
  fi
  grep -Fx "# fail $count" red.tap
}
red 12 apps/*/src/*.test.ts
red 2 probes.mjs
for app in client server; do
  cp "$suite/result/apps/$app/src/"*.ts "apps/$app/src/"
done
node --test --test-reporter=tap apps/*/src/*.test.ts probes.mjs

node renderer-probe.mjs
cp packages/contracts/src/index.ts original.ts
echo "export {basename as displayTitle} from 'node:path';" >> packages/contracts/src/index.ts
if node renderer-probe.mjs > renderer.log 2>&1; then
  echo 'The renderer loaded a Node-only public export' >&2
  exit 1
fi
grep -F 'Error: Renderer cannot load node:path from the public contract' renderer.log
mv original.ts packages/contracts/src/index.ts
node renderer-probe.mjs
