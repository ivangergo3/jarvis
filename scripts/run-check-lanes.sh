#!/bin/bash
set -eu
# Give each lane its own process group. On a terminal interrupt, the active
# checks can unwind normally and remove their own scratch files. The parent
# waits for them, reports cancellation, and does not launch the next batch.
set -m
scratch=$(mktemp -d "${TMPDIR:-/tmp}/jarvis-lanes.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
export JARVIS_CHECK_CANCEL_FILE="$scratch/cancel"
interrupted=0
trap 'interrupted=130; : > "$JARVIS_CHECK_CANCEL_FILE"' INT
trap 'interrupted=143; : > "$JARVIS_CHECK_CANCEL_FILE"' TERM
trap 'interrupted=129; : > "$JARVIS_CHECK_CANCEL_FILE"' HUP

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
# Release is the sole remaining lane. Return it to ordinary foreground
# execution so the terminal can interrupt an active release build directly.
set +m
trap - HUP TERM INT
if (( interrupted != 0 )); then exit "$interrupted"; fi
if (( failed != 0 )); then exit 1; fi
rm -rf "$scratch"
trap - EXIT
unset JARVIS_CHECK_CANCEL_FILE
exec /bin/bash scripts/check-lane.sh release "$@"
