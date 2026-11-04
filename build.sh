#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build/Jarvis.app/Contents/MacOS build/Jarvis.app/Contents/Resources .build/module-cache
swiftc -swift-version 5 -O -parse-as-library -module-cache-path "$PWD/.build/module-cache" Sources/Jarvis/*.swift -o build/Jarvis.app/Contents/MacOS/Jarvis -framework AppKit -framework SwiftUI -lsqlite3
cp Resources/reactor.png build/Jarvis.app/Contents/Resources/reactor.png
cp Resources/AppIcon.icns build/Jarvis.app/Contents/Resources/AppIcon.icns
cp Info.plist build/Jarvis.app/Contents/Info.plist
codesign --force --deep --sign - build/Jarvis.app
echo "Built $PWD/build/Jarvis.app"
