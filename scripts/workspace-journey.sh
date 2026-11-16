#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
case "${1:-}" in
    prepare)
        [[ -x build/Jarvis.app/Contents/MacOS/Jarvis ]] || { echo 'Run ./build.sh first.' >&2; exit 1; }
        run_dir=$(mktemp -d "${TMPDIR:-/tmp}/jarvis-workspace-journey.XXXXXX")
        mkdir "$run_dir/data"
        xcrun swiftc -swift-version 6 Tests/Fixtures/WorkspaceJourney.swift -lsqlite3 -o "$run_dir/setup"
        "$run_dir/setup" "$run_dir/data" > "$run_dir/setup.log"
        app="$run_dir/Jarvis Workspace Fixture.app"
        ditto build/Jarvis.app "$app"
        bundle_id="dev.jarvis.workspacefixture.$(uuidgen | tr '[:upper:]' '[:lower:]')"
        printf '%s\n' "$bundle_id" > "$run_dir/bundle-id"
        /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" "$app/Contents/Info.plist"
        /usr/libexec/PlistBuddy -c 'Set :CFBundleName Jarvis Workspace Fixture' "$app/Contents/Info.plist"
        /usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Jarvis Workspace Fixture' "$app/Contents/Info.plist"
        /usr/libexec/PlistBuddy -c "Add :JarvisWorkspaceFixtureDirectory string $run_dir/data" "$app/Contents/Info.plist"
        codesign --force --deep --sign - "$app" >&2
        printf '%s\n' "$run_dir"
        ;;
    cleanup)
        run_dir=${2:?Pass the directory printed by prepare}
        [[ "${run_dir##*/}" == jarvis-workspace-journey.* ]] || exit 64
        [[ -f "$run_dir/bundle-id" ]] || exit 64
        bundle_id=$(cat "$run_dir/bundle-id")
        [[ "$bundle_id" == dev.jarvis.workspacefixture.* ]] || exit 64
        if /usr/sbin/lsof "$run_dir/Jarvis Workspace Fixture.app/Contents/MacOS/Jarvis" >/dev/null 2>&1; then
            echo 'Quit the fixture app first; cleanup will not kill a process.' >&2; exit 1
        fi
        # This domain and directory were created solely for this synthetic run.
        defaults delete "$bundle_id" 2>/dev/null || true
        rm -rf "$run_dir"
        ;;
    *) echo 'Usage: bash scripts/workspace-journey.sh {prepare|cleanup directory}' >&2; exit 64 ;;
esac
