import Testing
@testable import Jarvis

@Suite("Markdown tables") struct MarkdownTableTests {
    @Test func toolSummaryWithWrappedDescriptions() {
        let blocks = ChatMarkdown.blocks("Intro\n\n| Tool | What it does here |\n|---|---|\n| **Analytics** | Tracks consented product activity. |\n| **Errors** | Receives selected failures. |\n| **Collector** | Checks log freshness. |\n\nAfter")
        #expect(blocks.count == 3)
        guard case .table(let table) = blocks[1] else { Issue.record("Missing table"); return }
        #expect(table.headers == ["Tool", "What it does here"])
        #expect(table.rows.count == 3)
        #expect(table.rows[0][0] == "**Analytics**")
    }
    @Test func alignmentEscapesAndCodePipes() {
        let blocks = ChatMarkdown.blocks("A | B | C\n:--- | :---: | ---:\na\\|b | `x|y` | z\nshort | row")
        guard case .table(let table) = blocks.first else { Issue.record("Missing table"); return }
        #expect(table.alignments == [.leading, .center, .trailing])
        #expect(table.rows == [["a\\|b", "`x|y`", "z"], ["short", "row", ""]])
    }
    @Test func malformedAndFencedTablesStayLiteral() {
        #expect(ChatMarkdown.blocks("A | B\n-- | ---") == [.paragraph("A | B\n-- | ---")])
        #expect(ChatMarkdown.blocks("```\nA | B\n--- | ---\n```") == [.code("A | B\n--- | ---")])
    }
    @Test func sweepWrapsWithoutLosingLength() {
        for progress in [0.0, 0.05, 0.5, 0.99, 1.05] {
            let ranges = BorderSweep.ranges(progress: progress)
            #expect(abs(ranges.reduce(0) { $0 + $1.upperBound - $1.lowerBound } - 0.12) < 0.0001)
            #expect(ranges.allSatisfy { $0.lowerBound >= 0 && $0.upperBound <= 1 })
        }
        #expect(BorderSweep.ranges(progress: 0.5) != BorderSweep.ranges(progress: 0.7))
    }
}
