import AppKit

/// Clipboard access is main-actor only; decoding and owned-file writes run in the store actor.
extension ClipboardImage {
    @MainActor static func read(_ pasteboard: NSPasteboard) -> ClipboardImage? {
        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
            let url = urls.first,
            ChatAttachment(name: url.lastPathComponent, location: url.path).isImage
        {
            return .file(url)
        }
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = pasteboard.data(forType: type) { return .data(data) }
        }
        return nil
    }
}
