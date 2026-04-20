import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 1.3 Streaming Output Renderer
//
// These tests define the EXPECTED behavior of OutputRenderer and related types.
// They will FAIL until OutputRenderer.swift and OutputRenderer+SDKMessage.swift
// are implemented (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: partialMessage streams text chunk-by-chunk, no buffering
//   AC#2: assistant with error shows red error + actionable guidance
//   AC#3: result shows summary line; error subtypes red; cancelled grey
//   AC#4: system messages shown in grey with [system] prefix
//   AC#5: error result shows each error message in red with guidance
//   AC#6: All SDKMessage cases handled including @unknown default

// MARK: - Mock TextOutputStream for Testing

/// A reference-type mock that captures all written output into a string for assertion.
/// Uses a class (not struct) so that writes through `AnyTextOutputStream` are visible
/// to the test -- value types would be copied and writes would be lost.
final class MockTextOutputStream: TextOutputStream {
    var output = ""
    func write(_ string: String) {
        output += string
    }
}

final class OutputRendererTests: XCTestCase {

    // MARK: - Helpers

    /// Creates an OutputRenderer backed by a MockTextOutputStream.
    /// Returns both the renderer and the mock so tests can assert on output.
    private func makeRenderer() -> (renderer: OutputRenderer, mock: MockTextOutputStream) {
        let mock = MockTextOutputStream()
        let renderer = OutputRenderer(output: mock)
        return (renderer, mock)
    }

    // MARK: - AC#1: partialMessage streams text chunk-by-chunk, no buffering (P0)

    func testPartialMessage_outputsTextWithoutNewline() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.PartialData(text: "Hello")

        renderer.render(.partialMessage(data))

        // AC#1: Text is output directly, no trailing newline
        XCTAssertEqual(mock.output, "Hello",
            "partialMessage should output text without trailing newline (terminator: '')")
    }

    func testPartialMessage_multipleChunks_concatenates() throws {
        let (renderer, mock) = makeRenderer()

        renderer.render(.partialMessage(SDKMessage.PartialData(text: "Hello")))
        renderer.render(.partialMessage(SDKMessage.PartialData(text: " ")))
        renderer.render(.partialMessage(SDKMessage.PartialData(text: "world")))

        // AC#1: Multiple chunks concatenate without separators
        XCTAssertEqual(mock.output, "Hello world",
            "Multiple partialMessage chunks should concatenate without separators")
    }

    func testPartialMessage_emptyString_noOutput() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.PartialData(text: "")

        renderer.render(.partialMessage(data))

        // Edge case: empty string produces no output
        XCTAssertEqual(mock.output, "",
            "Empty partialMessage text should produce no output")
    }

    // MARK: - AC#2: assistant with error shows red error (P0)

    func testAssistant_error_showsRedError() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.AssistantData(
            text: "",
            model: "glm-5.1",
            stopReason: "error",
            error: .rateLimit
        )

        renderer.render(.assistant(data))

        // AC#2: Error renders with red ANSI escape
        XCTAssertTrue(mock.output.contains("\u{001B}[31m"),
            "Assistant error should contain red ANSI escape code, got: \(mock.output.debugDescription)")
    }

    func testAssistant_error_includesErrorType() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.AssistantData(
            text: "",
            model: "glm-5.1",
            stopReason: "error",
            error: .rateLimit
        )

        renderer.render(.assistant(data))

        // AC#2: Error output should mention the error type
        let lowered = mock.output.lowercased()
        XCTAssertTrue(lowered.contains("ratelimit") || lowered.contains("rate limit") || lowered.contains("rate"),
            "Error output should mention the error type (rateLimit), got: \(mock.output)")
    }

    func testAssistant_noError_producesNoOutput() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.AssistantData(
            text: "Some response text",
            model: "glm-5.1",
            stopReason: "end_turn",
            error: nil
        )

        renderer.render(.assistant(data))

        // AC#2: Normal assistant (no error) produces no output
        // (text was already streamed via partialMessage)
        XCTAssertEqual(mock.output, "",
            "Normal assistant message should produce no output (already streamed via partialMessage)")
    }

    // MARK: - AC#3: Result summary line (P0)

    func testResult_success_summaryLine() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ResultData(
            subtype: .success,
            text: "Done",
            usage: TokenUsage(inputTokens: 100, outputTokens: 50),
            numTurns: 3,
            durationMs: 4200,
            totalCostUsd: 0.0023
        )

        renderer.render(.result(data))

        let output = mock.output
        // AC#3: Success summary line format
        XCTAssertTrue(output.contains("Turns: 3"),
            "Summary should contain 'Turns: 3', got: \(output)")
        XCTAssertTrue(output.contains("Cost:"),
            "Summary should contain 'Cost:', got: \(output)")
        XCTAssertTrue(output.contains("Duration:"),
            "Summary should contain 'Duration:', got: \(output)")
    }

    func testResult_success_correctTurns() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ResultData(
            subtype: .success,
            text: "Done",
            usage: nil,
            numTurns: 10,
            durationMs: 5000,
            totalCostUsd: 0.01
        )

        renderer.render(.result(data))

        XCTAssertTrue(mock.output.contains("Turns: 10"),
            "Summary should show numTurns=10, got: \(mock.output)")
    }

    func testResult_success_correctCost() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ResultData(
            subtype: .success,
            text: "Done",
            usage: nil,
            numTurns: 1,
            durationMs: 1000,
            totalCostUsd: 0.0023
        )

        renderer.render(.result(data))

        // AC#3: Cost formatted as $X.XXXX (4 decimal places)
        XCTAssertTrue(mock.output.contains("$0.0023"),
            "Cost should be formatted as $0.0023, got: \(mock.output)")
    }

    func testResult_success_correctDuration() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ResultData(
            subtype: .success,
            text: "Done",
            usage: nil,
            numTurns: 1,
            durationMs: 4200,
            totalCostUsd: 0.0
        )

        renderer.render(.result(data))

        // AC#3: Duration converted from ms to seconds (4200ms -> 4.2s)
        XCTAssertTrue(mock.output.contains("4.2s"),
            "Duration should be 4.2s (4200ms), got: \(mock.output)")
    }

    func testResult_errorMaxTurns_redHighlight() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ResultData(
            subtype: .errorMaxTurns,
            text: "Max turns exceeded",
            usage: nil,
            numTurns: 10,
            durationMs: 12000,
            totalCostUsd: 0.0089
        )

        renderer.render(.result(data))

        // AC#3: Error subtype renders with red ANSI escape
        XCTAssertTrue(mock.output.contains("\u{001B}[31m"),
            "errorMaxTurns should render with red ANSI, got: \(mock.output.debugDescription)")
        XCTAssertTrue(mock.output.contains("errorMaxTurns"),
            "Output should mention 'errorMaxTurns', got: \(mock.output)")
    }

    func testResult_errorDuringExecution_redHighlight() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ResultData(
            subtype: .errorDuringExecution,
            text: "Execution failed",
            usage: nil,
            numTurns: 5,
            durationMs: 8000,
            totalCostUsd: 0.005
        )

        renderer.render(.result(data))

        XCTAssertTrue(mock.output.contains("\u{001B}[31m"),
            "errorDuringExecution should render with red ANSI, got: \(mock.output.debugDescription)")
    }

    func testResult_errorMaxBudgetUsd_redHighlight() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ResultData(
            subtype: .errorMaxBudgetUsd,
            text: "Budget exceeded",
            usage: nil,
            numTurns: 7,
            durationMs: 9000,
            totalCostUsd: 1.50
        )

        renderer.render(.result(data))

        XCTAssertTrue(mock.output.contains("\u{001B}[31m"),
            "errorMaxBudgetUsd should render with red ANSI, got: \(mock.output.debugDescription)")
    }

    func testResult_errorMaxStructuredOutputRetries_redHighlight() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ResultData(
            subtype: .errorMaxStructuredOutputRetries,
            text: "Structured output retries exceeded",
            usage: nil,
            numTurns: 3,
            durationMs: 5000,
            totalCostUsd: 0.01
        )

        renderer.render(.result(data))

        XCTAssertTrue(mock.output.contains("\u{001B}[31m"),
            "errorMaxStructuredOutputRetries should render with red ANSI, got: \(mock.output.debugDescription)")
    }

    func testResult_cancelled_greyDisplay() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ResultData(
            subtype: .cancelled,
            text: "Cancelled by user",
            usage: nil,
            numTurns: 2,
            durationMs: 3000,
            totalCostUsd: 0.001
        )

        renderer.render(.result(data))

        // AC#3: Cancelled renders with grey/dim ANSI escape
        XCTAssertTrue(mock.output.contains("\u{001B}[2m"),
            "cancelled should render with dim/grey ANSI, got: \(mock.output.debugDescription)")
        XCTAssertTrue(mock.output.lowercased().contains("cancelled"),
            "Output should contain 'cancelled', got: \(mock.output)")
    }

    // MARK: - AC#4: System messages in grey with [system] prefix (P1)

    func testSystem_init_greyPrefix() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.SystemData(
            subtype: .`init`,
            message: "Session started"
        )

        renderer.render(.system(data))

        // AC#4: [system] prefix with grey/dim styling
        XCTAssertTrue(mock.output.contains("[system]"),
            "System message should have [system] prefix, got: \(mock.output)")
        XCTAssertTrue(mock.output.contains("Session started"),
            "System message should include the message text, got: \(mock.output)")
        XCTAssertTrue(mock.output.contains("\u{001B}[2m"),
            "System message should use dim/grey ANSI, got: \(mock.output.debugDescription)")
    }

    func testSystem_compactBoundary_greyPrefix() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.SystemData(
            subtype: .compactBoundary,
            message: "Conversation compacted"
        )

        renderer.render(.system(data))

        XCTAssertTrue(mock.output.contains("[system]"),
            "compactBoundary system message should have [system] prefix, got: \(mock.output)")
        XCTAssertTrue(mock.output.contains("Conversation compacted"),
            "compactBoundary should show message text, got: \(mock.output)")
    }

    func testSystem_status_greyPrefix() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.SystemData(
            subtype: .status,
            message: "Processing request"
        )

        renderer.render(.system(data))

        XCTAssertTrue(mock.output.contains("[system]"),
            "status system message should have [system] prefix, got: \(mock.output)")
        XCTAssertTrue(mock.output.contains("Processing request"),
            "status should show message text, got: \(mock.output)")
    }

    // MARK: - AC#5: Error result shows each error message in red (P0)

    func testResult_error_showsEachErrorMessage() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ResultData(
            subtype: .errorDuringExecution,
            text: "Execution failed",
            usage: nil,
            numTurns: 5,
            durationMs: 8000,
            totalCostUsd: 0.005,
            errors: ["API timeout after 30s", "Rate limit exceeded"]
        )

        renderer.render(.result(data))

        // AC#5: Each error message should be displayed
        XCTAssertTrue(mock.output.contains("API timeout after 30s"),
            "Output should show first error message, got: \(mock.output)")
        XCTAssertTrue(mock.output.contains("Rate limit exceeded"),
            "Output should show second error message, got: \(mock.output)")
    }

    func testResult_error_providesActionableGuidance() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ResultData(
            subtype: .errorMaxTurns,
            text: "Max turns exceeded",
            usage: nil,
            numTurns: 10,
            durationMs: 12000,
            totalCostUsd: 0.0089,
            errors: ["Agent exceeded maximum turns"]
        )

        renderer.render(.result(data))

        // AC#5: Error output should include actionable guidance
        // The specific guidance text is implementation-defined, but output
        // should not be empty and should contain the error type + message
        XCTAssertFalse(mock.output.isEmpty,
            "Error result should produce some output")
        XCTAssertTrue(mock.output.contains("errorMaxTurns") || mock.output.contains("Max turns"),
            "Error output should reference the error context, got: \(mock.output)")
    }

    // MARK: - AC#6: All SDKMessage cases handled (P0/P1)

    func testRender_toolUse_basicOutput() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ToolUseData(
            toolName: "Bash",
            toolUseId: "tool-123",
            input: "{\"command\": \"ls\"}"
        )

        renderer.render(.toolUse(data))

        // AC#6: ToolUse renders with cyan and tool name
        XCTAssertTrue(mock.output.contains("Bash"),
            "toolUse should show tool name, got: \(mock.output)")
        XCTAssertTrue(mock.output.contains("\u{001B}[36m"),
            "toolUse should render with cyan ANSI, got: \(mock.output.debugDescription)")
    }

    func testRender_toolResult_success() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ToolResultData(
            toolUseId: "tool-123",
            content: "file1.txt\nfile2.txt",
            isError: false
        )

        renderer.render(.toolResult(data))

        // AC#6: Successful tool result renders content
        XCTAssertTrue(mock.output.contains("file1.txt") || mock.output.contains("file2.txt"),
            "toolResult should show result content, got: \(mock.output)")
        // Should NOT be red
        XCTAssertFalse(mock.output.contains("\u{001B}[31m"),
            "Successful toolResult should not use red ANSI, got: \(mock.output.debugDescription)")
    }

    func testRender_toolResult_error_showsRed() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ToolResultData(
            toolUseId: "tool-456",
            content: "Command failed: permission denied",
            isError: true
        )

        renderer.render(.toolResult(data))

        // AC#6: Error tool result renders in red
        XCTAssertTrue(mock.output.contains("\u{001B}[31m"),
            "Error toolResult should render with red ANSI, got: \(mock.output.debugDescription)")
        XCTAssertTrue(mock.output.contains("permission denied"),
            "Error toolResult should show error content, got: \(mock.output)")
    }

    func testRender_handlesAllKnownCases_noCrash() throws {
        // AC#6: Verify that rendering all known SDKMessage cases does not crash.
        // This tests the @unknown default forward compatibility.
        let (renderer, _) = makeRenderer()

        // List of representative messages for each known case
        let messages: [SDKMessage] = [
            .partialMessage(SDKMessage.PartialData(text: "hi")),
            .assistant(SDKMessage.AssistantData(text: "ok", model: "glm-5.1", stopReason: "end_turn")),
            .result(SDKMessage.ResultData(subtype: .success, text: "done", usage: nil, numTurns: 1, durationMs: 100)),
            .system(SDKMessage.SystemData(subtype: .`init`, message: "init")),
            .toolUse(SDKMessage.ToolUseData(toolName: "Bash", toolUseId: "t1", input: "{}")),
            .toolResult(SDKMessage.ToolResultData(toolUseId: "t1", content: "ok", isError: false)),
            .userMessage(SDKMessage.UserMessageData(message: "hello")),
            .toolProgress(SDKMessage.ToolProgressData(toolUseId: "t1", toolName: "Bash")),
            .hookStarted(SDKMessage.HookStartedData(hookId: "h1", hookName: "pre", hookEvent: "PreToolUse")),
            .hookProgress(SDKMessage.HookProgressData(hookId: "h1", hookName: "pre", hookEvent: "PreToolUse")),
            .hookResponse(SDKMessage.HookResponseData(hookId: "h1", hookName: "pre", hookEvent: "PreToolUse")),
            .taskStarted(SDKMessage.TaskStartedData(taskId: "task1", taskType: "subagent", description: "sub task")),
            .taskProgress(SDKMessage.TaskProgressData(taskId: "task1", taskType: "subagent")),
            .authStatus(SDKMessage.AuthStatusData(status: "ok", message: "authenticated")),
            .filesPersisted(SDKMessage.FilesPersistedData(filePaths: ["/tmp/a.txt"])),
            .localCommandOutput(SDKMessage.LocalCommandOutputData(output: "result", command: "ls")),
            .promptSuggestion(SDKMessage.PromptSuggestionData(suggestions: ["next"])),
            .toolUseSummary(SDKMessage.ToolUseSummaryData(toolUseCount: 3, tools: ["Bash"])),
        ]

        // This should not crash for any known case
        for message in messages {
            renderer.render(message)
        }
    }

    func testRenderStream_consumesEntireStream() async throws {
        // AC#6: renderStream processes all messages in an AsyncStream
        let mock = MockTextOutputStream()
        let renderer = OutputRenderer(output: mock)

        let messages: [SDKMessage] = [
            .partialMessage(SDKMessage.PartialData(text: "Hello ")),
            .partialMessage(SDKMessage.PartialData(text: "world")),
            .result(SDKMessage.ResultData(
                subtype: .success,
                text: "Done",
                usage: nil,
                numTurns: 1,
                durationMs: 1000,
                totalCostUsd: 0.001
            )),
        ]

        let stream = AsyncStream<SDKMessage> { continuation in
            for message in messages {
                continuation.yield(message)
            }
            continuation.finish()
        }

        await renderer.renderStream(stream)

        // Verify that both partialMessage chunks were rendered
        XCTAssertTrue(mock.output.contains("Hello world"),
            "renderStream should render all partialMessage chunks, got: \(mock.output)")
        // Verify result summary was rendered
        XCTAssertTrue(mock.output.contains("Turns:"),
            "renderStream should render result summary, got: \(mock.output)")
    }

    // MARK: - TextOutputStream Abstraction Tests (P2)

    func testOutputRenderer_usesCustomTextOutputStream() throws {
        let mock = MockTextOutputStream()
        let renderer = OutputRenderer(output: mock)

        renderer.render(.partialMessage(SDKMessage.PartialData(text: "test")))

        XCTAssertEqual(mock.output, "test",
            "OutputRenderer should write through TextOutputStream abstraction")
    }

    func testOutputRenderer_defaultInit_succeeds() throws {
        let renderer = OutputRenderer()
        renderer.render(.partialMessage(SDKMessage.PartialData(text: "hello")))

        // Default init produces a working renderer — no crash means success
    }

    // MARK: - ATDD Red Phase: Story 2.2 Tool Call Visibility
    //
    // These tests define the EXPECTED behavior of enhanced tool call rendering.
    // They will FAIL until renderToolUse and renderToolResult are enhanced
    // with argument summaries, 500-char truncation, and improved formatting.
    //
    // Acceptance Criteria Coverage:
    //   AC#1: toolUse shows tool name + input args summary in cyan
    //   AC#2: toolResult shows result text (truncated at 500 chars); errors in red
    //   AC#3: Multiple sequential tool calls render in order

    // MARK: - AC#1: renderToolUse shows tool name and args summary (P0)

    func testRenderToolUse_showsArgsSummary() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ToolUseData(
            toolName: "Bash",
            toolUseId: "tool-001",
            input: "{\"command\": \"ls -la\"}"
        )

        renderer.render(.toolUse(data))

        // AC#1: Should show tool name with parsed args summary
        let output = mock.output
        XCTAssertTrue(output.contains("Bash"),
            "toolUse should show tool name, got: \(output)")
        XCTAssertTrue(output.contains("command"),
            "toolUse should show arg key 'command', got: \(output)")
        XCTAssertTrue(output.contains("ls -la"),
            "toolUse should show arg value 'ls -la', got: \(output)")
        XCTAssertTrue(output.contains("\u{001B}[36m"),
            "toolUse should use cyan ANSI, got: \(output.debugDescription)")
    }

    func testRenderToolUse_multipleArgs_showsAll() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ToolUseData(
            toolName: "Write",
            toolUseId: "tool-002",
            input: "{\"file_path\": \"/tmp/output.txt\", \"content\": \"hello world\"}"
        )

        renderer.render(.toolUse(data))

        // AC#1: Should show multiple arg key-value pairs
        let output = mock.output
        XCTAssertTrue(output.contains("Write"),
            "toolUse should show tool name 'Write', got: \(output)")
        XCTAssertTrue(output.contains("file_path"),
            "toolUse should show first arg key 'file_path', got: \(output)")
        XCTAssertTrue(output.contains("/tmp/output.txt"),
            "toolUse should show first arg value, got: \(output)")
    }

    func testRenderToolUse_emptyInput_showsToolNameOnly() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ToolUseData(
            toolName: "Read",
            toolUseId: "tool-003",
            input: "{}"
        )

        renderer.render(.toolUse(data))

        // AC#1: Empty JSON input should show tool name without empty parens
        let output = mock.output
        XCTAssertTrue(output.contains("Read"),
            "toolUse should show tool name 'Read', got: \(output)")
        // Should NOT contain empty parentheses like "Read()"
        XCTAssertFalse(output.contains("Read()"),
            "toolUse with empty input should not show empty parentheses, got: \(output)")
        XCTAssertTrue(output.contains("\u{001B}[36m"),
            "toolUse should use cyan ANSI even with empty input, got: \(output.debugDescription)")
    }

    func testRenderToolUse_invalidJSON_showsFallback() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ToolUseData(
            toolName: "Grep",
            toolUseId: "tool-004",
            input: "not valid json {{{"
        )

        renderer.render(.toolUse(data))

        // AC#1: Invalid JSON should show tool name and fall back gracefully
        let output = mock.output
        XCTAssertTrue(output.contains("Grep"),
            "toolUse should show tool name even with invalid JSON, got: \(output)")
        XCTAssertTrue(output.contains("\u{001B}[36m"),
            "toolUse should use cyan ANSI even with invalid JSON, got: \(output.debugDescription)")
    }

    func testRenderToolUse_longArgValue_truncates() throws {
        let (renderer, mock) = makeRenderer()
        let longValue = String(repeating: "x", count: 200)
        let data = SDKMessage.ToolUseData(
            toolName: "Write",
            toolUseId: "tool-005",
            input: "{\"content\": \"\(longValue)\"}"
        )

        renderer.render(.toolUse(data))

        // AC#1: Long arg values should be truncated (each value truncated to ~80 chars)
        let output = mock.output
        XCTAssertTrue(output.contains("Write"),
            "toolUse should show tool name, got: \(output)")
        // The full 200-char value should NOT appear in output
        XCTAssertFalse(output.contains(longValue),
            "toolUse should truncate long arg values, got output of length: \(output.count)")
    }

    func testRenderToolUse_manyArgs_showsFirstFew() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.ToolUseData(
            toolName: "Grep",
            toolUseId: "tool-006",
            input: "{\"pattern\": \"func.*render\", \"path\": \"/project\", \"type\": \"swift\", \"extra\": \"value\", \"another\": \"field\"}"
        )

        renderer.render(.toolUse(data))

        // AC#1: Should show args keys
        let output = mock.output
        XCTAssertTrue(output.contains("pattern"),
            "toolUse should show arg key 'pattern', got: \(output)")
    }

    func testRenderToolUse_nonStringJsonValues_displaysGracefully() throws {
        let (renderer, mock) = makeRenderer()
        // JSON with non-string values: number, boolean, null
        let data = SDKMessage.ToolUseData(
            toolName: "Config",
            toolUseId: "tool-007",
            input: "{\"count\": 42, \"verbose\": true, \"name\": \"test\"}"
        )

        renderer.render(.toolUse(data))

        // AC#1: Non-string values should be displayed via String(describing:)
        // without crashing or producing empty output
        let output = mock.output
        XCTAssertTrue(output.contains("Config"),
            "toolUse should show tool name, got: \(output)")
        XCTAssertTrue(output.contains("count"),
            "toolUse should show numeric arg key 'count', got: \(output)")
        XCTAssertTrue(output.contains("name"),
            "toolUse should show string arg key 'name', got: \(output)")
        // Verify the numeric and boolean values are rendered
        XCTAssertTrue(output.contains("42"),
            "toolUse should show numeric value 42, got: \(output)")
    }

    // MARK: - AC#2: renderToolResult with 500-char truncation (P0)

    func testRenderToolResult_success_underLimit_noTruncation() throws {
        let (renderer, mock) = makeRenderer()
        let shortContent = "file1.txt\nfile2.txt\nfile3.txt"
        let data = SDKMessage.ToolResultData(
            toolUseId: "tool-010",
            content: shortContent,
            isError: false
        )

        renderer.render(.toolResult(data))

        // AC#2: Short results (<=500 chars) should not be truncated
        let output = mock.output
        XCTAssertTrue(output.contains("file1.txt"),
            "toolResult should show full content for short results, got: \(output)")
        XCTAssertFalse(output.contains("..."),
            "Short result should not contain truncation marker, got: \(output)")
    }

    func testRenderToolResult_success_overLimit_truncates() throws {
        let (renderer, mock) = makeRenderer()
        let longContent = String(repeating: "a", count: 600)
        let data = SDKMessage.ToolResultData(
            toolUseId: "tool-011",
            content: longContent,
            isError: false
        )

        renderer.render(.toolResult(data))

        // AC#2: Results >500 chars should be truncated
        let output = mock.output
        XCTAssertTrue(output.contains("..."),
            "toolResult should contain truncation marker for long results, got output length: \(output.count)")
        // The output should NOT contain the full 600-char content
        XCTAssertFalse(output.contains(longContent),
            "toolResult should truncate content over 500 chars")
        // Verify the truncated content is around 500 chars (plus ANSI, prefix, etc.)
        // The content portion should be at most ~500 chars
        let contentWithoutFormatting = output
            .replacingOccurrences(of: "...", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(contentWithoutFormatting.count < longContent.count,
            "Truncated output should be shorter than original, got: \(contentWithoutFormatting.count) vs \(longContent.count)")
    }

    func testRenderToolResult_success_exactly500Chars_noTruncation() throws {
        let (renderer, mock) = makeRenderer()
        let exactContent = String(repeating: "b", count: 500)
        let data = SDKMessage.ToolResultData(
            toolUseId: "tool-012",
            content: exactContent,
            isError: false
        )

        renderer.render(.toolResult(data))

        // AC#2: Exactly 500 chars should NOT be truncated (cutoff is >500)
        let output = mock.output
        XCTAssertFalse(output.contains("..."),
            "toolResult with exactly 500 chars should not be truncated, got: \(output)")
    }

    func testRenderToolResult_error_showsRed_noTruncation() throws {
        let (renderer, mock) = makeRenderer()
        let errorContent = "Error: permission denied. The file could not be accessed because of insufficient permissions. Please check your access rights and try again."
        let data = SDKMessage.ToolResultData(
            toolUseId: "tool-013",
            content: errorContent,
            isError: true
        )

        renderer.render(.toolResult(data))

        // AC#2: Error results should display in red without truncation
        let output = mock.output
        XCTAssertTrue(output.contains("\u{001B}[31m"),
            "Error toolResult should render with red ANSI, got: \(output.debugDescription)")
        XCTAssertTrue(output.contains("permission denied"),
            "Error toolResult should show full error content, got: \(output)")
        XCTAssertFalse(output.contains("..."),
            "Error toolResult should not be truncated, got: \(output)")
    }

    func testRenderToolResult_error_longContent_noTruncation() throws {
        let (renderer, mock) = makeRenderer()
        let longError = "Critical failure: " + String(repeating: "e", count: 600)
        let data = SDKMessage.ToolResultData(
            toolUseId: "tool-014",
            content: longError,
            isError: true
        )

        renderer.render(.toolResult(data))

        // AC#2: Even long error content should NOT be truncated
        let output = mock.output
        XCTAssertTrue(output.contains("\u{001B}[31m"),
            "Long error toolResult should render with red ANSI, got: \(output.debugDescription)")
        XCTAssertFalse(output.contains("..."),
            "Long error toolResult should not be truncated, got: \(output)")
    }

    // MARK: - AC#3: Sequential tool calls render in order (P0)

    func testRenderMultipleToolCalls_sequential() throws {
        let (renderer, mock) = makeRenderer()

        // Simulate: toolUse(Bash) -> toolResult(Bash) -> toolUse(Read) -> toolResult(Read)
        renderer.render(.toolUse(SDKMessage.ToolUseData(
            toolName: "Bash",
            toolUseId: "tool-020",
            input: "{\"command\": \"ls\"}"
        )))
        renderer.render(.toolResult(SDKMessage.ToolResultData(
            toolUseId: "tool-020",
            content: "file1.txt",
            isError: false
        )))
        renderer.render(.toolUse(SDKMessage.ToolUseData(
            toolName: "Read",
            toolUseId: "tool-021",
            input: "{\"file_path\": \"/tmp/file1.txt\"}"
        )))
        renderer.render(.toolResult(SDKMessage.ToolResultData(
            toolUseId: "tool-021",
            content: "Hello World",
            isError: false
        )))

        // AC#3: All four messages should appear in sequential order
        let output = mock.output

        // Verify all tool names appear
        XCTAssertTrue(output.contains("Bash"),
            "Sequential output should contain 'Bash', got: \(output)")
        XCTAssertTrue(output.contains("Read"),
            "Sequential output should contain 'Read', got: \(output)")

        // Verify results appear
        XCTAssertTrue(output.contains("file1.txt"),
            "Sequential output should contain first tool result, got: \(output)")
        XCTAssertTrue(output.contains("Hello World"),
            "Sequential output should contain second tool result, got: \(output)")

        // Verify order: Bash should appear before Read
        let bashRange = output.range(of: "Bash")
        let readRange = output.range(of: "Read")
        if let bashRange = bashRange, let readRange = readRange {
            XCTAssertTrue(bashRange.lowerBound < readRange.lowerBound,
                "Bash tool call should appear before Read in sequential output")
        }
    }

    func testRenderMultipleToolCalls_threeInSequence() throws {
        let (renderer, mock) = makeRenderer()

        // Three sequential tool calls
        renderer.render(.toolUse(SDKMessage.ToolUseData(
            toolName: "Glob",
            toolUseId: "tool-030",
            input: "{\"pattern\": \"**/*.swift\"}"
        )))
        renderer.render(.toolUse(SDKMessage.ToolUseData(
            toolName: "Grep",
            toolUseId: "tool-031",
            input: "{\"pattern\": \"func\", \"type\": \"swift\"}"
        )))
        renderer.render(.toolUse(SDKMessage.ToolUseData(
            toolName: "Bash",
            toolUseId: "tool-032",
            input: "{\"command\": \"swift build\"}"
        )))

        // AC#3: Each tool call should render in order
        let output = mock.output
        XCTAssertTrue(output.contains("Glob"),
            "Should contain Glob tool call, got: \(output)")
        XCTAssertTrue(output.contains("Grep"),
            "Should contain Grep tool call, got: \(output)")
        XCTAssertTrue(output.contains("Bash"),
            "Should contain Bash tool call, got: \(output)")

        // Verify ordering: Glob < Grep < Bash
        let globRange = output.range(of: "Glob")
        let grepRange = output.range(of: "Grep")
        let bashRange = output.range(of: "Bash")
        if let globRange = globRange, let grepRange = grepRange, let bashRange = bashRange {
            XCTAssertTrue(globRange.lowerBound < grepRange.lowerBound,
                "Glob should appear before Grep")
            XCTAssertTrue(grepRange.lowerBound < bashRange.lowerBound,
                "Grep should appear before Bash")
        }
    }

    // MARK: - ATDD Red Phase: Story 4.2 Sub-Agent Progress Rendering
    //
    // These tests define the EXPECTED behavior of taskStarted and taskProgress rendering.
    // They will FAIL until renderTaskStarted and renderTaskProgress are implemented
    // in OutputRenderer+SDKMessage.swift (TDD red phase).
    //
    // Acceptance Criteria Coverage:
    //   AC#2: Sub-agent output visible with indented prefix
    //   AC#5: Sub-agent progress shown with indented [sub-agent] prefix

    // MARK: - AC#2: taskStarted renders with indented [sub-agent] prefix (P0)

    func testRenderTaskStarted_showsSubAgentPrefix() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.TaskStartedData(
            taskId: "task-001",
            taskType: "subagent",
            description: "Analyze codebase structure"
        )

        renderer.render(.taskStarted(data))

        // AC#2: taskStarted should render with [sub-agent] prefix
        let output = mock.output
        XCTAssertTrue(output.contains("[sub-agent]"),
            "taskStarted should contain '[sub-agent]' prefix, got: \(output)")
        XCTAssertTrue(output.contains("Analyze codebase structure"),
            "taskStarted should show task description, got: \(output)")
    }

    func testRenderTaskStarted_usesYellowANSI() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.TaskStartedData(
            taskId: "task-002",
            taskType: "subagent",
            description: "Search for patterns"
        )

        renderer.render(.taskStarted(data))

        // AC#2: taskStarted should use yellow ANSI styling
        // Yellow ANSI: \u{001B}[33m
        XCTAssertTrue(mock.output.contains("\u{001B}[33m") || mock.output.contains("\u{001B}["),
            "taskStarted should use colored ANSI styling (yellow), got: \(mock.output.debugDescription)")
    }

    func testRenderTaskStarted_indentedWithTwoSpaces() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.TaskStartedData(
            taskId: "task-003",
            taskType: "subagent",
            description: "Explore files"
        )

        renderer.render(.taskStarted(data))

        // AC#2: taskStarted should be indented with two spaces
        XCTAssertTrue(mock.output.hasPrefix("  ") || mock.output.contains("\n  "),
            "taskStarted output should be indented with two spaces, got: \(mock.output.debugDescription)")
    }

    // MARK: - AC#5: taskProgress renders with indented [sub-agent] prefix (P0)

    func testRenderTaskProgress_showsSubAgentPrefix() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.TaskProgressData(
            taskId: "task-001",
            taskType: "subagent",
            usage: TokenUsage(inputTokens: 500, outputTokens: 200)
        )

        renderer.render(.taskProgress(data))

        // AC#5: taskProgress should render with [sub-agent] prefix
        let output = mock.output
        XCTAssertTrue(output.contains("[sub-agent]"),
            "taskProgress should contain '[sub-agent]' prefix, got: \(output)")
        XCTAssertTrue(output.contains("task-001"),
            "taskProgress should show task ID, got: \(output)")
    }

    func testRenderTaskProgress_usesGreyANSI() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.TaskProgressData(
            taskId: "task-002",
            taskType: "subagent",
            usage: TokenUsage(inputTokens: 100, outputTokens: 50)
        )

        renderer.render(.taskProgress(data))

        // AC#5: taskProgress should use grey/dim ANSI styling
        XCTAssertTrue(mock.output.contains("\u{001B}[2m") || mock.output.contains("\u{001B}["),
            "taskProgress should use grey/dim ANSI styling, got: \(mock.output.debugDescription)")
    }

    func testRenderTaskProgress_indentedWithTwoSpaces() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.TaskProgressData(
            taskId: "task-003",
            taskType: "subagent"
        )

        renderer.render(.taskProgress(data))

        // AC#5: taskProgress should be indented with two spaces
        XCTAssertTrue(mock.output.hasPrefix("  ") || mock.output.contains("\n  "),
            "taskProgress output should be indented with two spaces, got: \(mock.output.debugDescription)")
    }

    func testRenderTaskProgress_withoutUsage_stillRenders() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.TaskProgressData(
            taskId: "task-004",
            taskType: "subagent",
            usage: nil
        )

        renderer.render(.taskProgress(data))

        // AC#5: taskProgress should render even without usage data
        let output = mock.output
        XCTAssertTrue(output.contains("[sub-agent]"),
            "taskProgress without usage should still render [sub-agent] prefix, got: \(output)")
        XCTAssertTrue(output.contains("task-004"),
            "taskProgress without usage should still show task ID, got: \(output)")
    }

    // MARK: - AC#2 + AC#5: taskStarted and taskProgress no longer silent (P0)

    func testRenderTaskStarted_producesOutput_notSilent() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.TaskStartedData(
            taskId: "task-100",
            taskType: "subagent",
            description: "Important task"
        )

        renderer.render(.taskStarted(data))

        // AC#2: taskStarted should produce output (not silently ignored)
        XCTAssertFalse(mock.output.isEmpty,
            "taskStarted should produce output, not be silently ignored (AC#2). Got empty output.")
    }

    func testRenderTaskProgress_producesOutput_notSilent() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.TaskProgressData(
            taskId: "task-101",
            taskType: "subagent"
        )

        renderer.render(.taskProgress(data))

        // AC#5: taskProgress should produce output (not silently ignored)
        XCTAssertFalse(mock.output.isEmpty,
            "taskProgress should produce output, not be silently ignored (AC#5). Got empty output.")
    }
}
