#!/bin/bash
set -euo pipefail
gate=$1
shift
# xargs appends the lane after the caller's optional Swift arguments.
lane=${!#}
set -- "${@:1:$#-1}"
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
    *) echo "Unknown check lane: $lane" >&2; exit 2 ;;
esac
