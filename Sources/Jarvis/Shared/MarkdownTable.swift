import Foundation

struct MarkdownTable: Equatable {
    enum Alignment: Equatable { case leading, center, trailing }
    let headers: [String]
    let alignments: [Alignment]
    var rows: [[String]] = []

    /// Split outside inline code and preserve escaped pipes for the inline renderer.
    static func cells(_ line: String) -> [String]? {
        let characters = Array(line.trimmingCharacters(in: .whitespaces))
        var result: [String] = []
        var cell = ""
        var index = 0
        var codeTicks = 0
        var separators = 0
        while index < characters.count {
            let c = characters[index]
            if c == "\\", index + 1 < characters.count {
                cell.append(c)
                cell.append(characters[index + 1])
                index += 2
                continue
            }
            if c == "`" {
                var end = index
                while end < characters.count, characters[end] == "`" { end += 1 }
                let count = end - index
                if codeTicks == 0 { codeTicks = count } else if codeTicks == count { codeTicks = 0 }
                cell += String(repeating: "`", count: count)
                index = end
                continue
            }
            if c == "|", codeTicks == 0 {
                result.append(cell.trimmingCharacters(in: .whitespaces))
                cell = ""
                separators += 1
            } else {
                cell.append(c)
            }
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
            delimiters.allSatisfy({
                $0.range(of: #"^:?-{3,}:?$"#, options: .regularExpression) != nil
            })
        else { return nil }
        return MarkdownTable(
            headers: headers,
            alignments: delimiters.map {
                $0.hasSuffix(":") ? ($0.hasPrefix(":") ? .center : .trailing) : .leading
            })
    }
}
