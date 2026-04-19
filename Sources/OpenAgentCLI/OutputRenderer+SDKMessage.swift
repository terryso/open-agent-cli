import Foundation
import OpenAgentSDK

// MARK: - OutputRenderer SDKMessage Rendering Extensions

extension OutputRenderer {

    // MARK: - AC#1: partialMessage -- chunk-by-chunk text output, no buffering

    /// Render a partial text chunk to the output stream without a trailing newline.
    ///
    /// This is the primary streaming target -- each text fragment is written
    /// immediately as it arrives from the SDK.
    func renderPartialMessage(_ data: SDKMessage.PartialData) {
        guard !data.text.isEmpty else { return }
        output.write(data.text)
    }

    // MARK: - AC#2: assistant -- error detection and display

    /// Render an assistant message.
    ///
    /// For normal responses (no error), produces no output -- the text was already
    /// streamed via `partialMessage`. Only errors are rendered (in red with guidance).
    func renderAssistant(_ data: SDKMessage.AssistantData) {
        guard let error = data.error else {
            // Normal assistant: text already streamed via partialMessage. Nothing to do.
            return
        }

        let errorLine = ANSI.red("Error: \(error.rawValue)")
        let guidance = actionableGuidance(for: error)
        output.write("\(errorLine) -- \(guidance)\n")
    }

    // MARK: - AC#3, AC#5: result -- summary line with error/cancel handling

    /// Render the final query result with a summary line.
    ///
    /// Format: `--- Turns: N | Cost: $X.XXXX | Duration: Xs`
    /// Error subtypes are highlighted in red; cancelled is shown in grey/dim.
    /// Individual error messages (from `data.errors`) are listed in red.
    func renderResult(_ data: SDKMessage.ResultData) {
        switch data.subtype {
        case .success:
            let summary = formatSummary(data)
            output.write("--- \(summary)\n")

        case .cancelled:
            let label = ANSI.dim("[cancelled]")
            output.write("--- \(label)\n")

        case .errorMaxTurns, .errorDuringExecution, .errorMaxBudgetUsd, .errorMaxStructuredOutputRetries:
            let tag = ANSI.red("[\(data.subtype.rawValue)]")
            let summary = formatSummary(data)
            output.write("--- \(tag) \(summary)\n")

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

    // MARK: - AC#6: toolUse -- basic cyan tool call line

    /// Render a tool invocation with cyan styling.
    ///
    /// This is a basic implementation. Story 2.2 will enhance this with
    /// argument summaries, execution timing, and truncation.
    func renderToolUse(_ data: SDKMessage.ToolUseData) {
        let line = ANSI.cyan("> \(data.toolName)")
        output.write("\(line)\n")
    }

    // MARK: - AC#6: toolResult -- result text, red on error

    /// Render a tool execution result.
    ///
    /// Successful results display content in default color; error results use red.
    /// Story 2.2 will enhance this with truncation and formatting.
    func renderToolResult(_ data: SDKMessage.ToolResultData) {
        if data.isError {
            output.write("  \(ANSI.red(data.content))\n")
        } else {
            // Truncate long results to a reasonable length for basic display.
            let display = data.content.count > 200
                ? String(data.content.prefix(200)) + "..."
                : data.content
            output.write("  \(display)\n")
        }
    }

    // MARK: - Private Helpers

    /// Format the summary portion of a result line.
    ///
    /// Example: `Turns: 3 | Cost: $0.0023 | Duration: 4.2s`
    private func formatSummary(_ data: SDKMessage.ResultData) -> String {
        let costStr = String(format: "$%.4f", data.totalCostUsd)
        let durationSeconds = Double(data.durationMs) / 1000.0
        let durationStr = String(format: "%.1f", durationSeconds)
        return "Turns: \(data.numTurns) | Cost: \(costStr) | Duration: \(durationStr)s"
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
}
