import AppKit
import Combine

/// Owns full-screen commands for the dashboard window, independent of key-window focus.
@MainActor final class WindowControls: NSObject, ObservableObject, NSWindowDelegate {
    @Published var applicationActive = true
    @Published private(set) var windowVisible = true
    @Published private(set) var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    var decorativeMotion: Bool { applicationActive && windowVisible && !lowPowerMode }

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(powerStateChanged),
            name: .NSProcessInfoPowerStateDidChange, object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    @objc private func powerStateChanged() {
        lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    func windowDidChangeOcclusionState(_ notification: Notification) { updateVisibility() }
    func windowDidMiniaturize(_ notification: Notification) { updateVisibility() }
    func windowDidDeminiaturize(_ notification: Notification) { updateVisibility() }
    private func updateVisibility() {
        let visible = window?.occlusionState.contains(.visible) == true && window?.isMiniaturized != true
        if windowVisible != visible { windowVisible = visible }
    }
    @Published private(set) var isFullScreen = false
    @Published private(set) var transitioning = false
    private weak var window: NSWindow?

    func attach(to window: NSWindow) {
        self.window = window
        window.delegate = self
        isFullScreen = window.styleMask.contains(.fullScreen)
    }

    @objc func toggleFullScreen(_ sender: Any?) {
        guard let window, !transitioning else { return }
        transitioning = true
        window.toggleFullScreen(sender)
    }

    func windowWillEnterFullScreen(_ notification: Notification) { transitioning = true }
    func windowWillExitFullScreen(_ notification: Notification) { transitioning = true }
    func windowDidEnterFullScreen(_ notification: Notification) { settle() }
    func windowDidExitFullScreen(_ notification: Notification) { settle() }
    func windowDidFailToEnterFullScreen(_ window: NSWindow) { settle() }
    func windowDidFailToExitFullScreen(_ window: NSWindow) { settle() }

    private func settle() {
        isFullScreen = window?.styleMask.contains(.fullScreen) ?? false
        transitioning = false
    }
}
