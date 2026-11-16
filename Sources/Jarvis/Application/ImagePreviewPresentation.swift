import Combine
import Foundation

@MainActor final class ImagePreviewPresentation: ObservableObject {
    @Published var file: ChatAttachment?
    private let loadImage: @Sendable (ChatAttachment, Int) async -> Data?

    init(loadImage: @escaping @Sendable (ChatAttachment, Int) async -> Data?) {
        self.loadImage = loadImage
    }

    func load(_ file: ChatAttachment, pixels: Int) async -> Data? {
        await loadImage(file, pixels)
    }
}
