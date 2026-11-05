import AppKit
import SwiftUI

/// A narrow AppKit bridge preserves native editing while intercepting image paste.
struct ComposerEditor: NSViewRepresentable {
    @Binding var text: String
    let editable: Bool
    let pasteImage: (ClipboardImage) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        let editor = ImagePasteTextView()
        editor.isRichText = false
        editor.importsGraphics = false
        editor.drawsBackground = false
        editor.font = .systemFont(ofSize: 13)
        editor.textColor = NSColor(HUD.text)
        editor.insertionPointColor = NSColor(HUD.cyan)
        editor.textContainerInset = NSSize(width: 5, height: 6)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.delegate = context.coordinator
        editor.setAccessibilityLabel("Message to Jarvis chat")
        editor.setAccessibilityIdentifier("companion.draft")
        scroll.documentView = editor
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? ImagePasteTextView else { return }
        if editor.string != text { editor.string = text }
        editor.isEditable = editable
        editor.onImage = pasteImage
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ComposerEditor
        init(_ parent: ComposerEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            if let editor = notification.object as? NSTextView { parent.text = editor.string }
        }
    }
}

final class ImagePasteTextView: NSTextView {
    var imagePasteboard: NSPasteboard = .general
    var onImage: ((ClipboardImage) -> Void)?
    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(paste(_:)), isEditable,
            imagePasteboard.availableType(from: [.png, .tiff, .fileURL]) != nil {
            return true
        }
        return super.validateUserInterfaceItem(item)
    }
    override func paste(_ sender: Any?) {
        guard isEditable else { return }
        if let image = ClipboardImage.read(imagePasteboard) { onImage?(image) }
        else { super.paste(sender) }
    }
}
