import AppKit
import Foundation
import ImageIO
import Testing
@testable import Jarvis

@Suite("Composer image paste") @MainActor struct ComposerImageTests {
    private func png() throws -> Data {
        let space = CGColorSpaceCreateDeviceRGB()
        let context = try #require(CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8,
            bytesPerRow: 8, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        let image = try #require(context.makeImage())
        let bytes = NSMutableData()
        let output = try #require(CGImageDestinationCreateWithData(bytes, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(output, image, nil)
        #expect(CGImageDestinationFinalize(output))
        return bytes as Data
    }

    @Test func clipboardDistinguishesTextAndImages() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("ordinary paste", forType: .string)
        #expect(ClipboardImage.read(board) == nil)
        board.clearContents()
        board.setData(try png(), forType: .png)
        guard case .data(let bytes) = ClipboardImage.read(board) else { Issue.record("No clipboard image"); return }
        #expect(!bytes.isEmpty)
    }

    @Test func nativePasteCommandAcceptsAnImageOnlyClipboard() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setData(try png(), forType: .png)
        let editor = ImagePasteTextView()
        editor.isRichText = false
        editor.isEditable = true
        editor.imagePasteboard = board
        var received = 0
        editor.onImage = { _ in received += 1 }
        let menuItem = NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        #expect(editor.validateUserInterfaceItem(menuItem))
        editor.paste(nil)
        #expect(received == 1)
        #expect(editor.string.isEmpty)
        editor.isEditable = false
        editor.paste(nil)
        #expect(received == 1)
    }

    @Test func imagesStayWithDraftAndSendAsLocalImages() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ComposerImageStore(directory: folder)
        let connection = LinkedFixtureConnection()
        let model = CompanionModel(makeConnection: { connection })
        let first = ConversationScope(projectID: "p", name: "Same", directory: nil, threadID: "a")
        let second = ConversationScope(projectID: "p", name: "Same", directory: nil, threadID: "b")
        await model.follow(first)
        await model.pasteImage(.data(try png()), store: store)?.value
        let image = try #require(model.draftImages.first)
        #expect(FileManager.default.fileExists(atPath: image.location))
        #expect(model.canSend) // Images alone are a complete message.
        await model.follow(second)
        #expect(model.draftImages.isEmpty)
        await model.follow(first)
        #expect(model.draftImages == [image])
        await model.send(in: first)?.value
        let call = try #require(await connection.calls.last { $0.method == "thread/queue/add" })
        #expect(call.params["threadId"].text == "a")
        #expect(call.params["input"].values == [.object(["type": .string("localImage"), "path": .string(image.location)])])
        #expect(model.draftImages.isEmpty)
        #expect(model.messages.last?.attachments.map(\.location) == [image.location])
        await model.follow(second)
        await model.follow(first)
        #expect(model.draftImages.isEmpty)
        await model.shutdown()
    }

    @Test func uncertainImageSendRetainsPreviewAndNeverReplays() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let connection = LinkedFixtureConnection(lostAcknowledgement: true)
        let model = CompanionModel(makeConnection: { connection })
        let scope = ConversationScope(projectID: "p", name: "Test", directory: nil, threadID: "a")
        await model.follow(scope)
        await model.pasteImage(.data(try png()), store: ComposerImageStore(directory: folder))?.value
        await model.send(in: scope)?.value
        #expect(model.phase == .outcomeUnknown)
        #expect(model.draftImages.count == 1)
        #expect(!model.canSend)
        await model.refreshLinkedHistory()
        #expect(model.draftImages.isEmpty)
        #expect(await connection.calls.filter { $0.method == "thread/queue/add" }.count == 1)
        await model.shutdown()
    }

    @Test func invalidClipboardDoesNotCreateAnAttachment() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ComposerImageStore(directory: folder)
        await #expect(throws: ComposerImageStore.Failure.self) { try await store.save(.data(Data("not an image".utf8))) }
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }
}
