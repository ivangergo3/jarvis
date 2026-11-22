#!/bin/bash
set -eu
# Give each lane its own process group. On a terminal interrupt, the active
# checks can unwind normally and remove their own scratch files. The parent
# waits for them, reports cancellation, and does not launch the next batch.
set -m
interrupted=0
trap 'interrupted=130' INT
trap 'interrupted=143' TERM
trap 'interrupted=129' HUP

wait_for_lane() {
    local pid=$1 status
    while :; do
        if wait "$pid"; then return 0; else status=$?; fi
        # A trapped signal interrupts Bash's wait before the child exits.
        if (( interrupted == 0 )) || ! kill -0 "$pid" 2>/dev/null; then return "$status"; fi
    done
}

bash scripts/check-lane.sh core "$@" &
core=$!
bash scripts/check-lane.sh hover "$@" &
hover=$!
failed=0
wait_for_lane "$core" || failed=1
wait_for_lane "$hover" || failed=1
if (( interrupted != 0 )); then exit "$interrupted"; fi
if (( failed != 0 )); then exit 1; fi
bash scripts/check-lane.sh release "$@" &
release=$!
wait_for_lane "$release" || failed=1
if (( interrupted != 0 )); then exit "$interrupted"; fi
exit "$failed"
