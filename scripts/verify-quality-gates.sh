#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
formatter=$(./scripts/format.sh tool-path)
mkdir -p .build/module-cache
scratch=$(mktemp -d "$PWD/.build/quality-probes.XXXXXX")
trap 'rm -rf "$scratch"' EXIT

printf 'func sum(_ a:Int,_ b:Int)->Int{return a+b}\n' > "$scratch/BadFormat.swift"
if "$formatter" lint --strict --configuration .swift-format "$scratch/BadFormat.swift" \
    > "$scratch/format.log" 2>&1; then
    echo 'Formatting gate accepted the malformed fixture.' >&2; exit 1
fi
grep -q '\[Spacing\]' "$scratch/format.log"
"$formatter" format --configuration .swift-format "$scratch/BadFormat.swift" > "$scratch/GoodFormat.swift"
"$formatter" lint --strict --configuration .swift-format "$scratch/GoodFormat.swift"

cat > "$scratch/Unsafe.swift" <<'SWIFT'
final class Counter { var value = 0 }
let sharedCounter = Counter()
SWIFT
cat > "$scratch/Safe.swift" <<'SWIFT'
actor Counter { var value = 0 }
let sharedCounter = Counter()
SWIFT
compiler=(xcrun swiftc -typecheck -parse-as-library -swift-version 6 -warnings-as-errors
    -target "$(uname -m)-apple-macosx14.0" -module-cache-path "$PWD/.build/module-cache")
if "${compiler[@]}" "$scratch/Unsafe.swift" > "$scratch/concurrency.log" 2>&1; then
    echo 'Swift 6 gate accepted shared non-Sendable mutable state.' >&2; exit 1
fi
grep -q 'not concurrency-safe' "$scratch/concurrency.log"
"${compiler[@]}" "$scratch/Safe.swift"
printf '%s\n' 'Verified: malformed formatting and unsafe shared state fail; corrected fixtures pass.'
