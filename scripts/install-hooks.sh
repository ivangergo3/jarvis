#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
existing=$(git config --get core.hooksPath || true)
[[ -z "$existing" || "$existing" == .githooks ]] || {
    echo 'Existing hooksPath found; preserve it and arrange explicit integration first.' >&2; exit 1;
}
for existing_hook in "$(git rev-parse --git-path hooks)"/*; do
    [[ ! -e "$existing_hook" || "$existing_hook" == *.sample ]] && continue
    echo 'Existing hooks found; preserve them and arrange explicit integration first.' >&2; exit 1
done
for hook in pre-commit pre-push; do
    [[ -x ".githooks/$hook" ]] || { echo "Missing executable $hook" >&2; exit 1; }
done
git config --local core.hooksPath .githooks
echo 'Installed repository-local size and push gates. No global configuration changed.'
