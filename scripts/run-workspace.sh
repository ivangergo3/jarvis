#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
    build|fixture|typecheck) ;;
    *) echo 'Expected build, fixture or typecheck' >&2; exit 2 ;;
esac
[[ $# == 1 ]] || { echo 'Expected one workspace task' >&2; exit 2; }

# Inherit the locked descriptor through the build and import, including on interruption.
mkdir -p .build
exec 9<>.build/typescript-workspace.lock
case "$(uname -s)" in
    Darwin) /usr/bin/lockf 9 ;;
    Linux) flock 9 ;;
    *) echo 'The local workspace commands currently support macOS and Linux with flock.' >&2; exit 2 ;;
esac
# Turbo's Node launcher forwards standard streams to its native process.
# These three noninteractive tasks need no input, so its stdin can also hold the lock.
exec 0<&9

export TURBO_TELEMETRY_DISABLED=1
if [[ $1 == typecheck ]]; then exec turbo run typecheck --cache=local:rw; fi

# Turbo overlays cached files. Clear only this fixture's generated output before either path.
[[ ! -L fixtures && ! -L fixtures/workspace-library ]] || { echo 'Expected local fixture directories' >&2; exit 1; }
dist=fixtures/workspace-library/dist
rm -rf -- "$dist"
if [[ $1 == fixture ]]; then
    turbo run build --filter=@jarvis/workspace-fixture --cache=local:rw
else
    turbo run build --cache=local:rw
fi
for entry in index.js index.d.ts; do
    [[ -f "$dist/$entry" ]] || { echo "TypeScript did not emit the public $entry." >&2; exit 1; }
done
if [[ $1 == fixture ]]; then exec node fixtures/verify-workspace.mjs; fi
