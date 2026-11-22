#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift --version
swift build --jobs 2 -Xswiftc -warnings-as-errors --product quality-gate
gate="$(swift build --show-bin-path)/quality-gate"

# Both lanes read the same source; hover mutates and builds only its private copy.
# xargs waits for both and returns nonzero if either fails. Keep each argument intact.
printf '%s\0' core hover | /usr/bin/xargs -0 -n 1 -P 2 \
    /bin/bash scripts/check-lane.sh "$gate" "$@"

"$gate" authority
./build.sh
bash scripts/verify-bundle.sh
