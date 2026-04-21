import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 6.4 Thinking Configuration and Quiet Mode
//
// These tests define the EXPECTED behavior of quiet mode filtering and
// thinking configuration. Tests for quiet mode (AC#2) and thinking output
// display (AC#3) will FAIL until OutputRenderer is updated to support
// the quiet property and thinking dim styling.
//
// Tests for AC#1 (--thinking argument parsing and config conversion) PASS
// because that feature was already implemented in Story 1.2.
//
// Acceptance Criteria Coverage:
//   AC#1: --thinking flag configures AgentOptions.thinking with token budget
//   AC#2: --quiet suppresses non-essential output (tool calls, system, success results)
//   AC#3: Thinking output displayed in dim/different style

final class ThinkingAndQuietModeTests: XCTestCase {

    // MARK: - Helpers

    /// Creates an OutputRenderer backed by a MockTextOutputStream.
    /// Returns both the renderer and the mock so tests can assert on output.
    private func makeRenderer(quiet: Bool = false) -> (renderer: OutputRenderer, mock: MockTextOutputStream) {
        let mock = MockTextOutputStream()
        let renderer = OutputRenderer(output: mock, quiet: quiet)
        return (renderer, mock)
    }

    // MARK: - AC#1: --thinking Flag Configuration (4 tests)

    // NOTE: These tests validate existing behavior from Story 1.2.
    // The --thinking parsing and ThinkingConfig conversion were already implemented.

    func testThinkingArg_parsesCorrectly() throws {
        let result = ArgumentParser.parse(["openagent", "--thinking", "8192", "hello"])

        XCTAssertEqual(result.thinking, 8192,
            "--thinking 8192 should parse as ParsedArgs.thinking = 8192")
    }

    func testThinkingArg_invalidValue_returnsError() throws {
        let result = ArgumentParser.parse(["openagent", "--thinking", "abc"])

        XCTAssertTrue(result.shouldExit,
            "Invalid --thinking value should signal shouldExit")
        XCTAssertEqual(result.exitCode, 1,
            "Invalid --thinking value should exit with code 1")
        XCTAssertNotNil(result.errorMessage,
            "Invalid --thinking value should produce an error message")
    }

    func testThinkingArg_zero_returnsError() throws {
        let result = ArgumentParser.parse(["openagent", "--thinking", "0"])

        XCTAssertTrue(result.shouldExit,
            "--thinking 0 should signal shouldExit (must be positive)")
        XCTAssertEqual(result.exitCode, 1,
            "--thinking 0 should exit with code 1")
    }

    func testThinkingArg_notSpecified_nil() throws {
        let result = ArgumentParser.parse(["openagent", "hello"])

        XCTAssertNil(result.thinking,
            "No --thinking flag should leave thinking = nil")
    }

    // MARK: - AC#2: Quiet Mode Filtering (8 tests)

    // NOTE: These tests will FAIL until OutputRenderer gains a `quiet` property
    // and the render() method adds quiet-mode filtering logic.

    func testQuietMode_rendersPartialMessage() throws {
        let (renderer, mock) = makeRenderer(quiet: true)
        let data = SDKMessage.PartialData(text: "Hello from agent")

        renderer.render(.partialMessage(data))

        // In quiet mode, partialMessage text should still be rendered.
        // This is the primary user-facing content stream.
        XCTAssertEqual(mock.output, "Hello from agent",
            "Quiet mode should still render .partialMessage text")
    }

    func testQuietMode_silencesToolUse() throws {
        let (renderer, mock) = makeRenderer(quiet: true)
        let data = SDKMessage.ToolUseData(
            toolName: "read_file",
            toolUseId: "tu-1",
            input: "{\"path\": \"/tmp/test.txt\"}"
        )

        renderer.render(.toolUse(data))

        // In quiet mode, tool use events should produce no output.
        XCTAssertEqual(mock.output, "",
            "Quiet mode should silence .toolUse output")
    }

    func testQuietMode_silencesToolResult() throws {
        let (renderer, mock) = makeRenderer(quiet: true)
        let data = SDKMessage.ToolResultData(
            toolUseId: "tu-1",
            content: "file contents here",
            isError: false
        )

        renderer.render(.toolResult(data))

        // In quiet mode, tool result events should produce no output.
        XCTAssertEqual(mock.output, "",
            "Quiet mode should silence .toolResult output")
    }

    func testQuietMode_silencesSystemMessage() throws {
        let (renderer, mock) = makeRenderer(quiet: true)
        let data = SDKMessage.SystemData(
            subtype: .status,
            message: "Agent initialized"
        )

        renderer.render(.system(data))

        // In quiet mode, system messages should produce no output.
        XCTAssertEqual(mock.output, "",
            "Quiet mode should silence .system output")
    }

    func testQuietMode_silencesSuccessResult() throws {
        let (renderer, mock) = makeRenderer(quiet: true)
        let data = SDKMessage.ResultData(
            subtype: .success,
            text: "Done",
            usage: nil,
            numTurns: 3,
            durationMs: 5000,
            totalCostUsd: 0.0023
        )

        renderer.render(.result(data))

        // In quiet mode, success result summaries should be silenced.
        // Only errors should be shown.
        XCTAssertEqual(mock.output, "",
            "Quiet mode should silence successful .result summary output")
    }

    func testQuietMode_rendersErrorResult() throws {
        let (renderer, mock) = makeRenderer(quiet: true)
        let data = SDKMessage.ResultData(
            subtype: .errorDuringExecution,
            text: "Something went wrong",
            usage: nil,
            numTurns: 1,
            durationMs: 1000,
            totalCostUsd: 0.001,
            errors: ["API rate limit exceeded"]
        )

        renderer.render(.result(data))

        // In quiet mode, errors should STILL be rendered.
        // Suppressing errors would hide critical information from the user.
        XCTAssertTrue(mock.output.contains("error") || mock.output.contains("Error") || mock.output.contains("rate"),
            "Quiet mode should still render .result errors, got: \(mock.output)")
        XCTAssertTrue(!mock.output.isEmpty,
            "Quiet mode should produce output for error results")
    }

    func testQuietMode_silencesTaskStarted() throws {
        let (renderer, mock) = makeRenderer(quiet: true)
        let data = SDKMessage.TaskStartedData(
            taskId: "task-1",
            taskType: "subagent",
            description: "Research task"
        )

        renderer.render(.taskStarted(data))

        // In quiet mode, sub-agent task started events should produce no output.
        XCTAssertEqual(mock.output, "",
            "Quiet mode should silence .taskStarted output")
    }

    func testQuietMode_silencesTaskProgress() throws {
        let (renderer, mock) = makeRenderer(quiet: true)
        let data = SDKMessage.TaskProgressData(
            taskId: "task-1",
            taskType: "subagent",
            usage: nil
        )

        renderer.render(.taskProgress(data))

        // In quiet mode, sub-agent task progress events should produce no output.
        XCTAssertEqual(mock.output, "",
            "Quiet mode should silence .taskProgress output")
    }

    // MARK: - AC#3: Thinking Output Display (1 test)

    func testThinkingOutput_dimStyle() throws {
        // When thinking is enabled and the agent produces thinking output,
        // the thinking content should be rendered with dim ANSI styling.
        //
        // This test creates a partial message that could contain thinking text
        // and verifies it uses ANSI.dim styling.
        //
        // Implementation note: The SDK sends thinking content through .partialMessage.
        // If the content is distinguishable (e.g., by prefix or marker), the renderer
        // should wrap it with ANSI.dim(). If not distinguishable, this test documents
        // the desired behavior for when the SDK adds content-type metadata.

        let (renderer, mock) = makeRenderer(quiet: false)

        // Simulate thinking content arriving as partial message.
        // The actual detection heuristic will depend on what the SDK delivers.
        // For now, we test that when thinking content IS detected, it uses dim style.
        let thinkingText = "[thinking] Let me analyze this step by step..."
        let data = SDKMessage.PartialData(text: thinkingText)

        renderer.render(.partialMessage(data))

        // The thinking output should contain ANSI dim escape codes
        let dimEscape = "\u{001B}[2m"
        XCTAssertTrue(mock.output.contains(dimEscape),
            "Thinking output should use ANSI.dim styling (escape code \\u{001B}[2m), got: \(mock.output.debugDescription)")
    }

    // MARK: - Regression Tests (2 tests)

    func testNormalMode_rendersAllMessageTypes() throws {
        // Regression: verify that non-quiet mode still renders all message types.
        // This ensures the quiet flag doesn't accidentally break normal operation.
        let (renderer, mock) = makeRenderer(quiet: false)

        // Render a tool use -- should produce output in normal mode
        renderer.render(.toolUse(SDKMessage.ToolUseData(
            toolName: "read_file",
            toolUseId: "tu-1",
            input: "{\"path\":\"/test\"}"
        )))
        let afterToolUse = mock.output
        XCTAssertTrue(!afterToolUse.isEmpty,
            "Normal mode should produce output for .toolUse")

        // Reset mock and render system -- should produce output in normal mode
        mock.output = ""
        renderer.render(.system(SDKMessage.SystemData(
            subtype: .status,
            message: "Ready"
        )))
        XCTAssertTrue(!mock.output.isEmpty,
            "Normal mode should produce output for .system")

        // Reset mock and render success result -- should produce summary
        mock.output = ""
        renderer.render(.result(SDKMessage.ResultData(
            subtype: .success,
            text: "Done",
            usage: nil,
            numTurns: 1,
            durationMs: 1000,
            totalCostUsd: 0.01
        )))
        XCTAssertTrue(!mock.output.isEmpty,
            "Normal mode should produce output for successful .result")
        XCTAssertTrue(mock.output.contains("Turns:"),
            "Normal mode result should contain summary line with 'Turns:'")
    }

    func testRegression_thinkingArgDoesNotAffectOtherArgs() throws {
        // Verify that --thinking does not interfere with other argument parsing.
        let result = ArgumentParser.parse([
            "openagent", "--thinking", "4096", "--model", "glm-5.1",
            "--max-turns", "5", "--quiet", "hello world"
        ])

        XCTAssertEqual(result.thinking, 4096,
            "--thinking should parse correctly alongside other flags")
        XCTAssertEqual(result.model, "glm-5.1",
            "--model should still parse with --thinking present")
        XCTAssertEqual(result.maxTurns, 5,
            "--max-turns should still parse with --thinking present")
        XCTAssertTrue(result.quiet,
            "--quiet should still parse with --thinking present")
        XCTAssertEqual(result.prompt, "hello world",
            "Positional prompt should still parse with --thinking present")
    }
}
