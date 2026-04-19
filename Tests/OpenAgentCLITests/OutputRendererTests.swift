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
}
