import Foundation
import OpenAgentSDK

// MARK: - JSON Output Models

/// JSON-serializable tool call record for --output json mode.
struct JsonToolCall: Encodable {
    let name: String
    let input: String
}

/// JSON-serializable result structure for --output json mode (success case).
struct JsonRenderResult: Encodable {
    let text: String
    let toolCalls: [JsonToolCall]
    let cost: Double
    let turns: Int
    let sessionId: String?
}

/// JSON-serializable error structure for --output json mode (error case).
struct JsonRenderError: Encodable {
    let error: String
}

// MARK: - JsonOutputRenderer

/// JSON output renderer for programmatic consumption.
///
/// Silences all intermediate streaming output and produces a single JSON
/// object when the query completes. Used when `--output json` is specified.
///
/// JSON mode guarantees that stdout contains ONLY the final JSON output --
/// no ANSI escape codes, no progress indicators, no intermediate text.
/// This makes it safe for piping to `jq` or other JSON-processing tools.
struct JsonOutputRenderer: OutputRendering {
    let output: AnyTextOutputStream

    /// Create with default stdout output.
    init() {
        self.output = AnyTextOutputStream(FileHandleTextOutputStream())
    }

    /// Create with custom output stream (for testing).
    init<O: TextOutputStream>(output: O) {
        self.output = AnyTextOutputStream(output)
    }

    // MARK: - OutputRendering Conformance

    /// Silently ignore all intermediate messages.
    ///
    /// In JSON mode, no streaming output is produced -- the caller should use
    /// ``renderSingleShotJson(_:)`` to produce the final JSON output from a
    /// ``QueryResult``.
    func render(_ message: SDKMessage) {
        // Intentionally empty: silence all intermediate output (AC#3).
    }

    /// Silently consume a stream without producing output.
    ///
    /// In JSON mode, the caller should use ``renderSingleShotJson(_:)`` instead
    /// of relying on stream-based rendering.
    func renderStream(_ stream: AsyncStream<SDKMessage>) async {
        // Intentionally consume without output (AC#3).
        for await _ in stream {}
    }

    // MARK: - Single-Shot JSON Rendering

    /// Render a QueryResult as JSON for single-shot mode.
    ///
    /// For success status: outputs `{"text": "...", "toolCalls": [...], "cost": N, "turns": N}`.
    /// For error/cancelled status: outputs `{"error": "..."}`.
    ///
    /// The JSON is written as a single line followed by a newline character,
    /// making it suitable for piping to `jq` or other tools.
    func renderSingleShotJson(_ result: QueryResult, sessionId: String? = nil) {
        switch result.status {
        case .success:
            let toolCalls = extractToolCalls(from: result.messages)
            let jsonResult = JsonRenderResult(
                text: result.text,
                toolCalls: toolCalls,
                cost: result.totalCostUsd,
                turns: result.numTurns,
                sessionId: sessionId
            )
            writeJson(jsonResult)

        case .errorMaxTurns:
            let error = JsonRenderError(
                error: "Max turns (\(result.numTurns)) exceeded."
            )
            writeJson(error)

        case .errorDuringExecution:
            let errorMessages: [String]
            if let errors = result.errors, !errors.isEmpty {
                errorMessages = errors
            } else {
                errorMessages = ["Execution failed."]
            }
            let error = JsonRenderError(
                error: errorMessages.joined(separator: "; ")
            )
            writeJson(error)

        case .errorMaxBudgetUsd:
            let costStr = String(format: "$%.4f", result.totalCostUsd)
            let error = JsonRenderError(
                error: "Budget exceeded at \(costStr)."
            )
            writeJson(error)

        case .cancelled:
            let error = JsonRenderError(
                error: "Query was cancelled."
            )
            writeJson(error)
        }
    }

    // MARK: - Private Helpers

    /// Extract tool call records from SDK messages.
    ///
    /// Scans messages for `.toolUse` cases and maps each to a ``JsonToolCall``
    /// with the tool name and raw input string preserved verbatim.
    private func extractToolCalls(from messages: [SDKMessage]) -> [JsonToolCall] {
        messages.compactMap { message -> JsonToolCall? in
            if case .toolUse(let data) = message {
                return JsonToolCall(name: data.toolName, input: data.input)
            }
            return nil
        }
    }

    /// Encode and write a JSON-encodable value to the output stream.
    ///
    /// Uses `JSONEncoder` with sorted keys for deterministic output.
    /// Writes a trailing newline for pipe-friendly consumption.
    private func writeJson<T: Encodable>(_ value: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value),
              let jsonString = String(data: data, encoding: .utf8) else {
            // Fallback: if encoding fails, output a minimal error JSON
            output.write("{\"error\":\"Failed to encode JSON output\"}\n")
            return
        }
        output.write(jsonString + "\n")
    }
}
