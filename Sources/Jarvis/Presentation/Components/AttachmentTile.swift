import AppKit
import SwiftUI

@MainActor private final class AttachmentViewState: ObservableObject {
    @Published var image: NSImage?
    @Published var loaded = false
}

struct AttachmentTile: View {
    let file: ChatAttachment
    @EnvironmentObject private var preview: ImagePreviewPresentation
    @EnvironmentObject private var desktopActions: DesktopActions
    @StateObject private var state = AttachmentViewState()

    var body: some View {
        Button {
            if state.image != nil {
                preview.file = file
            } else if let url = file.localURL {
                desktopActions.reveal(url)
            }
        } label: {
            VStack(spacing: 6) {
                if let image = state.image {
                    Image(nsImage: image).resizable().scaledToFit().frame(height: 100)
                } else {
                    Image(systemName: file.isImage ? "photo" : "doc")
                        .font(.system(size: 26)).frame(height: 50)
                    Text(file.name).font(.system(size: 11)).lineLimit(2)
                    Text(state.loaded && file.isImage ? "Preview unavailable" : "Attachment")
                        .font(.system(size: 10)).foregroundStyle(HUD.muted)
                }
            }.frame(maxWidth: .infinity).padding(7)
                .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(HUD.line))
        }
        .buttonStyle(.plain).disabled(file.localURL == nil)
        .accessibilityLabel(
            file.isImage ? "Preview image: \(file.name)" : "Reveal file: \(file.name)"
        )
        .help(file.name)
        .task(id: file.id) {
            state.image = nil
            state.loaded = false
            let data = await preview.load(file, pixels: 300)
            guard !Task.isCancelled else { return }
            state.image = data.flatMap(NSImage.init(data:))
            state.loaded = true
        }
    }
}

enum ImagePreviewLayout {
    static func fit(_ image: CGSize, within available: CGSize) -> CGSize {
        guard image.width > 0, image.height > 0,
            image.width.isFinite, image.height.isFinite,
            available.width > 0, available.height > 0
        else { return .zero }
        let scale = min(available.width / image.width, available.height / image.height)
        return CGSize(width: image.width * scale, height: image.height * scale)
    }
}

struct AttachmentImagePreview: View {
    let file: ChatAttachment
    @ObservedObject var preview: ImagePreviewPresentation
    let dismiss: () -> Void
    @StateObject private var state = AttachmentViewState()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Button {
                    dismiss()
                } label: {
                    Color.black.opacity(0.82).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close image preview")
                if let image = state.image {
                    let size = ImagePreviewLayout.fit(
                        image.size,
                        within: CGSize(
                            width: geometry.size.width * 0.9, height: geometry.size.height * 0.9))
                    Image(nsImage: image).resizable().frame(width: size.width, height: size.height)
                        .background(HUD.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.7), radius: 24)
                        .onTapGesture {}  // Only the surrounding backdrop dismisses the preview.
                        .accessibilityLabel("Image preview")
                } else {
                    Text(state.loaded ? "Preview unavailable" : "Loading image…")
                        .foregroundStyle(HUD.text)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(PreviewKeyboard(dismiss: dismiss))
        .accessibilityAddTraits(.isModal)
        .help("Press Escape or click anywhere outside the image to close")
        .task(id: file.id) {
            let data = await preview.load(file, pixels: 3200)
            guard !Task.isCancelled else { return }
            state.image = data.flatMap(NSImage.init(data:))
            state.loaded = true
        }
    }
}

/// Give the lightbox keyboard focus so Escape works even when the composer had focus.
private struct PreviewKeyboard: NSViewRepresentable {
    let dismiss: () -> Void

    func makeNSView(context: Context) -> EscapeView {
        let view = EscapeView()
        view.dismiss = dismiss
        return view
    }

    func updateNSView(_ view: EscapeView, context: Context) { view.dismiss = dismiss }

    static func dismantleNSView(_ view: EscapeView, coordinator: ()) {
        if view.window?.firstResponder === view {
            view.window?.makeFirstResponder(view.previousResponder)
        }
    }

    final class EscapeView: NSView {
        var dismiss: (() -> Void)?
        weak var previousResponder: NSResponder?
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            previousResponder = window.firstResponder
            window.makeFirstResponder(self)
        }
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 { dismiss?() } else { super.keyDown(with: event) }
        }
    }
}
