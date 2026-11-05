import Foundation
import SwiftUI

/// Basic chat Markdown with local image previews; no HTML or automatic remote requests.
enum ChatMarkdown {
    enum Block: Equatable {
        case paragraph(String)
        case heading(Int, String)
        case list(String, String)
        case quote(String)
        case code(String)
        case image(ChatAttachment)
        case table(MarkdownTable)
    }

    static func blocks(_ text: String) -> [Block] {
        var result: [Block] = []
        var paragraph: [String] = []
        var code: [String] = []
        var fence: String?
        func flushParagraph() {
            if !paragraph.isEmpty { result.append(.paragraph(paragraph.joined(separator: "\n"))) }
            paragraph.removeAll()
        }
        let lines = text.components(separatedBy: .newlines)
        var index = 0
        while index < lines.count {
            let line = lines[index]
            index += 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let marker = fence {
                if trimmed.hasPrefix(marker) {
                    result.append(.code(code.joined(separator: "\n")))
                    code.removeAll(); fence = nil
                } else { code.append(line) }
                continue
            }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                flushParagraph(); fence = String(trimmed.prefix(3)); continue
            }
            if index < lines.count, let tableHeader = MarkdownTable.header(line, separator: lines[index]) {
                flushParagraph()
                index += 1
                var table = tableHeader
                while index < lines.count, let cells = MarkdownTable.cells(lines[index]) {
                    table.rows.append(Array((cells + Array(repeating: "", count: table.headers.count)).prefix(table.headers.count)))
                    index += 1
                }
                result.append(.table(table)); continue
            }
            if trimmed.isEmpty { flushParagraph(); continue }
            if let image = imageAttachment(trimmed) {
                flushParagraph(); result.append(.image(image)); continue
            }
            let headingLevel = trimmed.prefix(while: { $0 == "#" }).count
            if (1...6).contains(headingLevel), trimmed.dropFirst(headingLevel).first == " " {
                flushParagraph()
                result.append(.heading(headingLevel, String(trimmed.dropFirst(headingLevel + 1))))
            } else if ["- ", "* ", "+ "].contains(String(trimmed.prefix(2))) {
                flushParagraph(); result.append(.list("•", String(trimmed.dropFirst(2))))
            } else if let range = trimmed.range(of: #"^\d+[.)] "#, options: .regularExpression) {
                flushParagraph()
                result.append(.list(String(trimmed[range]).trimmingCharacters(in: .whitespaces),
                    String(trimmed[range.upperBound...])))
            } else if trimmed.hasPrefix("> ") {
                flushParagraph(); result.append(.quote(String(trimmed.dropFirst(2))))
            } else { paragraph.append(line) }
        }
        flushParagraph()
        if fence != nil { result.append(.code(code.joined(separator: "\n"))) }
        return result
    }

    private static func imageAttachment(_ line: String) -> ChatAttachment? {
        guard line.hasPrefix("!["), let split = line.range(of: "]("), line.hasSuffix(")") else { return nil }
        let label = String(line[line.index(line.startIndex, offsetBy: 2)..<split.lowerBound])
        var path = String(line[split.upperBound..<line.index(before: line.endIndex)])
        if path.hasPrefix("<"), path.hasSuffix(">") { path = String(path.dropFirst().dropLast()) }
        guard !path.isEmpty, path.count < 4096 else { return nil }
        return ChatAttachment(name: label.isEmpty ? "Image" : label, location: path)
    }

    static func inline(_ text: String) -> AttributedString {
        do {
            return try AttributedString(markdown: text,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        } catch { return AttributedString(text) }
    }
}

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
