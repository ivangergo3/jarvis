#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Keep cache restoration, compilation and the consuming import in one critical section.
if [[ ${1:-} != --locked ]]; then
    [[ $# == 1 ]] || { echo 'Expected build, fixture or typecheck' >&2; exit 2; }
    mkdir -p .build
    lock=.build/typescript-workspace.lock
    case "$(uname -s)" in
        Darwin) exec /usr/bin/lockf -k "$lock" /bin/bash scripts/run-workspace.sh --locked "$1" ;;
        Linux) exec flock "$lock" /bin/bash scripts/run-workspace.sh --locked "$1" ;;
        *) echo 'The local workspace commands currently support macOS and Linux with flock.' >&2; exit 2 ;;
    esac
fi

export TURBO_TELEMETRY_DISABLED=1
case "${2:-}" in
    typecheck) exec turbo run typecheck --cache=local:rw ;;
    build|fixture) ;;
    *) echo 'Expected build, fixture or typecheck' >&2; exit 2 ;;
esac

# Turbo overlays cached files. Clear only this fixture's generated output before either path.
[[ ! -L fixtures && ! -L fixtures/workspace-library ]] || { echo 'Expected local fixture directories' >&2; exit 1; }
dist=fixtures/workspace-library/dist
rm -rf -- "$dist"
if [[ $2 == fixture ]]; then
    turbo run build --filter=@jarvis/workspace-fixture --cache=local:rw
else
    turbo run build --cache=local:rw
fi
for entry in index.js index.d.ts; do
    [[ -f "$dist/$entry" ]] || { echo "TypeScript did not emit the public $entry." >&2; exit 1; }
done
if [[ $2 == fixture ]]; then exec node fixtures/verify-workspace.mjs; fi
