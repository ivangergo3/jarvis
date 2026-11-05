import AppKit
import ImageIO

/// Clipboard access is main-actor only; decoding and owned-file writes run in the store actor.
enum ClipboardImage: Sendable {
    case data(Data)
    case file(URL)

    @MainActor static func read(_ pasteboard: NSPasteboard) -> ClipboardImage? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
            let url = urls.first, ChatAttachment(name: url.lastPathComponent, location: url.path).isImage {
            return .file(url)
        }
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = pasteboard.data(forType: type) { return .data(data) }
        }
        return nil
    }
}

actor ComposerImageStore {
    static let shared = ComposerImageStore()
    private let directory: URL
    init(directory: URL = URL.applicationSupportDirectory.appendingPathComponent("Jarvis/Attachments", isDirectory: true)) {
        self.directory = directory
    }
    enum Failure: LocalizedError {
        case invalid, tooLarge
        var errorDescription: String? {
            switch self {
            case .invalid: return "The clipboard image could not be read."
            case .tooLarge: return "Use an image smaller than 20 MB and 40 megapixels."
            }
        }
    }
    func save(_ input: ClipboardImage) throws -> ChatAttachment {
        try Task.checkCancellation()
        let data: Data
        switch input {
        case .data(let bytes): data = bytes
        case .file(let url):
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true, let size = values.fileSize, size <= 20 * 1024 * 1024 else { throw Failure.tooLarge }
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        }
        guard data.count <= 20 * 1024 * 1024 else { throw Failure.tooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
            let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else { throw Failure.invalid }
        guard width.doubleValue * height.doubleValue <= 40_000_000 else { throw Failure.tooLarge }
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 4096,
            kCGImageSourceCreateThumbnailWithTransform: true
        ] as CFDictionary) else { throw Failure.invalid }
        let png = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(png, "public.png" as CFString, 1, nil) else { throw Failure.invalid }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw Failure.invalid }
        guard png.length <= 20 * 1024 * 1024 else { throw Failure.tooLarge }
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let url = directory.appendingPathComponent(UUID().uuidString + ".png")
        try (png as Data).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return ChatAttachment(name: "Pasted image", location: url.path)
    }
}
