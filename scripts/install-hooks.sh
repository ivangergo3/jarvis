#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
existing=$(git config --get core.hooksPath || true)
[[ -z "$existing" || "$existing" == .githooks ]] || {
    echo 'Existing hooksPath found; preserve it and arrange explicit integration first.' >&2; exit 1;
}
for hook in pre-commit pre-push; do
    [[ ! -e "$(git rev-parse --git-path hooks)/$hook" ]] || {
        echo "Existing $hook found; preserve it and arrange explicit integration first." >&2; exit 1;
    }
    [[ -x ".githooks/$hook" ]] || { echo "Missing executable $hook" >&2; exit 1; }
done
git config --local core.hooksPath .githooks
echo 'Installed repository-local size and push gates. No global configuration changed.'
