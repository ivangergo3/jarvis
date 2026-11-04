import AppKit
import Combine

private actor CompanionArtworkLoader {
    func read(_ urls: [URL]) -> [Data] {
        urls.compactMap { url in
            guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                size <= 1_048_576
            else { return nil }
            return try? Data(contentsOf: url)
        }
    }
}

@MainActor final class CompanionArtwork: ObservableObject {
    @Published private(set) var frames: [NSImage] = []
    private let loader = CompanionArtworkLoader()

    func load() async {
        guard frames.isEmpty, let root = Bundle.main.resourceURL else { return }
        let urls = (0..<6).map { root.appendingPathComponent("CompanionIdle\($0).png") }
        let data = await loader.read(urls)
        guard !Task.isCancelled else { return }
        frames = data.compactMap { NSImage(data: $0) }
    }
}
