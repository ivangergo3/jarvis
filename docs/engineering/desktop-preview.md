# Run Jarvis Preview on macOS

Use Node 24.19.0 and pnpm 10.7.1 from the repository root.

```sh
pnpm install --frozen-lockfile
pnpm desktop:package
```

The final output line gives the absolute path to `Jarvis Preview.app`. Open that bundle in Finder or pass its path to `open`. Each packaging run creates a new output directory under `.build/desktop-previews/`. Packaging downloads the pinned Electron runtime for the host architecture on the first run. To reuse a local copy of the official Electron archive for your Mac, set `JARVIS_ELECTRON_ZIP_DIR` to its directory.

The window shows a synthetic workspace. Select **Observatory**, then **Sessions** to see **Shell verification**. Use **All projects** to return to the workspace. The preview uses bundle identifier `dev.greg.jarvis.preview` and its own `Jarvis Preview` application-support directory.

### Return to the Swift app

Close the preview and open the original **Jarvis.app** from Finder. If you built Swift from this checkout, its bundle is available from the repository root:

```sh
open ./build/Jarvis.app
```

If that path is missing, open the Swift copy you already use or build it with `./build.sh`. Swift's bundle identifier is `dev.greg.jarvis.missioncontrol`. Opening it requires no uninstaller, database reset, or history migration. Keep both app bundles and their data directories while trying the rewrite.

The packaged preview currently uses synthetic conversations. Its screenshots and launch checks qualify that fixture. The switch to daily use requires an owner-authenticated task, recovery after reopening, a verified backup and restore of new-app data, and the visual and performance acceptance checks. Continue using Swift for live work until those pass. [Cutover acceptance](https://github.com/ivangergo3/jarvis/issues/137)

### Verify a preview build

The build uses an ad-hoc signature for local development. Developer ID distribution and notarization require separate qualification.

Before printing the bundle path, packaging verifies its preview identity, host architecture and ad-hoc signature, including signed resources. Full GitHub checks run the same packaging command on Intel macOS.

Run `pnpm desktop:package --smoke` to exercise the signed bundle with Playwright. It opens the synthetic window, checks the renderer sandbox and preload bridge, visits Observatory and Sessions, tests blocked navigation, then closes the window. The result directory contains two screenshots and a JSON receipt. Set `JARVIS_SMOKE_EVIDENCE_DIR` to a new absolute output path if desired. GitHub retains these three files from its Intel run. If process cleanup cannot be verified, the command fails and prints the location of its retained diagnostic profile.

Reopening the running preview from Finder or the Dock restores the existing project window. The packaged smoke minimizes the real window, delivers Electron’s activation event inside its synthetic profile, and checks native and renderer focus as well as the selected project.

## On-device dictation adapter

The Phase 1 target is a user-initiated microphone session that returns editable text to the original conversation draft. The current packaged preview has no microphone control.

The existing Swift app uses AVFoundation to capture audio and Apple Speech to recognize it. For the Electron port, keep this macOS-specific capture and recognition in a bundled Swift helper. The TypeScript host owns its lifetime and the current renderer document. React owns the controls and editable draft. The helper has no reason to receive a Codex credential, a chat transcript, or a send-message capability. Audio samples stay between the capture engine and the on-device recognizer.

Before recording for a selected language, check microphone and speech permissions, recognizer availability and local recognition support. Compare the recognizer’s effective BCP 47 locale with the requested locale before opening the microphone. macOS can substitute a different locale. Set the local-only flag on every recognition request. If a check fails, show the reason and keep typing available. The two Apple API checks are both necessary. [Recognizer capability](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition) · [Local recognition request](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition)

| Action | Expected result |
| --- | --- |
| Start | Bind a fresh recording ID to the current document, project and chat. Request permissions only after the user starts. Offer UK and US English, French and Hungarian, subject to local availability. |
| Finish | Stop capture. Final text, or the latest partial after the existing three-second finish window, goes to the originating editable draft. Sending needs a separate user action. |
| Cancel, navigate away, lose the renderer, sleep or close | Electron main invalidates the recording ID and stops the helper on loss of the originating document, including a renderer crash. Release the input tap, recognition task and capture engine. Ignore late results and permission callbacks. |
| Helper exit, unavailable device or asset | End the recording with a visible status. Never retry using a network recognizer. |

The following probe passed with Apple Swift 6.4.2 and the macOS 27.2 SDK targeting ARM64 macOS 14. Save it as `probe.swift` and run `xcrun swiftc -typecheck -target arm64-apple-macosx14.0 probe.swift`. This check does not exercise recognition or determine installed language availability. Planned automated acceptance uses a fake recognizer for cancellation, delayed results and cross-chat events. Packaged permission prompts, audio input, supported languages and termination of capture require a separate hands-on Mac check.

```swift
import AVFoundation
import Speech

@available(macOS 14, *)
func localRequest(_ identifier: String) -> SFSpeechAudioBufferRecognitionRequest? {
    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: identifier)),
        recognizer.locale.identifier(.bcp47) == Locale(identifier: identifier).identifier(.bcp47),
        recognizer.isAvailable, recognizer.supportsOnDeviceRecognition
    else { return nil }
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.requiresOnDeviceRecognition = true
    request.shouldReportPartialResults = true
    return request
}
```
