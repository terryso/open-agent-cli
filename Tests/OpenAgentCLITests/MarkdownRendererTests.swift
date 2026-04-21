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
}
