import Foundation
import OpenAgentSDK

// MARK: - OutputRenderer SDKMessage Rendering Extensions

extension OutputRenderer {

    // MARK: - AC#1: partialMessage -- chunk-by-chunk with Markdown block buffering

    /// Render a partial text chunk through the Markdown buffer.
    ///
    /// Thinking content (prefixed with `[thinking]`) bypasses the Markdown buffer
    /// and is written immediately with dim ANSI styling, as Markdown rendering
    /// should not interfere with thinking content (Story 6.4).
    ///
    /// Regular text is accumulated in the Markdown buffer and rendered at block
    /// boundaries (paragraph breaks, code block closures) for correct formatting.
    func renderPartialMessage(_ data: SDKMessage.PartialData) {
        guard !data.text.isEmpty else { return }
        if data.text.hasPrefix("[thinking]") {
            output.write(ANSI.dim(data.text))
        } else {
            markdownBuffer.append(data.text)
        }
    }

    // MARK: - AC#2: assistant -- error detection and display

    /// Render an assistant message.
    ///
    /// For normal responses (no error), produces no output -- the text was already
    /// streamed via `partialMessage`. Only errors are rendered (in red with guidance).
    /// Flushes the Markdown buffer first to ensure all pending text is output.
    func renderAssistant(_ data: SDKMessage.AssistantData) {
        // Flush any remaining buffered Markdown content before showing error
        markdownBuffer.flush()

        guard let error = data.error else {
            // Normal assistant: text already streamed via partialMessage. Nothing to do.
            return
        }

        let errorLine = ANSI.red("Error: \(error.rawValue)")
        let guidance = actionableGuidance(for: error)
        output.write("\(errorLine) -- \(guidance)\n")
    }

    // MARK: - AC#3, AC#5: result -- flush Markdown, then summary line

    /// Render the final query result with a summary line.
    ///
    /// Flushes any remaining Markdown buffer content before rendering the result
    /// summary to ensure all text is rendered through the Markdown pipeline.
    /// Format: `--- Turns: N | Cost: $X.XXXX | Duration: Xs`
    /// Error subtypes are highlighted in red; cancelled is shown in grey/dim.
    /// Individual error messages (from `data.errors`) are listed in red.
    func renderResult(_ data: SDKMessage.ResultData) {
        // Flush any remaining buffered Markdown content
        markdownBuffer.flush()

        switch data.subtype {
        case .success:
            let summary = formatSummary(data)
            output.write("\n--- \(summary)\n")

        case .cancelled:
            let label = ANSI.dim("[cancelled]")
            output.write("\n--- \(label)\n")

        case .errorMaxTurns, .errorDuringExecution, .errorMaxBudgetUsd, .errorMaxStructuredOutputRetries:
            let tag = ANSI.red("[\(data.subtype.rawValue)]")
            let summary = formatSummary(data)
            output.write("\n--- \(tag) \(summary)\n")

            // AC#5: Display each individual error message in red.
            if let errors = data.errors {
                for error in errors {
                    output.write("  \(ANSI.red(error))\n")
                }
            }
        }
    }

    // MARK: - AC#4: system -- grey [system] prefix

    /// Render a system event message with grey/dim styling and `[system]` prefix.
    ///
    /// Only the message text is displayed -- no full JSON dump.
    func renderSystem(_ data: SDKMessage.SystemData) {
        let line = ANSI.dim("[system] \(data.message)")
        output.write("\(line)\n")
    }

    // MARK: - AC#6: toolUse -- cyan tool call line with args summary

    /// Render a tool invocation with cyan styling and argument summary.
    ///
    /// Parses the `input` JSON string to extract key arguments and display
    /// a concise summary. Falls back gracefully for empty or invalid JSON.
    func renderToolUse(_ data: SDKMessage.ToolUseData) {
        let summary = summarizeInput(data.input)
        let line = summary.isEmpty
            ? ANSI.cyan("> \(data.toolName)")
            : ANSI.cyan("> \(data.toolName)(\(summary))")
        output.write("\(line)\n")
    }

    // MARK: - AC#6: toolResult -- result text, 500-char truncation, red on error

    /// Render a tool execution result.
    ///
    /// Successful results are truncated at 500 characters with a "..." marker.
    /// Error results display in red without truncation (errors are important).
    func renderToolResult(_ data: SDKMessage.ToolResultData) {
        if data.isError {
            output.write("  \(ANSI.red(data.content))\n")
        } else {
            let display = data.content.count > 500
                ? String(data.content.prefix(500)) + "..."
                : data.content
            output.write("  \(display)\n")
        }
    }

    // MARK: - Single-Shot Mode (Story 1.5)

    /// Render a summary line from a `QueryResult` for single-shot mode.
    ///
    /// Reuses the same format as the streaming result summary to avoid DRY violations.
    /// Format: `--- Turns: N | Cost: $X.XXXX | Duration: Xs`
    /// Error statuses include a red tag; cancelled uses dim styling.
    /// When `debug` is true, individual error messages are listed below the summary.
    func renderSingleShotSummary(_ result: QueryResult, debug: Bool = false) {
        switch result.status {
        case .success:
            let summary = formatSummaryLine(
                numTurns: result.numTurns,
                totalCostUsd: result.totalCostUsd,
                durationMs: result.durationMs
            )
            output.write("--- \(summary)\n")

        case .cancelled:
            let label = ANSI.dim("[cancelled]")
            output.write("--- \(label)\n")

        case .errorMaxTurns, .errorDuringExecution, .errorMaxBudgetUsd:
            let tag = ANSI.red("[\(result.status.rawValue)]")
            let summary = formatSummaryLine(
                numTurns: result.numTurns,
                totalCostUsd: result.totalCostUsd,
                durationMs: result.durationMs
            )
            output.write("--- \(tag) \(summary)\n")
            if debug {
                let errorMessages = Self.extractErrors(from: result)
                for error in errorMessages {
                    output.write("  \(ANSI.red(error))\n")
                }
            }
        }
    }

    // MARK: - Private Helpers

    /// Extract a concise argument summary from a JSON input string.
    ///
    /// Strategy:
    /// - Parse JSON into `[String: Any]`
    /// - Show all keys sorted alphabetically (rely on summary truncation for length control)
    /// - Truncate each value to 80 characters
    /// - Format as "key1: val1, key2: val2"
    /// - Truncate total summary to 200 characters with "..."
    /// - Return empty string for empty JSON `{}` or parse failures
    private func summarizeInput(_ input: String) -> String {
        guard let data = input.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              !dict.isEmpty else {
            return ""
        }

        let maxValueLength = 80
        let maxSummaryLength = 200

        var pairs: [String] = []
        let sortedKeys = dict.keys.sorted()
        for key in sortedKeys {
            let valueStr = String(describing: dict[key] ?? "")
            let truncated = valueStr.count > maxValueLength
                ? String(valueStr.prefix(maxValueLength)) + "..."
                : valueStr
            pairs.append("\(key): \(truncated)")
        }

        let summary = pairs.joined(separator: ", ")
        if summary.count > maxSummaryLength {
            return String(summary.prefix(maxSummaryLength)) + "..."
        }
        return summary
    }

    /// Format the summary portion of a result line.
    ///
    /// Example: `Turns: 3 | Cost: $0.0023 | Duration: 4.2s`
    private func formatSummary(_ data: SDKMessage.ResultData) -> String {
        return formatSummaryLine(
            numTurns: data.numTurns,
            totalCostUsd: data.totalCostUsd,
            durationMs: data.durationMs
        )
    }

    /// Shared summary line formatter used by both streaming and single-shot modes.
    ///
    /// Extracts the common formatting logic to avoid duplication (DRY).
    private func formatSummaryLine(numTurns: Int, totalCostUsd: Double, durationMs: Int) -> String {
        let costStr = String(format: "$%.4f", totalCostUsd)
        let durationSeconds = Double(durationMs) / 1000.0
        let durationStr = String(format: "%.1f", durationSeconds)
        return "Turns: \(numTurns) | Cost: \(costStr) | Duration: \(durationStr)s"
    }

    /// Provide actionable guidance for an assistant error type.
    private func actionableGuidance(for error: SDKMessage.AssistantError) -> String {
        switch error {
        case .authenticationFailed:
            return "Check your API key."
        case .billingError:
            return "Check your billing status."
        case .rateLimit:
            return "Wait a moment and try again."
        case .invalidRequest:
            return "Check your request parameters."
        case .serverError:
            return "The server encountered an error. Try again later."
        case .maxOutputTokens:
            return "The response was too long. Try simplifying your request."
        case .unknown:
            return "An unexpected error occurred."
        }
    }

    // MARK: - AC#2, AC#5: Sub-agent progress rendering (Story 4.2)

    /// Render a sub-agent task started event with yellow styling and indented [sub-agent] prefix.
    ///
    /// Format: `  [sub-agent] <description>` (yellow ANSI, two-space indent)
    func renderTaskStarted(_ data: SDKMessage.TaskStartedData) {
        let line = "  " + ANSI.yellow("[sub-agent] \(data.description)")
        output.write("\(line)\n")
    }

    /// Render a sub-agent task progress event with grey/dim styling and indented [sub-agent] prefix.
    ///
    /// Format: `  [sub-agent] <taskId> - <usage info>` (grey/dim ANSI, two-space indent)
    /// Usage info is shown when available; otherwise only taskId is displayed.
    func renderTaskProgress(_ data: SDKMessage.TaskProgressData) {
        let usageStr: String
        if let usage = data.usage {
            usageStr = " - \(usage.inputTokens)in/\(usage.outputTokens)out"
        } else {
            usageStr = ""
        }
        let line = "  " + ANSI.dim("[sub-agent] \(data.taskId)\(usageStr)")
        output.write("\(line)\n")
    }

    /// Extract error strings from a QueryResult's messages.
    static func extractErrors(from result: QueryResult) -> [String] {
        result.messages.compactMap { msg -> [String]? in
            if case .result(let data) = msg, data.subtype != .success, let errors = data.errors {
                return errors
            }
            return nil
        }.flatMap { $0 }
    }
}
