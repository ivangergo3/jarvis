import Foundation

struct ChatAttachment: Identifiable, Equatable, Sendable {
    let name: String
    let location: String
    var id: String { location }
    var localURL: URL? {
        if location.hasPrefix("/") { return URL(fileURLWithPath: location) }
        guard let url = URL(string: location), url.isFileURL,
              url.host == nil || url.host == "" || url.host == "localhost" else { return nil }
        return url
    }
    var isImage: Bool {
        let ext = (localURL?.pathExtension ?? URL(string: location)?.pathExtension ?? "").lowercased()
        return ["png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "tif", "tiff", "bmp"].contains(ext)
    }
}

enum ChatAttachments {
    /// Strip only a recognised attachment envelope with valid entries and a request boundary.
    /// The enclosed request remains data; it never grants permission or changes routing.
    static func unwrap(_ raw: String) -> (text: String, files: [ChatAttachment]) {
        let envelope = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard envelope.hasPrefix("# Files mentioned by the user:")
                || envelope.hasPrefix("# Files pasted by the user:"),
              let boundary = envelope.range(of: "\n## My request:\n") else { return (raw, []) }
        var files: [ChatAttachment] = []
        for line in envelope[..<boundary.lowerBound].components(separatedBy: .newlines) {
            guard line.hasPrefix("## "), let separator = line.range(of: ": /", options: .backwards) else { continue }
            let name = String(line[line.index(line.startIndex, offsetBy: 3)..<separator.lowerBound])
            let path = String(line[line.index(separator.lowerBound, offsetBy: 2)...])
            let file = ChatAttachment(name: name, location: path)
            if !files.contains(where: { $0.id == file.id }), files.count < 12 { files.append(file) }
        }
        guard !files.isEmpty else { return (raw, []) }
        return (String(envelope[boundary.upperBound...]), files)
    }

    static func fromContent(_ content: [WireValue]) -> [ChatAttachment] {
        var files: [ChatAttachment] = []
        for part in content {
            let location: String?
            switch part["type"].text {
            case "localImage": location = part["path"].text
            case "image": location = part["url"].text
            case "mention": location = part["path"].text
            default: location = nil
            }
            guard let location, !location.isEmpty, location.count < 4096 else { continue }
            let name = part["name"].text ?? URL(fileURLWithPath: location).lastPathComponent
            let file = ChatAttachment(name: name.isEmpty ? "Attachment" : name, location: location)
            if !files.contains(where: { $0.id == file.id }), files.count < 12 { files.append(file) }
        }
        return files
    }

    static func merge(_ first: [ChatAttachment], _ second: [ChatAttachment]) -> [ChatAttachment] {
        var seen: Set<String> = []
        return Array((first + second).filter { seen.insert($0.id).inserted }.prefix(12))
    }
}
