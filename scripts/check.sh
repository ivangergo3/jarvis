#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift --version
./scripts/format.sh check
./scripts/verify-quality-gates.sh
swift run -Xswiftc -warnings-as-errors quality-gate test \
    --swift-arg=-Xswiftc --swift-arg=-warnings-as-errors
./build.sh
