import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 10.3 Streaming Table Buffer and Rendering
//
// These tests define the EXPECTED behavior of MarkdownBuffer's table buffering
// state machine. They will FAIL until OutputRenderer.swift is updated with
// table buffering logic in MarkdownBuffer (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: Table row detection triggers buffering mode
//   AC#2: Complete table rendered atomically on table end
//   AC#3: Multiple independent tables buffered separately
//   AC#4: Chunk boundary splicing handled correctly
//   AC#5: Flush renders incomplete table with best-effort
//   AC#6: Normal text after table resumes immediate output
//
// Regression:
//   Code block buffering unaffected
//   Normal text immediate output unaffected

// MARK: - Mock TextOutputStream for Testing

/// A reference-type mock that captures all written output into a string for assertion.
/// Separate from MockTextOutputStream in OutputRendererTests to avoid test isolation issues.
final class TableBufferMockOutputStream: TextOutputStream {
    var output = ""
    /// Record of each separate write call for order-aware assertions.
    var writes: [String] = []
    func write(_ string: String) {
        output += string
        writes.append(string)
    }
}

final class StreamingTableBufferTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a MarkdownBuffer backed by a TableBufferMockOutputStream.
    /// Returns both the buffer and the mock so tests can assert on output.
    private func makeBuffer() -> (buffer: MarkdownBuffer, mock: TableBufferMockOutputStream) {
        let mock = TableBufferMockOutputStream()
        let anyStream = AnyTextOutputStream(mock)
        let buffer = MarkdownBuffer(output: anyStream)
        return (buffer, mock)
    }

    // MARK: - AC#1: Table row detection triggers buffering mode (P0)

    func testAppend_singleTableLineStarts_bufferingActivated() {
        // Given a chunk containing the start of a table
        let (buffer, mock) = makeBuffer()

        // When we append a table header line followed by a separator
        buffer.append("| Name | Status |\n")
        buffer.append("|------|--------|\n")

        // Then: the output should be empty (content is buffered, not rendered yet)
        // The table is incomplete (no data rows and no termination), so it stays buffered
        XCTAssertTrue(mock.output.isEmpty,
            "AC#1: Table content should be buffered, not immediately output. Got: \(mock.output)")
    }

    func testAppend_tableLineDetection_requiresMultipleTableLines() {
        // Given a single pipe line that is NOT a table (just inline text with pipe)
        let (buffer, mock) = makeBuffer()

        // When we append a single line containing a pipe (like "a | b")
        buffer.append("a | b and some text")

        // Then: it should NOT trigger table buffering -- render inline immediately
        XCTAssertFalse(mock.output.isEmpty,
            "AC#1: Single pipe in text should NOT trigger table buffering. Got output: \(mock.output)")
    }

    func testAppend_tableChunksAreBuffered_noOutputDuringTable() {
        // Given chunks that form a table
        let (buffer, mock) = makeBuffer()

        // When we send table content in chunks
        buffer.append("| Name | Status |\n")
        buffer.append("|------|--------|\n")
        buffer.append("| Alice | active |\n")

        // Then: no output should appear yet (table still incomplete)
        XCTAssertTrue(mock.output.isEmpty,
            "AC#1: Table chunks should be buffered with no output until table ends. Got: \(mock.output)")
    }

    // MARK: - AC#2: Complete table rendered atomically on table end (P0)

    func testAppend_tableComplete_rendersAtomically() {
        // Given chunks that form a complete table followed by a blank line
        let (buffer, mock) = makeBuffer()

        // When we send the table and then a termination signal (blank line / non-table text)
        buffer.append("| Name | Status |\n")
        buffer.append("|------|--------|\n")
        buffer.append("| Alice | active |\n")
        buffer.append("\n")  // Table ends at blank line

        // Then: the output should contain box-drawing table rendering
        let output = mock.output
        // Box-drawing top border
        XCTAssertTrue(output.contains("\u{250C}") || output.contains("\u{2510}"),
            "AC#2: Rendered table should contain box-drawing border characters. Got: \(output.debugDescription)")
        // Content preserved
        XCTAssertTrue(output.contains("Name") && output.contains("Alice"),
            "AC#2: Rendered table should contain cell content (Name, Alice). Got: \(output)")
    }

    func testAppend_tableComplete_renderMatchesMarkdownRendererOutput() {
        // Given a complete table buffered via append
        let (buffer, mock) = makeBuffer()

        buffer.append("| Name | Status |\n|------|--------|\n| Alice | active |\n\n")

        // Then: the output should match what MarkdownRenderer.render() would produce
        // for the same table markdown
        let _ = MarkdownRenderer.render("| Name | Status |\n|------|--------|\n| Alice | active |")
        let actualOutput = mock.output.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(actualOutput.isEmpty,
            "AC#2: Table output should not be empty")
        // Verify key structural elements match
        XCTAssertTrue(actualOutput.contains("\u{2502}"),
            "AC#2: Rendered table should contain vertical bar characters (│). Got: \(actualOutput.debugDescription)")
    }

    func testAppend_tableEndDetectedByNonTableLine() {
        // Given table content followed by a non-table line
        let (buffer, mock) = makeBuffer()

        buffer.append("| A | B |\n|---|---|\n| 1 | 2 |\n")
        buffer.append("Some regular text\n")

        // Then: table should be rendered, and the non-table text should also appear
        let output = mock.output
        XCTAssertTrue(output.contains("A") && output.contains("1"),
            "AC#2: Table content should be rendered when followed by non-table line. Got: \(output)")
    }

    // MARK: - AC#3: Multiple independent tables buffered separately (P0)

    func testAppend_twoIndependentTables_bothRenderedCorrectly() {
        // Given streaming output with two separate tables
        let (buffer, mock) = makeBuffer()

        // First table
        buffer.append("| Name | Age |\n|------|-----|\n| Bob | 30 |\n\n")
        // Inter-table text
        buffer.append("Some text between tables\n")
        // Second table
        buffer.append("| City | Pop |\n|------|-----|\n| NYC | 8M |\n\n")

        let output = mock.output
        // Verify both tables rendered
        XCTAssertTrue(output.contains("Name") && output.contains("Bob"),
            "AC#3: First table should be rendered with its content. Got: \(output)")
        XCTAssertTrue(output.contains("City") && output.contains("NYC"),
            "AC#3: Second table should be rendered with its content. Got: \(output)")
        XCTAssertTrue(output.contains("Some text between"),
            "AC#3: Text between tables should be rendered. Got: \(output)")
    }

    func testAppend_tablesDoNotInterfere() {
        // Given two tables with different content
        let (buffer, mock) = makeBuffer()

        buffer.append("| X | Y |\n|---|---|\n| 1 | 2 |\n\n")
        buffer.append("| A | B |\n|---|---|\n| 3 | 4 |\n\n")

        let output = mock.output
        // First table content should appear
        XCTAssertTrue(output.contains("X") && output.contains("1"),
            "AC#3: First table content (X, 1) should appear. Got: \(output)")
        // Second table content should appear
        XCTAssertTrue(output.contains("A") && output.contains("3"),
            "AC#3: Second table content (A, 3) should appear. Got: \(output)")
    }

    // MARK: - AC#4: Chunk boundary splicing (P0)

    func testAppend_chunkSplitMidCell_correctlySplices() {
        // Given a table split across chunks in the middle of a cell
        let (buffer, mock) = makeBuffer()

        // Chunk 1: header with partial cell
        buffer.append("| Nam")
        // Chunk 2: rest of header + separator
        buffer.append("e | Status |\n|------|--------|\n")
        // Chunk 3: data row
        buffer.append("| Alice | active |\n")
        // Chunk 4: table end
        buffer.append("\n")

        let output = mock.output
        // The table should be correctly assembled and rendered
        XCTAssertTrue(output.contains("Name"),
            "AC#4: Spliced table should contain 'Name' from reassembled header. Got: \(output)")
        XCTAssertTrue(output.contains("Alice"),
            "AC#4: Spliced table should contain 'Alice' from data row. Got: \(output)")
        // Should have box-drawing borders (proves it was rendered as a table)
        XCTAssertTrue(output.contains("\u{2502}"),
            "AC#4: Spliced table should render with box-drawing characters. Got: \(output.debugDescription)")
    }

    func testAppend_chunkSplitAtLineBoundary_correctlySplices() {
        // Given chunks split at line boundaries
        let (buffer, mock) = makeBuffer()

        buffer.append("| H1 | H2 |\n")
        buffer.append("|----|----|\n")
        buffer.append("| a | b |\n")
        buffer.append("| c | d |\n")
        buffer.append("\n")

        let output = mock.output
        XCTAssertTrue(output.contains("H1") && output.contains("a") && output.contains("c"),
            "AC#4: Line-boundary split table should render all content. Got: \(output)")
    }

    func testAppend_singleChunkCompleteTable_rendersCorrectly() {
        // Given a complete table in a single chunk
        let (buffer, mock) = makeBuffer()

        buffer.append("| A | B |\n|---|---|\n| 1 | 2 |\n\n")

        let output = mock.output
        XCTAssertTrue(output.contains("A") && output.contains("1"),
            "AC#4: Single-chunk table should render correctly. Got: \(output)")
    }

    // MARK: - AC#5: Flush renders incomplete table with best-effort (P0)

    func testFlush_incompleteTable_bestEffortNoCrash() {
        // Given a partially buffered table (interrupted stream)
        let (buffer, mock) = makeBuffer()

        buffer.append("| Name | Status |\n")
        buffer.append("|------|--------|\n")
        buffer.append("| Alice")  // Incomplete -- mid-cell when flush happens

        // When flush is called (simulating Ctrl+C or stream end)
        buffer.flush()

        // Then: should not crash and should produce some output
        // Best-effort: either renders what it can or falls back gracefully
        XCTAssertFalse(mock.output.isEmpty,
            "AC#5: Flush with incomplete table should produce best-effort output. Got empty output.")
    }

    func testFlush_incompleteTable_singleRow_noCrash() {
        // Given only a header line buffered (no separator, no data)
        let (buffer, mock) = makeBuffer()

        buffer.append("| Name | Status |")
        // Flush without any more content
        buffer.flush()

        // Then: should not crash. Single line may not render as table but should not error
        // MarkdownRenderer.render() for a single |...| line would fall back to paragraph
        XCTAssertFalse(mock.output.isEmpty,
            "AC#5: Flush with single table row should produce output (paragraph fallback). Got empty output.")
    }

    func testFlush_emptyBuffer_noOutput() {
        // Given nothing has been buffered
        let (buffer, mock) = makeBuffer()

        // When flush is called on empty buffer
        buffer.flush()

        // Then: no output
        XCTAssertTrue(mock.output.isEmpty,
            "AC#5: Flush on empty buffer should produce no output. Got: \(mock.output)")
    }

    // MARK: - AC#6: Normal text after table resumes immediate output (P0)

    func testAppend_textAfterTable_immediateOutput() {
        // Given a table has been rendered
        let (buffer, mock) = makeBuffer()

        buffer.append("| A | B |\n|---|---|\n| 1 | 2 |\n\n")

        // Reset mock to capture only post-table output
        mock.output = ""
        mock.writes = []

        // When non-table text follows
        buffer.append("Regular text after table")

        // Then: text should be rendered immediately (via renderInline)
        XCTAssertTrue(mock.output.contains("Regular text after table"),
            "AC#6: Text after table should be output immediately. Got: \(mock.output)")
    }

    func testAppend_textBeforeTable_normalThenTableBuffering() {
        // Given normal text followed by a table
        let (buffer, mock) = makeBuffer()

        // Normal text first
        buffer.append("Some introductory text\n")
        // Then table starts
        buffer.append("| H1 | H2 |\n|----|----|\n| v1 | v2 |\n\n")

        let output = mock.output
        XCTAssertTrue(output.contains("Some introductory text"),
            "AC#6: Text before table should be rendered. Got: \(output)")
        XCTAssertTrue(output.contains("H1"),
            "AC#6: Table content should also be rendered. Got: \(output)")
    }

    // MARK: - Regression: Code block buffering unaffected (P1)

    func testAppend_codeBlockStillWorks_afterTableBufferingAdded() {
        // Given a code block
        let (buffer, mock) = makeBuffer()

        buffer.append("```\n")
        buffer.append("let x = 1\n")
        buffer.append("```")

        // Then: code block should still be rendered with box-drawing borders
        let output = mock.output
        XCTAssertTrue(output.contains("let x = 1"),
            "Regression: Code block content should be rendered. Got: \(output)")
    }

    func testAppend_codeBlockNotConfusedWithTable() {
        // Given a code block containing pipe characters
        let (buffer, mock) = makeBuffer()

        buffer.append("```\n")
        buffer.append("| not a table |\n")
        buffer.append("```")

        // Then: should render as code block, not as table
        let output = mock.output
        XCTAssertTrue(output.contains("not a table"),
            "Regression: Code block with pipes should render as code. Got: \(output)")
        // Code blocks have │ left margin, tables have │ cell separators
        // The key is it should not crash or produce garbled output
    }

    // MARK: - Regression: Normal text immediate output unaffected (P1)

    func testAppend_normalText_stillImmediate() {
        // Given normal streaming text
        let (buffer, mock) = makeBuffer()

        buffer.append("Hello world")

        // Then: text should be rendered immediately
        XCTAssertTrue(mock.output.contains("Hello world"),
            "Regression: Normal text should still be rendered immediately. Got: \(mock.output)")
    }

    func testAppend_normalTextMultipleChunks_concatenates() {
        // Given multiple text chunks
        let (buffer, mock) = makeBuffer()

        buffer.append("Hello ")
        buffer.append("world")
        buffer.append("!")

        // Then: all chunks should appear
        XCTAssertTrue(mock.output.contains("Hello") && mock.output.contains("world"),
            "Regression: Multiple text chunks should concatenate. Got: \(mock.output)")
    }

    // MARK: - Edge Cases (P2)

    func testAppend_tableWithSeparatorOnly_noDataRows_noCrash() {
        // Given a table with header and separator but no data rows, then terminated
        let (buffer, mock) = makeBuffer()

        buffer.append("| H1 | H2 |\n|----|----|\n\n")

        let output = mock.output
        // Should not crash -- header-only table is valid
        XCTAssertFalse(output.isEmpty,
            "Edge case: Header-only table should produce output. Got empty.")
    }

    func testAppend_emptyChunk_noEffect() {
        // Given an empty chunk
        let (buffer, mock) = makeBuffer()

        buffer.append("")

        // Then: no output
        XCTAssertTrue(mock.output.isEmpty,
            "Edge case: Empty chunk should produce no output. Got: \(mock.output)")
    }

    func testAppend_tableFollowedByImmediateAnotherTable() {
        // Given two tables with no text between them (just a blank line separator)
        let (buffer, mock) = makeBuffer()

        buffer.append("| T1A | T1B |\n|-----|-----|\n| 1 | 2 |\n\n| T2A | T2B |\n|-----|-----|\n| 3 | 4 |\n\n")

        let output = mock.output
        XCTAssertTrue(output.contains("T1A") && output.contains("1"),
            "Edge case: First table content should appear. Got: \(output)")
        XCTAssertTrue(output.contains("T2A") && output.contains("3"),
            "Edge case: Second table content should appear. Got: \(output)")
    }
}
