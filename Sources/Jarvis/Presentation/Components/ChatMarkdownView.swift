import SwiftUI

struct ChatMarkdownView: View, Equatable {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(ChatMarkdown.blocks(text).enumerated()), id: \.offset) { _, block in
                switch block {
                case .paragraph(let content):
                    inline(content)
                case .heading(let level, let content):
                    inline(content).font(.system(size: level <= 2 ? 17 : 14, weight: .semibold))
                case .list(let marker, let content):
                    HStack(alignment: .top, spacing: 8) {
                        Text(marker).monospacedDigit()
                        inline(content).frame(maxWidth: .infinity, alignment: .leading)
                    }
                case .quote(let content):
                    HStack(spacing: 10) {
                        Rectangle().fill(HUD.cyan).frame(width: 2)
                        inline(content).foregroundStyle(HUD.text)
                    }.fixedSize(horizontal: false, vertical: true)
                case .code(let content):
                    ScrollView(.horizontal) {
                        Text(verbatim: content).font(.system(size: 12, design: .monospaced))
                            .padding(10)
                    }.background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 6))
                case .table(let table):
                    MarkdownTableView(table: table)
                case .image(let file):
                    AttachmentTile(file: file).frame(maxWidth: 260)
                }
            }
        }
        .font(.system(size: 13)).foregroundStyle(.white).tint(HUD.cyan)
        .lineSpacing(3).textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inline(_ content: String) -> Text { Text(ChatMarkdown.inline(content)) }
}
