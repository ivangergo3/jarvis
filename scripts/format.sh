#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(cat Tools/SwiftFormat/VERSION)
revision=$(cat Tools/SwiftFormat/REVISION)
tool_dir="$PWD/.build/tools/swift-format-$version"
tool="$tool_dir/.build/release/swift-format"
lock_hash=$(shasum -a 256 Tools/SwiftFormat/Package.resolved | cut -d ' ' -f 1)

if [[ "${1:-check}" == bootstrap ]]; then
    if [[ ! -d "$tool_dir/.git" ]]; then
        mkdir -p "$(dirname "$tool_dir")"
        git clone --quiet --branch "$version" --depth 1 \
            https://github.com/swiftlang/swift-format.git "$tool_dir"
    fi
    [[ "$(git -C "$tool_dir" rev-parse HEAD)" == "$revision" ]] || {
        echo "Formatter checkout does not match the pinned revision." >&2; exit 1;
    }
    git -C "$tool_dir" diff --exit-code HEAD --
    cp Tools/SwiftFormat/Package.resolved "$tool_dir/Package.resolved"
    env -u SWIFTCI_USE_LOCAL_DEPS -u SWIFTFORMAT_BUILD_ONLY_TESTS \
        -u SWIFTSYNTAX_BUILD_DYNAMIC_LIBRARY -u SWIFTFORMAT_CI_INSTALL \
        swift build --package-path "$tool_dir" --configuration release \
        --product swift-format --disable-automatic-resolution --jobs 4
    cmp Tools/SwiftFormat/Package.resolved "$tool_dir/Package.resolved"
    [[ "$("$tool" --version)" == "$version" ]]
    printf '%s\n' "$lock_hash" > "$tool_dir/verified-lock.sha256"
    exit 0
fi

if [[ ! -x "$tool" || ! -f "$tool_dir/verified-lock.sha256" ]] \
    || [[ "$(cat "$tool_dir/verified-lock.sha256")" != "$lock_hash" ]]; then
    echo "Run ./scripts/format.sh bootstrap to build the pinned formatter locally." >&2
    exit 1
fi
[[ "$("$tool" --version)" == "$version" ]] || {
    echo "Unexpected swift-format version; expected $version." >&2; exit 1;
}
if [[ "${1:-check}" == tool-path ]]; then
    printf '%s\n' "$tool"
    exit 0
fi

[[ -f Package.swift && -d Sources && -d Tests \
    && -d UITests && -d Tools/NativeUI && -d Tools/QualityGate && -d Tools/QualitySupport ]] || {
    echo "Missing owned Swift source roots." >&2; exit 1;
}
files=(Package.swift)
while IFS= read -r -d '' file; do
    files+=("$file")
done < <(find Sources Tests UITests Tools/NativeUI Tools/QualityGate Tools/QualitySupport -type f -name '*.swift' -print0)
case "${1:-check}" in
    check) "$tool" lint --strict --configuration .swift-format "${files[@]}" ;;
    fix) "$tool" format --in-place --configuration .swift-format "${files[@]}" ;;
    *) echo "Usage: $0 {bootstrap|check|fix|tool-path}" >&2; exit 2 ;;
esac
