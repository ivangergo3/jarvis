#!/bin/bash
set -eu
for scope in full docs ''; do
    for classifier in success failure skipped cancelled ''; do
        for swift in success failure skipped cancelled ''; do
            for native in success failure skipped cancelled ''; do
                expected=1
                if [[ "$classifier" == success ]]; then
                    if [[ "$scope" == full && "$swift" == success && "$native" == success ]] ||
                       [[ "$scope" == docs && "$swift" == skipped && "$native" == skipped ]]; then
                        expected=0
                    fi
                fi
                actual=0
                bash scripts/ci-result.sh "$classifier" "$scope" "$swift" "$native" >/dev/null || actual=$?
                [[ "$actual" == "$expected" ]] || { echo "Unexpected CI outcome: $classifier $scope $swift $native"; exit 1; }
            done
        done
    done
done
echo 'Verified full and docs-only CI aggregation, including missing and cancelled jobs.'
