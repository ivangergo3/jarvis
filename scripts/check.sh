#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift --version
./scripts/format.sh check
./scripts/verify-quality-gates.sh
bash ./scripts/verify-workspace-architecture.sh
bash ./scripts/verify-app-architecture.sh
swift run -Xswiftc -warnings-as-errors quality-gate skills
swift run -Xswiftc -warnings-as-errors quality-gate test \
    --swift-arg=-Xswiftc --swift-arg=-warnings-as-errors "$@"
swift run -Xswiftc -warnings-as-errors quality-gate authority
./build.sh
