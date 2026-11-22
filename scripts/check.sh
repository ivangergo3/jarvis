#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift --version
swift build --jobs 2 -Xswiftc -warnings-as-errors --product quality-gate
gate="$(swift build --show-bin-path)/quality-gate"
bash scripts/verify-check-lanes.sh "$gate"
exec "$gate" parallel-checks "$@"
