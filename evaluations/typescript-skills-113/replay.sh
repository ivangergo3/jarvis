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

# Match every named outcome; TAP marks a skipped or TODO case on that same
# result line. Sorting allows parallel test files to finish in any order.
export LC_ALL=C
run_cases() {
  node --test --test-reporter=tap apps/*/src/*.test.ts probes.mjs > results.tap
}
check_inventory() {
  sed -nE 's/^(not ok|ok) [0-9]+ - /\1 /p' results.tap | sort > actual.txt
  diff -u expected.txt actual.txt
  grep -Fx '# cancelled 0' results.tap
  grep -Fx '# skipped 0' results.tap
  grep -Fx '# todo 0' results.tap
}
sort "$suite/expected-original.txt" > expected.txt
if run_cases; then
  echo 'The unrepaired cases unexpectedly passed' >&2
  exit 1
fi
check_inventory
grep -Fx '# fail 14' results.tap

for app in client server; do
  cp "$suite/result/apps/$app/src/"*.ts "apps/$app/src/"
done
sed 's/^not ok /ok /' "$suite/expected-original.txt" | sort > expected.txt
run_cases
check_inventory
grep -Fx '# pass 17' results.tap

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
