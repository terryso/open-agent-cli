import Foundation
import OpenAgentSDK

// MARK: - TextOutputStream Abstractions

/// A reference-type wrapper around any `TextOutputStream`.
///
/// Needed because `TextOutputStream.write` is mutating, which conflicts with
/// `Sendable` conformance when captured in closures. By wrapping in a class,
/// the mutation happens on the reference, not the enclosing struct.
final class AnyTextOutputStream: TextOutputStream, @unchecked Sendable {
    private let lock = NSLock()
    private var _output: Any

    init<O: TextOutputStream>(_ output: O) {
        self._output = output
    }

    func write(_ string: String) {
        lock.lock()
        defer { lock.unlock() }
        // Dynamic cast and mutation -- safe because `lock` serializes access.
        if var stream = _output as? TextOutputStream {
            stream.write(string)
            _output = stream
        }
    }
}

/// FileHandle-based TextOutputStream for stdout.
///
/// Writes UTF-8 encoded strings directly to standard output using
/// unbuffered I/O for immediate display of streaming content.
struct FileHandleTextOutputStream: TextOutputStream, Sendable {
    func write(_ string: String) {
        FileHandle.standardOutput.write(string.data(using: .utf8) ?? Data())
    }
}

// MARK: - OutputRendering Protocol

/// Protocol for output rendering, enabling testability.
///
/// Implementations consume `SDKMessage` events and format them for terminal display.
protocol OutputRendering: Sendable {
    func render(_ message: SDKMessage)
    func renderStream(_ stream: AsyncStream<SDKMessage>) async
}

// MARK: - Streaming Markdown Buffer

/// Reference-type buffer that accumulates streaming text for code block and table rendering.
///
/// Strategy: Most text chunks are written immediately with inline Markdown
/// formatting (bold, code) applied per-chunk. Code blocks (``` ... ```) and
/// Markdown tables (| ... |) are the exception -- they are buffered until
/// complete so the box-drawing borders can be calculated from the full content.
final class MarkdownBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = ""
    private var insideCodeBlock = false
    private var insideTableBlock = false
    private let output: AnyTextOutputStream

    // MARK: - Turn state tracking (Story 10.1)

    private var _turnHeaderPrinted = false
    private var _firstToolInTurn = true

    /// Whether the blue "●" prefix has been printed for the current AI turn.
    var turnHeaderPrinted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _turnHeaderPrinted
    }

    /// Whether the first tool call in the current turn has been seen.
    var firstToolInTurn: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _firstToolInTurn
    }

    init(output: AnyTextOutputStream) {
        self.output = output
    }

    /// Append a streaming chunk.
    ///
    /// - If currently inside a code block, buffer the chunk.
    /// - If the chunk contains an opening ```, enter code block mode.
    /// - If currently inside a table block, buffer the chunk.
    /// - If the chunk triggers table detection, enter table buffer mode.
    /// - Otherwise, apply inline Markdown formatting and write immediately.
    func append(_ chunk: String) {
        lock.lock()
        defer { lock.unlock() }

        guard !chunk.isEmpty else { return }

        if insideCodeBlock {
            buffer += chunk
            tryFlushCodeBlock()
        } else if chunk.contains("```") {
            // Chunk contains a code fence start -- buffer it
            buffer += chunk
            insideCodeBlock = true
            tryFlushCodeBlock()
        } else if insideTableBlock {
            // Already in table buffer mode -- accumulate and check for table end
            buffer += chunk
            tryFlushTableBlock()
        } else {
            // Normal mode: accumulate and check for table start
            buffer += chunk
            if detectTableStart() {
                insideTableBlock = true
                tryFlushTableBlock()
            } else if mightBeStartingTable() && bufferHasPlausibleTableContent() {
                // Last line could be a table row fragment -- keep buffering
                // and output any safe content before the potential table start
                flushSafePrefix()
            } else {
                output.write(MarkdownRenderer.renderInline(buffer))
                buffer = ""
            }
        }
    }

    /// Flush any remaining buffered content.
    ///
    /// Called when the final `.result` message arrives. If we're inside an
    /// unclosed code block or table block, render what we have gracefully.
    func flush() {
        lock.lock()
        defer { lock.unlock() }

        guard !buffer.isEmpty else { return }
        if insideCodeBlock {
            // Unclosed code block: render as code block with existing content
            let rendered = MarkdownRenderer.renderCodeBlock(buffer)
            output.write(rendered)
        } else if insideTableBlock {
            // Incomplete table: best-effort render via MarkdownRenderer.render()
            // which handles >= 2 table lines as a table, < 2 as paragraph
            let rendered = MarkdownRenderer.render(buffer)
            output.write(rendered)
        } else {
            output.write(MarkdownRenderer.render(buffer))
        }
        buffer = ""
        insideCodeBlock = false
        insideTableBlock = false
    }

    // MARK: - Turn State Management (Story 10.1)

    /// Mark that the blue "●" turn header has been printed for this turn.
    func markTurnHeaderPrinted() {
        lock.lock()
        defer { lock.unlock() }
        _turnHeaderPrinted = true
    }

    /// Mark that the first tool call in this turn has been seen.
    func markToolInTurn() {
        lock.lock()
        defer { lock.unlock() }
        _firstToolInTurn = false
    }

    /// Reset turn state for a new turn. Called from `renderResult`.
    func resetTurnHeader() {
        lock.lock()
        defer { lock.unlock() }
        _turnHeaderPrinted = false
        _firstToolInTurn = true
    }

    // MARK: - Private

    /// Check if a line looks like a Markdown table row (starts and ends with |).
    private func isTableLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && trimmed.count >= 2
    }

    /// Detect whether the buffer contains enough table-like lines to enter table mode.
    ///
    /// Requires at least 2 consecutive lines matching the `|...|` pattern to avoid
    /// false positives from inline pipe characters like `a | b` in normal text.
    private func detectTableStart() -> Bool {
        let lines = buffer.components(separatedBy: "\n")
        var consecutiveTableLines = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isTableLine(trimmed) {
                consecutiveTableLines += 1
                if consecutiveTableLines >= 2 {
                    return true
                }
            } else if !trimmed.isEmpty {
                consecutiveTableLines = 0
            }
            // Empty lines don't reset the counter -- separator rows may have
            // surrounding whitespace
        }
        return false
    }

    /// Check if the last non-empty line in the buffer starts with `|`,
    /// suggesting a table row might be forming across chunk boundaries.
    private func mightBeStartingTable() -> Bool {
        let lines = buffer.components(separatedBy: "\n")
        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                return trimmed.hasPrefix("|")
            }
        }
        return false
    }

    /// Check if the buffer contains content that could plausibly form a table.
    ///
    /// Prevents indefinite buffering when text starts with `|` but isn't a table
    /// (e.g., shell pipe syntax like `| grep foo`). If the buffer has grown to
    /// multiple lines with no valid table lines at all, or is a single long line
    /// that clearly isn't a table row, returns false to allow immediate output.
    private func bufferHasPlausibleTableContent() -> Bool {
        let lines = buffer.components(separatedBy: "\n")
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        // Single-line buffer starting with |: could be a table fragment forming
        // across chunk boundaries. Allow short buffering.
        if nonEmptyLines.count <= 1 {
            let trimmed = nonEmptyLines.first?.trimmingCharacters(in: .whitespaces) ?? ""
            // If it's a valid table line (|...|), definitely plausible
            if isTableLine(trimmed) { return true }
            // If it just starts with |, allow buffering but only if short
            // (a table row fragment won't grow very long before closing | arrives)
            return trimmed.count <= 100
        }

        // Multi-line buffer: check if there's at least one valid table line
        // If none of the lines are valid table lines, it's not a table
        let tableLineCount = nonEmptyLines.filter { isTableLine($0.trimmingCharacters(in: .whitespaces)) }.count
        return tableLineCount > 0
    }

    /// Output any content that appears before a potential table start,
    /// keeping only the table-like lines in the buffer.
    private func flushSafePrefix() {
        let lines = buffer.components(separatedBy: "\n")
        var potentialStart: Int? = nil
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && trimmed.hasPrefix("|") {
                potentialStart = i
                break
            }
        }
        if let start = potentialStart, start > 0 {
            let safeContent = lines[0..<start].joined(separator: "\n")
                .trimmingCharacters(in: .whitespaces)
            if !safeContent.isEmpty {
                output.write(MarkdownRenderer.renderInline(safeContent))
            }
            buffer = lines[start...].joined(separator: "\n")
        }
    }

    /// Process remaining content after a table render without re-acquiring the lock.
    /// Called from tryFlushTableBlock which already holds the lock.
    private func processRemainingContent(_ content: String) {
        buffer = content
        if detectTableStart() {
            insideTableBlock = true
            tryFlushTableBlock()
        } else if mightBeStartingTable() {
            flushSafePrefix()
        } else {
            output.write(MarkdownRenderer.renderInline(buffer))
            buffer = ""
        }
    }

    /// Try to find and render a complete table block from the buffer.
    ///
    /// Scans the buffer for a table section followed by a non-table line or
    /// empty line. When found, renders the table portion via MarkdownRenderer
    /// and processes any remaining content recursively.
    private func tryFlushTableBlock() {
        let lines = buffer.components(separatedBy: "\n")

        // Find the end of the table block: first non-empty, non-table line after table starts
        var tableStartIndex: Int? = nil
        var tableEndIndex = lines.count
        var tableEndFound = false

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isTableLine(trimmed) {
                if tableStartIndex == nil {
                    tableStartIndex = i
                }
            } else if trimmed.isEmpty {
                // Empty line signals table end, but ignore trailing artifact from
                // components(separatedBy:) which creates a "" after the final \n
                if tableStartIndex != nil && i < lines.count - 1 {
                    tableEndIndex = i
                    tableEndFound = true
                    break
                }
            } else {
                // Non-table, non-empty line always signals table end
                if tableStartIndex != nil {
                    tableEndIndex = i
                    tableEndFound = true
                    break
                }
            }
        }

        // Only render if we found an explicit table end (empty line or non-table text)
        guard let startIndex = tableStartIndex, tableEndFound else {
            // Table not yet complete -- keep buffering
            return
        }

        // Verify at least 2 table lines in the detected range
        let tableSlice = lines[startIndex..<tableEndIndex]
        let tableLineCount = tableSlice.filter { isTableLine($0.trimmingCharacters(in: .whitespaces)) }.count
        guard tableLineCount >= 2 else {
            // Not enough table lines -- this is not a real table
            // Output the buffered content as inline text
            output.write(MarkdownRenderer.renderInline(buffer))
            buffer = ""
            insideTableBlock = false
            return
        }

        // Check if there are non-empty lines before the table that should be output first
        if startIndex > 0 {
            let preTableLines = lines[0..<startIndex]
            let preContent = preTableLines.joined(separator: "\n")
                .trimmingCharacters(in: .whitespaces)
            if !preContent.isEmpty {
                output.write(MarkdownRenderer.renderInline(preContent))
            }
        }

        // Render the table portion
        let tableLines = Array(tableSlice)
        let tableContent = tableLines.joined(separator: "\n")
        output.write(MarkdownRenderer.render(tableContent))

        // Handle remaining content after the table
        let remainingLines: [String]
        if tableEndIndex < lines.count {
            remainingLines = Array(lines[tableEndIndex...])
        } else {
            remainingLines = []
        }

        buffer = ""
        insideTableBlock = false

        let remaining = remainingLines.joined(separator: "\n")
        if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Process remaining content inline (lock already held, cannot call append)
            processRemainingContent(remaining)
        }
    }

    /// Try to extract and render a complete code block from the buffer.
    private func tryFlushCodeBlock() {
        // Look for opening ```
        guard let openRange = buffer.range(of: "```") else {
            return
        }

        // Look for closing ``` after the opening
        let searchStart = openRange.upperBound
        if let closeRange = buffer.range(of: "```", range: searchStart..<buffer.endIndex) {
            // Complete code block found -- extract, render, and remove from buffer
            let blockEnd = closeRange.upperBound
            let block = String(buffer[buffer.startIndex..<blockEnd])

            // Remove the block from buffer
            var remaining = String(buffer[blockEnd...])
            if remaining.hasPrefix("\n") {
                remaining = String(remaining.dropFirst())
            }
            buffer = remaining
            insideCodeBlock = false

            output.write(MarkdownRenderer.render(block))

            // Check if there's another code block starting in remaining buffer
            if buffer.contains("```") {
                insideCodeBlock = true
                tryFlushCodeBlock()
            } else if !buffer.isEmpty {
                // Write any remaining non-code text
                output.write(MarkdownRenderer.renderInline(buffer))
                buffer = ""
            }
        }
        // else: code block not yet closed, keep buffering
    }
}

// MARK: - OutputRenderer

/// Renders SDK messages to terminal output with ANSI styling.
///
/// Consumes `AsyncStream<SDKMessage>` from the SDK and formats each event
/// for terminal display. All output goes through a `TextOutputStream` abstraction
/// for testability -- the default writes to stdout.
struct OutputRenderer: OutputRendering {
    let output: AnyTextOutputStream

    /// When true, only render essential output: partialMessage text and errors.
    /// Suppresses tool calls, system messages, success results, and sub-agent events.
    let quiet: Bool

    /// Markdown buffer for accumulating streaming text and rendering at block boundaries.
    let markdownBuffer: MarkdownBuffer

    /// Create with default stdout output.
    init(quiet: Bool = false) {
        let outputStream = AnyTextOutputStream(FileHandleTextOutputStream())
        self.output = outputStream
        self.quiet = quiet
        self.markdownBuffer = MarkdownBuffer(output: outputStream)
    }

    /// Create with custom output stream (for testing).
    init<O: TextOutputStream>(output: O, quiet: Bool = false) {
        let outputStream = AnyTextOutputStream(output)
        self.output = outputStream
        self.quiet = quiet
        self.markdownBuffer = MarkdownBuffer(output: outputStream)
    }

    /// Main dispatch method -- routes each SDKMessage case to its renderer.
    func render(_ message: SDKMessage) {
        // Quiet mode: only render partialMessage text, assistant errors, and non-success results.
        if quiet {
            switch message {
            case .partialMessage(let data):
                renderPartialMessage(data)
            case .assistant(let data):
                renderAssistant(data)
            case .result(let data):
                // Only render non-success results (errors) in quiet mode.
                if data.subtype != .success {
                    renderResult(data)
                }
            default:
                // Silence all other message types in quiet mode.
                break
            }
            return
        }

        // Normal mode: render everything.
        switch message {
        case .partialMessage(let data):
            renderPartialMessage(data)
        case .assistant(let data):
            renderAssistant(data)
        case .result(let data):
            renderResult(data)
        case .system(let data):
            if data.message != "Session started" {
                renderSystem(data)
            }
        case .toolUse(let data):
            renderToolUse(data)
        case .toolResult(let data):
            renderToolResult(data)
        case .taskStarted(let data):
            renderTaskStarted(data)
        case .taskProgress(let data):
            renderTaskProgress(data)
        case .userMessage,
             .toolProgress,
             .hookStarted,
             .hookProgress,
             .hookResponse,
             .authStatus,
             .filesPersisted,
             .localCommandOutput,
             .promptSuggestion,
             .toolUseSummary:
            // Silent handling for secondary message types.
            // These will be enhanced in future stories.
            break
        @unknown default:
            // Forward compatibility: silently ignore future message types.
            break
        }
    }

    /// Convenience method to consume an entire AsyncStream of SDKMessages.
    func renderStream(_ stream: AsyncStream<SDKMessage>) async {
        for await message in stream {
            render(message)
        }
    }
}
