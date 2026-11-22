#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Dependency downloads are reusable. Acceptance tasks must execute against this checkout.
export TURBO_TELEMETRY_DISABLED=1 TURBO_FORCE=true
node scripts/verify-vitest-links.mjs
pnpm install --frozen-lockfile --store-dir "${1:-$PWD/.pnpm-store}"
pnpm build
pnpm fixture
pnpm run check:style
pnpm -r --workspace-concurrency=1 --if-present run test
