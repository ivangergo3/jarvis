import SwiftUI

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
                let alignment: SwiftUI.Alignment =
                    table.alignments[column] == .trailing
                    ? .trailing : table.alignments[column] == .center ? .center : .leading
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
