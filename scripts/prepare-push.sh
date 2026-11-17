#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(git config --get core.hooksPath)" == .githooks ]] || {
    echo 'Install repository hooks first: bash scripts/install-hooks.sh' >&2; exit 1;
}
git fetch --quiet origin main
exec swift run quality-gate push prepare "$@"
