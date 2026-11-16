import AppKit
import Combine

@MainActor final class DesktopActions: ObservableObject {
    @Published private(set) var executable: String
    let allowed: Bool

    init(allowed: Bool) {
        self.allowed = allowed
        executable = allowed ? CodexExecutable.locate()?.path ?? "Not found" : "Disabled in fixture"
    }

    func openChat(_ id: String) {
        guard allowed else { return }
        var destination = URLComponents()
        destination.scheme = "codex"
        destination.host = "threads"
        destination.path = "/" + id
        if let url = destination.url { NSWorkspace.shared.open(url) }
    }

    func reveal(_ url: URL) {
        guard allowed, url.isFileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func chooseExecutable() {
        guard allowed else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, CodexExecutable.isValid(url) {
            UserDefaults.standard.set(url.path, forKey: "codexExecutable")
            executable = url.path
        }
    }
}
