#!/bin/bash
set -euo pipefail
scheduler="$PWD/scripts/run-check-lanes.sh"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/jarvis-check-lanes.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
cd "$scratch"
mkdir scripts
cat > scripts/check-lane.sh <<'SH'
#!/bin/bash
set -eu
lane=$1
test "$3" = 'two words'
if [[ "$lane" == release ]]; then
    touch release.entered
    test -f core.done
    test -f hover.done
    touch release.done
    exit 0
fi
touch "$lane.started"
other=core
[[ "$lane" == hover ]] || other=hover
for ((i=0; i<100; i++)); do
    [[ ! -f "$other.started" ]] || break
    sleep 0.02
done
test -f "$other.started"
if [[ "$MODE" == interrupt ]]; then
    # Wait until the test signals the supervisor and releases both workers.
    for ((i=0; i<100; i++)); do
        [[ ! -e "$JARVIS_CHECK_CANCEL_FILE" ]] || break
        sleep 0.02
    done
    test -f "$JARVIS_CHECK_CANCEL_FILE"
    touch "$lane.done"
    exit 1
fi
if [[ "$MODE" == "hold-$lane" ]]; then
    for ((i=0; i<250; i++)); do
        [[ ! -e finish ]] || break
        sleep 0.02
    done
    test -f finish
fi
[[ "$MODE" != "$lane" ]]
touch "$lane.done"
SH
for mode in pass core hover; do
    rm -f ./*.started ./*.done
    if MODE=$mode bash "$scheduler" fixture-gate 'two words'; then
        [[ "$mode" == pass && -f release.done ]]
    else
        [[ "$mode" != pass && ! -e release.done && -e core.started && -e hover.started ]]
    fi
done
for slow in core hover; do
    rm -f ./*.started ./*.done release.entered finish
    MODE="hold-$slow" bash "$scheduler" fixture-gate 'two words' &
    supervisor=$!
    fast=core
    [[ "$slow" != core ]] || fast=hover
    for ((i=0; i<100; i++)); do
        [[ ! -e "$fast.done" ]] || break
        sleep 0.02
    done
    test -f "$fast.done"
    test ! -e "$slow.done"
    # Leave the slow worker blocked after its peer exits.
    sleep 0.2
    test ! -e release.entered
    touch finish
    wait "$supervisor"
    test -f release.done
done
rm -f ./*.started ./*.done release.entered finish
MODE=interrupt bash "$scheduler" fixture-gate 'two words' &
supervisor=$!
for ((i=0; i<100; i++)); do
    [[ ! -e core.started || ! -e hover.started ]] || break
    sleep 0.02
done
test -f core.started
test -f hover.started
kill -TERM "$supervisor"
status=0
wait "$supervisor" || status=$?
test "$status" = 143
test -f core.done
test -f hover.done
test ! -e release.done
echo 'Verified parallel execution, failure propagation and cancellation.'
