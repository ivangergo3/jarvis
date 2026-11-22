#!/bin/bash
set -euo pipefail
gate=$1
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
    test -f core.done && test -f hover.done
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
    sleep 20 &
    echo "$!" > "$lane.child"
    wait
fi
[[ "$MODE" != "$lane" ]]
touch "$lane.done"
SH
for mode in pass core hover; do
    rm -f ./*.started ./*.done
    if MODE=$mode "$gate" parallel-checks 'two words'; then
        [[ "$mode" == pass && -f release.done ]]
    else
        [[ "$mode" != pass && ! -e release.done && -e core.started && -e hover.started ]]
    fi
done
rm -f ./*.started ./*.done
MODE=interrupt "$gate" parallel-checks 'two words' &
supervisor=$!
for ((i=0; i<100; i++)); do
    [[ ! -s core.child || ! -s hover.child ]] || break
    sleep 0.02
done
kill -TERM "$supervisor"
if wait "$supervisor"; then exit 1; fi
for lane in core hover; do
    child=$(cat "$lane.child")
    if kill -0 "$child" 2>/dev/null; then
        # An exited child can briefly remain as a zombie until the host reaps it.
        [[ "$(ps -o stat= -p "$child")" == Z* ]]
    fi
done
test ! -e release.done
echo 'Verified parallel execution, failure propagation and cancellation.'
