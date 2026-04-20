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

// MARK: - OutputRenderer

/// Renders SDK messages to terminal output with ANSI styling.
///
/// Consumes `AsyncStream<SDKMessage>` from the SDK and formats each event
/// for terminal display. All output goes through a `TextOutputStream` abstraction
/// for testability -- the default writes to stdout.
struct OutputRenderer: OutputRendering {
    let output: AnyTextOutputStream

    /// Create with default stdout output.
    init() {
        self.output = AnyTextOutputStream(FileHandleTextOutputStream())
    }

    /// Create with custom output stream (for testing).
    init<O: TextOutputStream>(output: O) {
        self.output = AnyTextOutputStream(output)
    }

    /// Main dispatch method -- routes each SDKMessage case to its renderer.
    func render(_ message: SDKMessage) {
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
