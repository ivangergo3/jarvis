import Foundation
import ImageIO

/// File I/O and raster downsampling stay off the UI actor, with bounded input/output.
actor AttachmentPreviewLoader {
    func load(_ file: ChatAttachment, pixels: Int) -> Data? {
        guard file.isImage, let url = file.localURL, !Task.isCancelled else { return nil }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true, let size = values.fileSize,
                size > 0, size <= 50 * 1024 * 1024
            else { return nil }
        } catch { return nil }  // Missing, removed or inaccessible attachments show a file card.
        guard
            let source = CGImageSourceCreateWithURL(
                url as CFURL,
                [kCGImageSourceShouldCache: false] as CFDictionary),
            let image = CGImageSourceCreateThumbnailAtIndex(
                source, 0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: min(3200, max(64, pixels)),
                    kCGImageSourceCreateThumbnailWithTransform: true,
                ] as CFDictionary), !Task.isCancelled
        else { return nil }
        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                data, "public.png" as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
