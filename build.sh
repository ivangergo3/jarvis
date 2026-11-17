#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build/Jarvis.app/Contents/MacOS build/Jarvis.app/Contents/Resources .build/module-cache
build_revision=$(git rev-parse HEAD 2>/dev/null || printf unknown)
build_dirty=true
if git diff --quiet HEAD -- 2>/dev/null; then build_dirty=false; fi
build_untracked=true
if [[ "$build_revision" != unknown && -z "$(git ls-files --others --exclude-standard -- Sources Resources Package.swift build.sh)" ]]; then
    build_untracked=false
fi
swift build --configuration release --product Jarvis -Xswiftc -warnings-as-errors
binary_dir=$(swift build --configuration release --show-bin-path)
cp "$binary_dir/Jarvis" build/Jarvis.app/Contents/MacOS/Jarvis
cp Resources/reactor.png build/Jarvis.app/Contents/Resources/reactor.png
cp Resources/AppIcon.icns build/Jarvis.app/Contents/Resources/AppIcon.icns
cp Resources/CompanionIdle*.png build/Jarvis.app/Contents/Resources/
cp Resources/CompletionChime.wav build/Jarvis.app/Contents/Resources/CompletionChime.wav
cp Info.plist build/Jarvis.app/Contents/Info.plist
# Stamp the built source, not whichever checkout later prepares a fixture.
if ! git diff --quiet HEAD -- 2>/dev/null || [[ "$(git rev-parse HEAD 2>/dev/null || printf unknown)" != "$build_revision" ]]; then build_dirty=true; fi
if [[ -n "$(git ls-files --others --exclude-standard -- Sources Resources Package.swift build.sh)" ]]; then build_untracked=true; fi
build_toolchain=$(swift --version)
build_toolchain=${build_toolchain%%$'\n'*}
build_info=build/Jarvis.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Add :JarvisBuildRevision string $build_revision" "$build_info"
/usr/libexec/PlistBuddy -c "Add :JarvisBuildTrackedDirty bool $build_dirty" "$build_info"
/usr/libexec/PlistBuddy -c "Add :JarvisBuildUntrackedSources bool $build_untracked" "$build_info"
/usr/libexec/PlistBuddy -c "Add :JarvisBuildToolchain string $build_toolchain" "$build_info"
/usr/libexec/PlistBuddy -c "Add :JarvisBuildArchitecture string $(uname -m)" "$build_info"
codesign --force --deep --sign - build/Jarvis.app
echo "Built $PWD/build/Jarvis.app"
