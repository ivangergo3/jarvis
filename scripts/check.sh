#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift --version
./scripts/format.sh check
./scripts/verify-quality-gates.sh
swift test -Xswiftc -warnings-as-errors
./build.sh
