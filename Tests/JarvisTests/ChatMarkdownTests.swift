import Foundation
import Testing

@testable import Jarvis

@Suite("Chat Markdown") struct ChatMarkdownTests {
    @Test func orderedListRequiresACompleteDelimiterCharacter() {
        for marker in ["12. ", "٤) "] {
            let line = marker + "\u{0301}item"
            #expect(ChatMarkdown.blocks(line) == [.paragraph(line)])
        }
        #expect(ChatMarkdown.blocks("12. item") == [.list("12.", "item")])
    }

    @Test func paragraphsAndLists() {
        #expect(
            ChatMarkdown.blocks("Done.\n\n- **Resize:** drag it\n- Refresh\n\n1. First\n2. Second")
                == [
                    .paragraph("Done."), .list("•", "**Resize:** drag it"), .list("•", "Refresh"),
                    .list("1.", "First"), .list("2.", "Second"),
                ])
    }

    @Test func literalCodeAndUnfinishedFence() {
        #expect(
            ChatMarkdown.blocks("```swift\n- **literal**\n```\n\n~~~\n# code") == [
                .code("- **literal**"), .code("# code"),
            ])
    }

    @Test func headingsQuotesAndOrdinarySymbols() {
        #expect(
            ChatMarkdown.blocks("## Title\n> A quote\n\n#hashtag\n2.5 euros\n\\* literal") == [
                .heading(2, "Title"), .quote("A quote"),
                .paragraph("#hashtag\n2.5 euros\n\\* literal"),
            ])
    }

    @Test func inlineFormattingRemovesMarkdownDelimiters() {
        let formatted = ChatMarkdown.inline("**Bold** and `code` and [a link](https://example.com)")
        #expect(String(formatted.characters) == "Bold and code and a link")
        let containsLink = formatted.runs.contains {
            $0[AttributeScopes.FoundationAttributes.LinkAttribute.self]?.absoluteString
                == "https://example.com"
        }
        #expect(containsLink)
    }
}
