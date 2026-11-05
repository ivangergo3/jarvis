import SwiftUI

struct MarkdownTable: Equatable {
    enum Alignment: Equatable { case leading, center, trailing }
    let headers: [String]
    let alignments: [Alignment]
    var rows: [[String]] = []

    /// Split outside inline code and preserve escaped pipes for the inline renderer.
    static func cells(_ line: String) -> [String]? {
        let characters = Array(line.trimmingCharacters(in: .whitespaces))
        var result: [String] = [], cell = ""
        var index = 0, codeTicks = 0, separators = 0
        while index < characters.count {
            let c = characters[index]
            if c == "\\", index + 1 < characters.count {
                cell.append(c); cell.append(characters[index + 1]); index += 2; continue
            }
            if c == "`" {
                var end = index
                while end < characters.count, characters[end] == "`" { end += 1 }
                let count = end - index
                if codeTicks == 0 { codeTicks = count } else if codeTicks == count { codeTicks = 0 }
                cell += String(repeating: "`", count: count); index = end; continue
            }
            if c == "|", codeTicks == 0 {
                result.append(cell.trimmingCharacters(in: .whitespaces)); cell = ""; separators += 1
            } else { cell.append(c) }
            index += 1
        }
        guard separators > 0 else { return nil }
        result.append(cell.trimmingCharacters(in: .whitespaces))
        if characters.first == "|" { result.removeFirst() }
        if characters.last == "|", result.last == "" { result.removeLast() }
        return result.isEmpty ? nil : result
    }

    static func header(_ line: String, separator: String) -> MarkdownTable? {
        guard let headers = cells(line), headers.count <= 32,
            let delimiters = cells(separator), delimiters.count == headers.count,
            delimiters.allSatisfy({ $0.range(of: #"^:?-{3,}:?$"#, options: .regularExpression) != nil })
        else { return nil }
        return MarkdownTable(headers: headers, alignments: delimiters.map {
            $0.hasSuffix(":") ? ($0.hasPrefix(":") ? .center : .trailing) : .leading
        })
    }
}

struct MarkdownTableView: View {
    let table: MarkdownTable
    private var widths: [CGFloat] {
        table.headers.indices.map { column in
            let count = ([table.headers] + table.rows).map { $0[column].count }.max() ?? 0
            return min(280, max(120, CGFloat(count) * 6))
        }
    }
    var body: some View {
        ScrollView(.horizontal) {
            VStack(spacing: 0) {
                row(table.headers, header: true)
                ForEach(table.rows.indices, id: \.self) { index in
                    row(table.rows[index], header: false)
                        .background(HUD.cyan.opacity(index.isMultiple(of: 2) ? 0.025 : 0.055))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(HUD.line))
        }
        .accessibilityLabel("Table, \(table.headers.count) columns, \(table.rows.count) rows")
    }
    private func row(_ cells: [String], header: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(table.headers.indices, id: \.self) { column in
                let alignment: SwiftUI.Alignment = table.alignments[column] == .trailing ? .trailing : table.alignments[column] == .center ? .center : .leading
                Text(ChatMarkdown.inline(cells[column]))
                    .font(.system(size: 13, weight: header ? .semibold : .regular))
                    .frame(width: widths[column], alignment: alignment)
                    .fixedSize(horizontal: false, vertical: true).padding(10)
            }
        }
        .background(header ? HUD.cyan.opacity(0.1) : .clear)
        .overlay(alignment: .bottom) { Rectangle().fill(HUD.line).frame(height: 0.5) }
    }
}
