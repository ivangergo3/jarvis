#!/bin/bash
set -euo pipefail
lane=$1
gate=$2
shift 2
case "$lane" in
    core)
        ./scripts/format.sh check
        ./scripts/verify-quality-gates.sh
        bash scripts/verify-workspace-architecture.sh "$gate"
        bash scripts/verify-app-architecture.sh "$gate"
        "$gate" skills
        "$gate" test --swift-arg=-Xswiftc --swift-arg=-warnings-as-errors "$@" \
            --swift-arg=--jobs --swift-arg=2
        ;;
    hover)
        "$gate" hover-fault "$@" --swift-arg=--jobs --swift-arg=2
        ;;
    release)
        "$gate" authority
        ./build.sh
        bash scripts/verify-bundle.sh
        ;;
    *) echo "Unknown check lane: $lane" >&2; exit 2 ;;
esac
