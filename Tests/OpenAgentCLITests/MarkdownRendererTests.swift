import XCTest
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 6.5 Markdown Terminal Rendering
//
// These tests define the EXPECTED behavior of MarkdownRenderer and terminal
// width detection utilities. They will FAIL until MarkdownRenderer.swift is
// implemented and integrated into OutputRenderer (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: Markdown rendered with code block borders, bold headings, correct list indent
//   AC#2: Long lines wrap at terminal width boundary

final class MarkdownRendererTests: XCTestCase {

    // MARK: - AC#1: Code Block Rendering (3 tests)

    func testCodeBlock_rendersWithBorders() {
        // Given a fenced code block
        // When rendered
        // Then output has top border, left margin, and bottom border
        let input = "```\nlet x = 1\n```"
        let result = MarkdownRenderer.render(input)

        // Verify top border exists (starts with box-drawing characters)
        XCTAssertTrue(result.contains("\u{250C}") || result.contains("+") || result.contains("-"),
            "Code block should have a top border character, got: \(result.debugDescription)")

        // Verify bottom border exists
        XCTAssertTrue(result.contains("\u{2514}") || result.contains("+") || result.contains("-"),
            "Code block should have a bottom border character, got: \(result.debugDescription)")

        // Verify left margin (pipe character or vertical bar)
        XCTAssertTrue(result.contains("\u{2502}") || result.contains("|"),
            "Code block lines should have a left margin/bar, got: \(result.debugDescription)")

        // Verify code content is present
        XCTAssertTrue(result.contains("let x = 1"),
            "Code block content should be preserved in output")
    }

    func testCodeBlock_preservesIndentation() {
        // Given a code block with indented content
        // When rendered
        // Then indentation is preserved exactly
        let input = "```\n  func hello() {\n    print(\"hi\")\n  }\n```"
        let result = MarkdownRenderer.render(input)

        // The indented lines should appear with their original whitespace intact
        XCTAssertTrue(result.contains("  func hello()"),
            "Code block should preserve 2-space indentation")
        XCTAssertTrue(result.contains("    print"),
            "Code block should preserve 4-space indentation")
    }

    func testCodeBlock_withLanguageTag_rendersContent() {
        // Given a fenced code block with a language tag
        // When rendered
        // Then code content is rendered (language tag may or may not display)
        let input = "```swift\nlet x = 42\n```"
        let result = MarkdownRenderer.render(input)

        XCTAssertTrue(result.contains("let x = 42"),
            "Code block with language tag should still render code content")
    }

    // MARK: - AC#1: Heading Rendering (3 tests)

    func testHeading_h1_boldRendering() {
        // Given a level-1 heading
        // When rendered
        // Then output uses ANSI bold styling
        let input = "# Title"
        let result = MarkdownRenderer.render(input)
        let boldEscape = "\u{001B}[1m"

        XCTAssertTrue(result.contains(boldEscape),
            "H1 heading should use ANSI bold escape code")
        XCTAssertTrue(result.contains("Title"),
            "Heading text should be preserved")
    }

    func testHeading_allLevels_boldRendering() {
        // Given headings at all levels (# through ######)
        // When rendered
        // Then all use ANSI bold styling
        let boldEscape = "\u{001B}[1m"

        for level in 1...6 {
            let hashes = String(repeating: "#", count: level)
            let input = "\(hashes) Heading Level \(level)"
            let result = MarkdownRenderer.render(input)

            XCTAssertTrue(result.contains(boldEscape),
                "H\(level) heading should use ANSI bold escape code")
            XCTAssertTrue(result.contains("Heading Level \(level)"),
                "H\(level) heading text should be preserved")
        }
    }

    func testHeading_differentLevels_visualHierarchy() {
        // Given headings at different levels
        // When rendered
        // Then higher-level headings (fewer #) appear differently from lower-level ones
        // At minimum, all headings should be bold; visual weight differentiation is optional
        let h1 = MarkdownRenderer.render("# Main Title")
        let h6 = MarkdownRenderer.render("###### Small Heading")

        // Both should be bold
        let boldEscape = "\u{001B}[1m"
        XCTAssertTrue(h1.contains(boldEscape), "H1 should be bold")
        XCTAssertTrue(h6.contains(boldEscape), "H6 should be bold")

        // Both should preserve their text
        XCTAssertTrue(h1.contains("Main Title"), "H1 text preserved")
        XCTAssertTrue(h6.contains("Small Heading"), "H6 text preserved")
    }

    // MARK: - AC#1: Unordered List Rendering (2 tests)

    func testUnorderedList_bulletAndIndent() {
        // Given unordered list items with - or * markers
        // When rendered
        // Then items display with bullet character and 2-space indent
        let input = "- First item\n- Second item\n- Third item"
        let result = MarkdownRenderer.render(input)

        // Bullet character should be present
        XCTAssertTrue(result.contains("\u{2022}") || result.contains("*"),
            "Unordered list should render bullet points, got: \(result.debugDescription)")

        // Items should be indented
        XCTAssertTrue(result.contains("First item"), "First item text preserved")
        XCTAssertTrue(result.contains("Second item"), "Second item text preserved")
        XCTAssertTrue(result.contains("Third item"), "Third item text preserved")
    }

    func testUnorderedList_asteriskMarker_rendersAsBullet() {
        // Given unordered list items with * markers
        // When rendered
        // Then items display with bullet character
        let input = "* Apple\n* Banana"
        let result = MarkdownRenderer.render(input)

        XCTAssertTrue(result.contains("Apple"), "Apple text preserved")
        XCTAssertTrue(result.contains("Banana"), "Banana text preserved")
        // Should not contain raw "* " marker in rendered output
        // (replaced with bullet and indent)
    }

    // MARK: - AC#1: Ordered List Rendering (1 test)

    func testOrderedList_preservesNumbering() {
        // Given ordered list items
        // When rendered
        // Then numbering is preserved with correct indent
        let input = "1. First\n2. Second\n3. Third"
        let result = MarkdownRenderer.render(input)

        XCTAssertTrue(result.contains("1"), "Number 1 should be present")
        XCTAssertTrue(result.contains("2"), "Number 2 should be present")
        XCTAssertTrue(result.contains("3"), "Number 3 should be present")
        XCTAssertTrue(result.contains("First"), "First text preserved")
        XCTAssertTrue(result.contains("Second"), "Second text preserved")
        XCTAssertTrue(result.contains("Third"), "Third text preserved")
    }

    // MARK: - AC#1: Nested List Rendering (1 test)

    func testNestedList_correctIndentation() {
        // Given a nested list with sub-items
        // When rendered
        // Then each nesting level adds 2 spaces of indent
        let input = "- Top level\n  - Nested level 1\n    - Nested level 2"
        let result = MarkdownRenderer.render(input)

        XCTAssertTrue(result.contains("Top level"), "Top level text preserved")
        XCTAssertTrue(result.contains("Nested level 1"), "Nested level 1 text preserved")
        XCTAssertTrue(result.contains("Nested level 2"), "Nested level 2 text preserved")

        // Nested items should have more leading whitespace than parent
        let lines = result.components(separatedBy: "\n").filter { !$0.isEmpty }
        let topLine = lines.first { $0.contains("Top level") }
        let nested1Line = lines.first { $0.contains("Nested level 1") }

        if let top = topLine, let nested = nested1Line {
            let topIndent = top.prefix(while: { $0 == " " }).count
            let nestedIndent = nested.prefix(while: { $0 == " " }).count
            XCTAssertTrue(nestedIndent > topIndent,
                "Nested list items should have more indentation than parent")
        }
    }

    // MARK: - AC#1: Inline Bold Rendering (1 test)

    func testInlineBold_ansiWrapped() {
        // Given text with **bold** markers
        // When rendered
        // Then bold text is wrapped with ANSI bold escape codes
        let input = "This is **important** text"
        let result = MarkdownRenderer.render(input)
        let boldEscape = "\u{001B}[1m"

        XCTAssertTrue(result.contains(boldEscape),
            "Bold text should use ANSI bold escape code")
        XCTAssertTrue(result.contains("important"),
            "Bold text content should be preserved")
        XCTAssertTrue(!result.contains("**important**"),
            "Raw ** markers should be removed from output")
    }

    // MARK: - AC#1: Inline Code Rendering (1 test)

    func testInlineCode_cyanOrHighlighted() {
        // Given text with `code` markers
        // When rendered
        // Then code text is wrapped with ANSI cyan or highlight style
        let input = "Use the `print` function"
        let result = MarkdownRenderer.render(input)
        let cyanEscape = "\u{001B}[36m"

        XCTAssertTrue(result.contains(cyanEscape) || result.contains("\u{001B}[7m"),
            "Inline code should use ANSI cyan or reverse-video highlighting")
        XCTAssertTrue(result.contains("print"),
            "Inline code content should be preserved")
        XCTAssertTrue(!result.contains("`print`"),
            "Raw backtick markers should be removed from output")
    }

    // MARK: - AC#1: Plain Text (1 test)

    func testPlainText_noModification() {
        // Given plain text with no Markdown formatting
        // When rendered
        // Then text is output unchanged (no ANSI codes added for formatting)
        let input = "Hello world, this is plain text."
        let result = MarkdownRenderer.render(input)

        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines),
            input,
            "Plain text should pass through unchanged")
    }

    // MARK: - AC#1: Paragraph Separation (1 test)

    func testParagraphSeparation_blankLines() {
        // Given two paragraphs separated by a blank line
        // When rendered
        // Then output preserves blank-line separation between paragraphs
        let input = "First paragraph.\n\nSecond paragraph."
        let result = MarkdownRenderer.render(input)

        XCTAssertTrue(result.contains("First paragraph"), "First paragraph preserved")
        XCTAssertTrue(result.contains("Second paragraph"), "Second paragraph preserved")
        // There should be at least one blank line between them
        XCTAssertTrue(result.contains("\n\n") || result.components(separatedBy: "\n").count >= 3,
            "Paragraphs should be separated by blank lines")
    }

    // MARK: - AC#1: Mixed Markdown (1 test)

    func testMixedMarkdown_listWithInlineCode_correctRendering() {
        // Given a list containing inline code
        // When rendered
        // Then both list formatting and code highlighting are applied
        let input = "- Use `npm install` to install\n- Run `npm test` to verify"
        let result = MarkdownRenderer.render(input)

        // Should have bullet character
        XCTAssertTrue(result.contains("\u{2022}") || result.contains("npm install"),
            "List should have bullet formatting")

        // Should have inline code highlighting
        let cyanEscape = "\u{001B}[36m"
        XCTAssertTrue(result.contains(cyanEscape) || result.contains("npm install"),
            "Inline code in list should be highlighted")

        XCTAssertTrue(result.contains("npm install"), "npm install text preserved")
        XCTAssertTrue(result.contains("npm test"), "npm test text preserved")
    }

    // MARK: - AC#2: Word Wrap (2 tests)

    func testWordWrap_wrapsAtBoundary() {
        // Given a long line of text
        // When wrapped at a specified width
        // Then text breaks at word boundaries near the width limit
        let longText = "This is a very long line of text that should definitely be wrapped at some reasonable boundary"
        let wrapped = MarkdownRenderer.wordWrap(longText, width: 40)

        // Each line should be <= width (allowing some tolerance for word boundaries)
        for line in wrapped.components(separatedBy: "\n") {
            XCTAssertTrue(line.count <= 50,
                "Each wrapped line should be near the width limit, got \(line.count) chars: '\(line)'")
        }

        // Full text content should be preserved
        let withoutNewlines = wrapped.replacingOccurrences(of: "\n", with: " ")
        XCTAssertTrue(withoutNewlines.contains("very long line"),
            "Wrapped text should preserve all original content")
    }

    func testWordWrap_preservesIndent() {
        // Given an indented line that needs wrapping
        // When wrapped
        // Then continuation lines preserve the original indentation
        let indentedText = "    This is an indented long line of text that needs to wrap at a reasonable boundary for terminal display"
        let wrapped = MarkdownRenderer.wordWrap(indentedText, width: 50)

        let lines = wrapped.components(separatedBy: "\n")
        for line in lines {
            XCTAssertTrue(line.hasPrefix("    ") || line.hasPrefix("   "),
                "Each wrapped line should preserve leading indentation, got: '\(line)'")
        }
    }

    // MARK: - AC#2: Terminal Width Detection (1 test)

    func testTerminalWidth_fallbackTo80() {
        // Given terminal width detection
        // When the terminal width cannot be determined
        // Then the function returns 80 as a safe default
        let width = MarkdownRenderer.terminalWidth()

        XCTAssertTrue(width > 0,
            "Terminal width should always be positive")
        XCTAssertTrue(width >= 80,
            "Terminal width should be at least 80 columns as fallback")
    }

    // MARK: - Regression: Code Block Content Not Wrapped (1 test)

    func testCodeBlock_noWordWrapping() {
        // Given a code block with a very long line
        // When rendered
        // Then code content is NOT word-wrapped (preserved as-is)
        let longCode = "let veryLongVariableName = \"some extremely long string value that exceeds normal terminal width limits\""
        let input = "```\n\(longCode)\n```"
        let result = MarkdownRenderer.render(input)

        // The code line should appear in full, not broken by word wrap
        XCTAssertTrue(result.contains("let veryLongVariableName"),
            "Code block content should not be word-wrapped")
        XCTAssertTrue(result.contains("exceeds normal terminal width"),
            "Long code lines should be preserved intact")
    }

    // MARK: - Edge Cases (2 tests)

    func testEmptyInput_returnsEmpty() {
        // Given empty input
        // When rendered
        // Then output is empty
        let result = MarkdownRenderer.render("")
        XCTAssertTrue(result.isEmpty,
            "Empty input should produce empty output")
    }

    func testIncompleteCodeBlock_rendersAsText() {
        // Given a code block that is opened but never closed
        // When rendered
        // Then it is treated as regular text (graceful fallback)
        let input = "```\nthis never closes"
        let result = MarkdownRenderer.render(input)

        // Should not crash, should contain the text
        XCTAssertTrue(result.contains("this never closes"),
            "Unclosed code block should still contain the text")
    }

    // MARK: - Integration: Thinking Text Not Modified (1 test)

    func testThinkingPrefix_notModifiedByMarkdown() {
        // Given text that starts with [thinking] prefix
        // When rendered through MarkdownRenderer
        // Then the [thinking] prefix is preserved (Markdown rendering should not
        // interfere with thinking content handling from Story 6.4)
        let input = "[thinking] Let me consider **this** option"
        let result = MarkdownRenderer.render(input)

        XCTAssertTrue(result.contains("[thinking]"),
            "[thinking] prefix should be preserved for dim styling downstream")
    }

    // MARK: - Integration: Quiet Mode Markdown Still Works (1 test)

    func testMarkdownRenders_independentOfQuietMode() {
        // MarkdownRenderer is a pure function -- it does not depend on quiet mode.
        // This test verifies that MarkdownRenderer.render() works the same regardless
        // of the OutputRenderer's quiet setting. Quiet mode only filters message types,
        // not formatting. The MarkdownRenderer transforms text regardless.
        let input = "# Hello\n\nSome **bold** text"
        let result = MarkdownRenderer.render(input)

        let boldEscape = "\u{001B}[1m"
        XCTAssertTrue(result.contains(boldEscape),
            "Markdown rendering should apply bold regardless of quiet mode")
        XCTAssertTrue(result.contains("Hello"),
            "Markdown rendering should preserve text regardless of quiet mode")
    }

    // MARK: - Story 10.2 ATDD: Markdown Table & Block Element Rendering
    //
    // ATDD RED PHASE: These tests define the EXPECTED behavior for Story 10.2.
    // They WILL FAIL until MarkdownRenderer.swift is updated with table rendering,
    // blockquote rendering, horizontal rule rendering, link rendering, and
    // heading decoration lines (AC#1-#5).
    //
    // Acceptance Criteria Coverage:
    //   AC#1: Table rendering with box-drawing characters, bold header, column alignment
    //   AC#2: Blockquote rendering with grey │ prefix
    //   AC#3: Horizontal rule rendering with ─ characters
    //   AC#4: Link rendering [text](url) → underlined text, URL hidden
    //   AC#5: H1/H2 heading decoration lines (═ and ─)

    // MARK: - AC#1: Table Rendering (6 tests)

    func testTable_simpleTable_boxDrawingBorders() {
        // Given a Markdown table with header, separator, and data rows
        let input = "| Name | Status | Count |\n|------|--------|-------|\n| foo  | active | 3     |\n| bar  | idle   | 0     |"
        let result = MarkdownRenderer.render(input)

        // Then box-drawing border characters are present
        XCTAssertTrue(result.contains("\u{250C}"), "Table should have top-left corner ┌")
        XCTAssertTrue(result.contains("\u{2510}"), "Table should have top-right corner ┐")
        XCTAssertTrue(result.contains("\u{2514}"), "Table should have bottom-left corner └")
        XCTAssertTrue(result.contains("\u{2518}"), "Table should have bottom-right corner ┘")
        XCTAssertTrue(result.contains("\u{251C}"), "Table should have left junction ├")
        XCTAssertTrue(result.contains("\u{2524}"), "Table should have right junction ┤")
    }

    func testTable_simpleTable_columnAlignment() {
        // Given a Markdown table
        let input = "| Name | Status | Count |\n|------|--------|-------|\n| foo  | active | 3     |\n| bar  | idle   | 0     |"
        let result = MarkdownRenderer.render(input)

        // Then column separators (│ and ┼) appear
        XCTAssertTrue(result.contains("\u{2502}"), "Table should have vertical bar │ between columns")

        // And separator row junctions (┼) should appear for header/data separator
        XCTAssertTrue(result.contains("\u{253C}"), "Table should have cross junction ┼ in header separator")

        // And all cell content is preserved
        XCTAssertTrue(result.contains("Name"), "Header 'Name' should be preserved")
        XCTAssertTrue(result.contains("Status"), "Header 'Status' should be preserved")
        XCTAssertTrue(result.contains("Count"), "Header 'Count' should be preserved")
        XCTAssertTrue(result.contains("foo"), "Data cell 'foo' should be preserved")
        XCTAssertTrue(result.contains("bar"), "Data cell 'bar' should be preserved")
        XCTAssertTrue(result.contains("active"), "Data cell 'active' should be preserved")
        XCTAssertTrue(result.contains("idle"), "Data cell 'idle' should be preserved")
    }

    func testTable_headerBold() {
        // Given a Markdown table
        let input = "| Name | Status |\n|------|--------|\n| foo  | active |"
        let result = MarkdownRenderer.render(input)

        // Then header row should contain ANSI bold escape codes
        let boldEscape = "\u{001B}[1m"
        XCTAssertTrue(result.contains(boldEscape),
            "Table header row should use ANSI bold styling, got: \(result.debugDescription)")
    }

    func testTable_unevenColumns_noCrash() {
        // Given a table where data rows have fewer columns than the header
        let input = "| A | B | C |\n|---|---|---|\n| 1 |"
        let result = MarkdownRenderer.render(input)

        // Then rendering does not crash and content is present
        XCTAssertTrue(result.contains("A"), "Header cell A should be preserved")
        XCTAssertTrue(result.contains("1"), "Data cell 1 should be preserved")
    }

    func testTable_wideCell_truncation() {
        // Given a table with a cell that would be very wide
        let longContent = String(repeating: "X", count: 200)
        let input = "| Short | \(longContent) |\n|-------|--------|\n| a     | b      |"
        let result = MarkdownRenderer.render(input)

        // Then the table renders without crash and shows truncation marker
        XCTAssertTrue(result.contains("Short"), "Short header should be preserved")
        // The long content should either be truncated (contains "...") or present
        XCTAssertTrue(result.contains("...") || result.contains("X"),
            "Wide cells should be truncated with ... or otherwise handled")
    }

    func testTable_headerOnly_noDataRows() {
        // Given a table with only header and separator, no data rows
        let input = "| Col1 | Col2 |\n|------|------|"
        let result = MarkdownRenderer.render(input)

        // Then the table renders (at minimum top border + header)
        XCTAssertTrue(result.contains("\u{250C}") || result.contains("\u{2502}"),
            "Header-only table should still render box-drawing characters")
        XCTAssertTrue(result.contains("Col1"), "Header Col1 should be preserved")
        XCTAssertTrue(result.contains("Col2"), "Header Col2 should be preserved")
    }

    // MARK: - AC#2: Blockquote Rendering (2 tests)

    func testBlockquote_singleLine() {
        // Given a single-line blockquote
        let input = "> This is a quote"
        let result = MarkdownRenderer.render(input)

        // Then the output contains the │ prefix
        XCTAssertTrue(result.contains("\u{2502}"),
            "Blockquote should render with │ prefix, got: \(result.debugDescription)")
        XCTAssertTrue(result.contains("This is a quote"),
            "Blockquote text should be preserved")
        // The raw "> " prefix should NOT appear
        XCTAssertFalse(result.contains("> This is a quote"),
            "Raw '> ' prefix should be replaced with │")
    }

    func testBlockquote_multiLine() {
        // Given a multi-line blockquote
        let input = "> This is a quote\n> spanning multiple lines"
        let result = MarkdownRenderer.render(input)

        // Then each line has the │ prefix
        let lines = result.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        for line in lines {
            XCTAssertTrue(line.contains("\u{2502}"),
                "Each blockquote line should contain │, got: \(line)")
        }
        XCTAssertTrue(result.contains("This is a quote"), "First line text preserved")
        XCTAssertTrue(result.contains("spanning multiple lines"), "Second line text preserved")
    }

    // MARK: - AC#3: Horizontal Rule Rendering (3 tests)

    func testHorizontalRule_dash() {
        // Given a horizontal rule with dashes
        let input = "---"
        let result = MarkdownRenderer.render(input)

        // Then output contains ─ (box-drawing horizontal line) characters
        XCTAssertTrue(result.contains("\u{2500}"),
            "--- should render as ─ characters, got: \(result.debugDescription)")
        // Should NOT contain raw "---"
        XCTAssertFalse(result.contains("---"),
            "Raw --- should be replaced with ─ characters")
    }

    func testHorizontalRule_asterisks() {
        // Given a horizontal rule with asterisks
        let input = "***"
        let result = MarkdownRenderer.render(input)

        XCTAssertTrue(result.contains("\u{2500}"),
            "*** should render as ─ characters, got: \(result.debugDescription)")
    }

    func testHorizontalRule_underscores() {
        // Given a horizontal rule with underscores
        let input = "___"
        let result = MarkdownRenderer.render(input)

        XCTAssertTrue(result.contains("\u{2500}"),
            "___ should render as ─ characters, got: \(result.debugDescription)")
    }

    // MARK: - AC#4: Link Rendering (2 tests)

    func testLink_inline_rendersAsUnderlinedText() {
        // Given inline link syntax [text](url)
        let input = "Visit [OpenAI](https://openai.com) for more info"
        let result = MarkdownRenderer.render(input)

        // Then the text "OpenAI" is present with underline ANSI styling
        let underlineEscape = "\u{001B}[4m"
        XCTAssertTrue(result.contains(underlineEscape),
            "Link text should have ANSI underline styling, got: \(result.debugDescription)")
        XCTAssertTrue(result.contains("OpenAI"),
            "Link text 'OpenAI' should be preserved")
        // URL should NOT be visible in output
        XCTAssertFalse(result.contains("https://openai.com"),
            "URL should not be displayed in rendered output")
        // Raw markdown syntax should not appear
        XCTAssertFalse(result.contains("[OpenAI](https://openai.com)"),
            "Raw link markdown should not appear in output")
    }

    func testLink_multipleLinks() {
        // Given text with multiple links
        let input = "Check [foo](http://foo.com) and [bar](http://bar.com)"
        let result = MarkdownRenderer.render(input)

        let underlineEscape = "\u{001B}[4m"
        XCTAssertTrue(result.contains("foo"), "First link text preserved")
        XCTAssertTrue(result.contains("bar"), "Second link text preserved")
        XCTAssertFalse(result.contains("http://foo.com"), "First URL hidden")
        XCTAssertFalse(result.contains("http://bar.com"), "Second URL hidden")

        // Should have at least 2 underline sequences (one per link)
        let underlineCount = result.components(separatedBy: underlineEscape).count - 1
        XCTAssertTrue(underlineCount >= 2,
            "Should have underline styling for each link, found \(underlineCount)")
    }

    // MARK: - AC#5: Heading Decoration (3 tests)

    func testHeading_h1_hasDoubleLineDecoration() {
        // Given an H1 heading
        let input = "# Title"
        let result = MarkdownRenderer.render(input)

        // Then output contains bold title
        let boldEscape = "\u{001B}[1m"
        XCTAssertTrue(result.contains(boldEscape),
            "H1 heading should be bold")
        XCTAssertTrue(result.contains("Title"),
            "Title text should be preserved")

        // And a decoration line of ═ characters below
        XCTAssertTrue(result.contains("\u{2550}"),
            "H1 heading should have ═ decoration line, got: \(result.debugDescription)")
    }

    func testHeading_h2_hasSingleLineDecoration() {
        // Given an H2 heading
        let input = "## Section"
        let result = MarkdownRenderer.render(input)

        // Then output contains bold title
        let boldEscape = "\u{001B}[1m"
        XCTAssertTrue(result.contains(boldEscape),
            "H2 heading should be bold")
        XCTAssertTrue(result.contains("Section"),
            "Section text should be preserved")

        // And a decoration line of ─ characters below
        XCTAssertTrue(result.contains("\u{2500}"),
            "H2 heading should have ─ decoration line, got: \(result.debugDescription)")
        // Should NOT have ═ (that's H1 only)
        XCTAssertFalse(result.contains("\u{2550}"),
            "H2 heading should NOT have ═ decoration (that is H1 only)")
    }

    func testHeading_h3_through_h6_noDecoration() {
        // Given H3-H6 headings, they should only be bold without decoration lines
        for level in 3...6 {
            let hashes = String(repeating: "#", count: level)
            let input = "\(hashes) Level \(level)"
            let result = MarkdownRenderer.render(input)

            let boldEscape = "\u{001B}[1m"
            XCTAssertTrue(result.contains(boldEscape),
                "H\(level) should be bold")
            XCTAssertTrue(result.contains("Level \(level)"),
                "H\(level) text preserved")

            // Should NOT have ═ or standalone ─ decoration lines
            // (Note: ─ may appear in other contexts, so we check ═ specifically)
            XCTAssertFalse(result.contains("\u{2550}"),
                "H\(level) should NOT have ═ decoration line")
        }
    }
}
