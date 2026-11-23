#!/bin/bash
set -eu
# Exercise the actual protected verdict. This step runs inline on GitHub
# without checking out or executing any PR files in the aggregate job.
verdict=$(awk '
    /^        id: required_result$/ { found=1; next }
    found && /^        run: \|$/ { body=1; next }
    body && /^          / { print substr($0, 11); next }
    body { exit }
' .github/workflows/quality.yml)
test -n "$verdict"
export SWIFT_LANES=unit/hover/release/static NATIVE_SHARDS=1/2
for scope in full docs ''; do
    export DESKTOP_RESULT=success
    if [[ "$scope" == docs ]]; then export DESKTOP_RESULT=skipped; fi
    for classifier in success failure skipped cancelled ''; do
        for swift in success failure skipped cancelled ''; do
            for native in success failure skipped cancelled ''; do
                for ts in success failure skipped cancelled ''; do
                    expected=1
                    if [[ "$classifier" == success ]]; then
                        if [[ "$scope" == full && "$swift" == success && "$native" == success && "$ts" == success ]] ||
                           [[ "$scope" == docs && "$swift" == skipped && "$native" == skipped && "$ts" == skipped ]]; then
                            expected=0
                        fi
                    fi
                    actual=0
                    SCOPE_RESULT="$classifier" SCOPE="$scope" SWIFT_RESULT="$swift" NATIVE_RESULT="$native" TS_RESULT="$ts" bash -e -c "$verdict" >/dev/null || actual=$?
                    [[ "$actual" == "$expected" ]] || { echo "Unexpected CI outcome: $classifier $scope $swift $native $ts"; exit 1; }
                done
            done
        done
    done
done
for scope in full docs; do
    required=success
    if [[ "$scope" == docs ]]; then required=skipped; fi
    for desktop in success failure skipped cancelled ''; do
        [[ "$desktop" != "$required" ]] || continue
        if SCOPE_RESULT=success SCOPE="$scope" SWIFT_RESULT="$required" NATIVE_RESULT="$required" \
            TS_RESULT="$required" DESKTOP_RESULT="$desktop" bash -e -c "$verdict" >/dev/null; then
            echo "Unexpected desktop result accepted: $scope $desktop" >&2; exit 1
        fi
    done
done
export DESKTOP_RESULT=success
for missing in unit hover release static 1 2; do
    if SCOPE_RESULT=success SCOPE=full SWIFT_RESULT=success NATIVE_RESULT=success TS_RESULT=success \
        SWIFT_LANES="${SWIFT_LANES/$missing/}" NATIVE_SHARDS="${NATIVE_SHARDS/$missing/}" \
        bash -e -c "$verdict" >/dev/null; then
        echo "A full run passed without completion evidence for $missing." >&2; exit 1
    fi
done
echo 'Verified full and docs-only CI aggregation, including missing and cancelled jobs.'
