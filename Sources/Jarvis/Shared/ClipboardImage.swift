import Foundation

enum ClipboardImage: Sendable {
    case data(Data)
    case file(URL)
}

protocol ComposerImageSaving: Sendable {
    func save(_ input: ClipboardImage) async throws -> ChatAttachment
}
