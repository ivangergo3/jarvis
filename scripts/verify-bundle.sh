#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bundle=build/Jarvis.app
plutil -lint "$bundle/Contents/Info.plist"
codesign --verify --deep --strict "$bundle"
test -x "$bundle/Contents/MacOS/Jarvis"
for resource in reactor.png AppIcon.icns CompletionChime.wav CompanionIdle{0..5}.png; do
    test -s "$bundle/Contents/Resources/$resource"
done
for permission in NSMicrophoneUsageDescription NSSpeechRecognitionUsageDescription; do
    /usr/libexec/PlistBuddy -c "Print :$permission" "$bundle/Contents/Info.plist"
done
