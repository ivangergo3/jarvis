#!/bin/bash
set -euo pipefail
lane=$1
gate=$2
shift 2
stage() {
    [[ ! -e "${JARVIS_CHECK_CANCEL_FILE:-}" ]] || return 1
    "$@"
}
case "$lane" in
    core)
        stage bash scripts/check-lane.sh static "$gate" "$@"
        stage bash scripts/check-lane.sh unit "$gate" "$@"
        ;;
    static)
        stage ./scripts/format.sh check
        stage ./scripts/verify-quality-gates.sh
        stage bash scripts/verify-workspace-architecture.sh "$gate"
        stage bash scripts/verify-app-architecture.sh "$gate"
        stage "$gate" skills
        ;;
    unit)
        stage "$gate" test --swift-arg=-Xswiftc --swift-arg=-warnings-as-errors "$@" \
            --swift-arg=--jobs "--swift-arg=${JARVIS_SWIFT_JOBS:-2}"
        ;;
    hover)
        stage "$gate" hover-fault "$@" --swift-arg=--jobs "--swift-arg=${JARVIS_SWIFT_JOBS:-2}"
        ;;
    release)
        stage "$gate" authority
        stage ./build.sh
        stage bash scripts/verify-bundle.sh
        ;;
    *) echo "Unknown check lane: $lane" >&2; exit 2 ;;
esac
