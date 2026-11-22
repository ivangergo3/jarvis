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
run_verdict() ( set -e; eval "$verdict" )
for scope in full docs ''; do
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
                    SCOPE_RESULT="$classifier" SCOPE="$scope" SWIFT_RESULT="$swift" NATIVE_RESULT="$native" TS_RESULT="$ts" run_verdict >/dev/null || actual=$?
                    [[ "$actual" == "$expected" ]] || { echo "Unexpected CI outcome: $classifier $scope $swift $native $ts"; exit 1; }
                done
            done
        done
    done
done
echo 'Verified full and docs-only CI aggregation, including missing and cancelled jobs.'
