#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# == 0 ]]; then
    swift build --jobs 2 -Xswiftc -warnings-as-errors --product quality-gate
    set -- "$(swift build --show-bin-path)/quality-gate"
fi
gate=$1
fixture=$(mktemp -d "${TMPDIR:-/tmp}/jarvis-architecture.XXXXXX")
trap 'status=$?; if [[ $status != 0 && -f "$fixture/probe.log" ]]; then tail -n 60 "$fixture/probe.log" >&2; fi; rm -rf "$fixture"' EXIT
mkdir -p "$fixture/Sources/JarvisDomain" "$fixture/Sources/JarvisWorkspace" "$fixture/Sources/Jarvis"
mkdir -p "$fixture/Sources/JarvisAuthority"
printf 'import Foundation\nstruct Authority {}\n' > "$fixture/Sources/JarvisAuthority/Authority.swift"
manifest() {
    cat > "$fixture/Package.swift" <<EOF
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ArchitectureFixture", targets: [
    .target(name: "JarvisAuthority"),
    .target(name: "JarvisDomain", dependencies: $1),
    .target(name: "JarvisWorkspace", dependencies: ["JarvisDomain"]),
    .executableTarget(name: "Jarvis", dependencies: ["JarvisDomain", "JarvisWorkspace"])
])
EOF
}
manifest '[]'
printf 'import SwiftUI\nstruct Forbidden {}\n' > "$fixture/Sources/JarvisDomain/Injected.swift"
printf 'import JarvisDomain\nstruct Adapter {}\n' > "$fixture/Sources/JarvisWorkspace/Adapter.swift"
printf 'import JarvisDomain\nprint("synthetic fixture")\n' > "$fixture/Sources/Jarvis/Main.swift"
if "$gate" architecture --root "$fixture" > "$fixture/probe.log" 2>&1; then
    echo 'Forbidden UI dependency was accepted.' >&2; exit 1
fi
grep -Fq 'Sources/JarvisDomain/Injected.swift: forbidden import SwiftUI' "$fixture/probe.log"
printf 'import Foundation\nstruct Corrected {}\n' > "$fixture/Sources/JarvisDomain/Injected.swift"
"$gate" architecture --root "$fixture"
manifest '["JarvisWorkspace"]'
if "$gate" architecture --root "$fixture" > "$fixture/probe.log" 2>&1; then
    echo 'Forbidden reverse dependency was accepted.' >&2; exit 1
fi
grep -Fq 'JarvisDomain: dependencies must be []' "$fixture/probe.log"
manifest '[]'
"$gate" architecture --root "$fixture"
echo 'Workspace architecture probes: forbidden imports and graph edges rejected; corrections passed.'
