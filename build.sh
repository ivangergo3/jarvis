#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build/Jarvis.app/Contents/MacOS build/Jarvis.app/Contents/Resources .build/module-cache
swift build --configuration release --product Jarvis -Xswiftc -warnings-as-errors
binary_dir=$(swift build --configuration release --show-bin-path)
cp "$binary_dir/Jarvis" build/Jarvis.app/Contents/MacOS/Jarvis
cp Resources/reactor.png build/Jarvis.app/Contents/Resources/reactor.png
cp Resources/AppIcon.icns build/Jarvis.app/Contents/Resources/AppIcon.icns
cp Resources/CompanionIdle*.png build/Jarvis.app/Contents/Resources/
cp Resources/CompletionChime.wav build/Jarvis.app/Contents/Resources/CompletionChime.wav
cp Info.plist build/Jarvis.app/Contents/Info.plist
codesign --force --deep --sign - build/Jarvis.app
echo "Built $PWD/build/Jarvis.app"
