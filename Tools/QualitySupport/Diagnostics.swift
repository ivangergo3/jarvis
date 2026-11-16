import Foundation

public struct QualityFailure: Error, LocalizedError, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public enum Diagnostics {
    public static let tailLimit = 128 * 1024

    public static func redact(_ text: String) -> String {
        var result = text.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path, with: "<home>")
        result = result.replacingOccurrences(
            of: #"/(?:private/)?(?:var/folders|tmp)/[^\s"<>]+"#,
            with: "<temporary-path>", options: .regularExpression)
        return result.replacingOccurrences(
            of:
                #"(?im)(["']?(?:authorization|token|password|secret)["']?\s*[:=]\s*)(?:"[^"\n]*"|'[^'\n]*'|[^\n,}]+)"#,
            with: "$1<redacted>", options: .regularExpression)
    }

    public static func tail(of url: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else { return "" }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let size = try file.seekToEnd()
        try file.seek(toOffset: size > UInt64(tailLimit) ? size - UInt64(tailLimit) : 0)
        return redact(
            String(decoding: try file.read(upToCount: tailLimit) ?? Data(), as: UTF8.self))
    }

    public static func writeJSON(_ value: some Encodable, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var data = try encoder.encode(value)
        data.append(10)
        try data.write(to: url, options: .atomic)
    }
}

public final class TemporaryDirectory {
    public let url: URL

    public init(prefix: String) throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent(
            prefix + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        do { try FileManager.default.removeItem(at: url) } catch {
            FileHandle.standardError.write(
                Data("Temporary quality-tool directory could not be removed.\n".utf8))
        }
    }
}
