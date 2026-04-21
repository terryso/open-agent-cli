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

/// Reference-type buffer that accumulates streaming text for code block rendering.
///
/// Strategy: Most text chunks are written immediately with inline Markdown
/// formatting (bold, code) applied per-chunk. Code blocks (``` ... ```) are
/// the exception -- they are buffered until the closing ``` so the box-drawing
/// borders can be calculated from the full content.
final class MarkdownBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = ""
    private var insideCodeBlock = false
    private let output: AnyTextOutputStream

    init(output: AnyTextOutputStream) {
        self.output = output
    }

    /// Append a streaming chunk.
    ///
    /// - If currently inside a code block, buffer the chunk.
    /// - If the chunk contains an opening ```, enter code block mode.
    /// - Otherwise, apply inline Markdown formatting and write immediately.
    func append(_ chunk: String) {
        lock.lock()
        defer { lock.unlock() }

        if insideCodeBlock {
            buffer += chunk
            tryFlushCodeBlock()
        } else if chunk.contains("```") {
            // Chunk contains a code fence start -- buffer it
            buffer += chunk
            insideCodeBlock = true
            tryFlushCodeBlock()
        } else {
            // Normal streaming text: apply inline formatting and write immediately
            output.write(MarkdownRenderer.renderInline(chunk))
        }
    }

    /// Flush any remaining buffered content.
    ///
    /// Called when the final `.result` message arrives. If we're inside an
    /// unclosed code block, render what we have gracefully.
    func flush() {
        lock.lock()
        defer { lock.unlock() }

        guard !buffer.isEmpty else { return }
        if insideCodeBlock {
            // Unclosed code block: render as code block with existing content
            let rendered = MarkdownRenderer.renderCodeBlock(buffer)
            output.write(rendered)
        } else {
            output.write(MarkdownRenderer.render(buffer))
        }
        buffer = ""
        insideCodeBlock = false
    }

    // MARK: - Private

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
            renderSystem(data)
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
