#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# == 0 ]]; then
    swift build --jobs 2 -Xswiftc -warnings-as-errors --product quality-gate
    set -- "$(swift build --show-bin-path)/quality-gate"
fi
gate=$1
fixture=$(mktemp -d "${TMPDIR:-/tmp}/jarvis-app-architecture.XXXXXX")
trap 'status=$?; if [[ $status != 0 && -f "$fixture/probe.log" ]]; then tail -n 60 "$fixture/probe.log" >&2; fi; rm -rf "$fixture"' EXIT
mkdir -p "$fixture/Sources/Jarvis/Shared" "$fixture/Sources/Jarvis/Application" \
    "$fixture/Sources/Jarvis/Integrations" "$fixture/Sources/Jarvis/Presentation/Views"
check() {
    "$gate" app-architecture --root "$fixture"
}
reject() {
    if check > "$fixture/probe.log" 2>&1; then
        echo "Forbidden architecture was accepted: $1" >&2; exit 1
    fi
    grep -Fq "$1" "$fixture/probe.log"
}
printf 'import SwiftUI\nstruct Contract {}\n' > "$fixture/Sources/Jarvis/Shared/Contract.swift"
reject 'forbidden import SwiftUI'
printf 'import Foundation\nprotocol Storage {}\n' > "$fixture/Sources/Jarvis/Shared/Contract.swift"
check
printf 'actor DiskStore: Storage {}\n' > "$fixture/Sources/Jarvis/Integrations/Store.swift"
printf 'class State { let storage: DiskStore }\n' > "$fixture/Sources/Jarvis/Application/State.swift"
reject 'forbidden Integrations reference DiskStore'
printf 'class State { let storage: any Storage }\n' > "$fixture/Sources/Jarvis/Application/State.swift"
check
printf 'let process = Process()\n' > "$fixture/Sources/Jarvis/Presentation/Views/Screen.swift"
reject 'forbidden effect Process'
printf 'struct Screen { let state: State }\n' > "$fixture/Sources/Jarvis/Presentation/Views/Screen.swift"
check
printf 'struct Loose {}\n' > "$fixture/Sources/Jarvis/Loose.swift"
reject 'uncategorized app source'
mv "$fixture/Sources/Jarvis/Loose.swift" "$fixture/Sources/Jarvis/Shared/Loose.swift"
check
echo 'Native app architecture probes: imports, reverse references, effects and unclassified sources rejected; corrections passed.'
