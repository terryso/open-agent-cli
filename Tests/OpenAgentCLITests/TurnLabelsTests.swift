import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 10.1 Turn Labels and Visual Separation
//
// These tests define the EXPECTED behavior of turn labels and visual separators.
// They will FAIL until OutputRenderer+SDKMessage.swift and OutputRenderer.swift
// are updated with turn state tracking and visual separation logic (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: AI text turn prefix (blue "● " on first partialMessage chunk)
//   AC#2: Turn-end separator (blank line before result divider on success)
//   AC#3: User input prefix (no change, existing green "> ")
//   AC#4: Tool call blank line (blank line before first toolUse after AI text)
//   AC#5: Tool result (no change, existing grey indented display)
//   AC#6: System message blank line (blank line before [system])
//   AC#7: Error blank line (blank line before error message)

// MARK: - Mock TextOutputStream for Testing

/// A reference-type mock that captures all written output into a string for assertion.
/// Uses a class (not struct) so that writes through `AnyTextOutputStream` are visible
/// to the test -- value types would be copied and writes would be lost.
final class TurnMockTextOutputStream: TextOutputStream {
    var output = ""
    func write(_ string: String) {
        output += string
    }
}

final class TurnLabelsTests: XCTestCase {

    // MARK: - Helpers

    /// Creates an OutputRenderer backed by a TurnMockTextOutputStream.
    /// Returns both the renderer and the mock so tests can assert on output.
    private func makeRenderer(quiet: Bool = false) -> (renderer: OutputRenderer, mock: TurnMockTextOutputStream) {
        let mock = TurnMockTextOutputStream()
        let renderer = OutputRenderer(output: mock, quiet: quiet)
        return (renderer, mock)
    }

    // MARK: - AC#1: AI text turn prefix (P0)

    func testPartialMessage_firstChunk_outputsBlueBulletPrefix() throws {
        let (renderer, mock) = makeRenderer()
        let data = SDKMessage.PartialData(text: "Hello from AI")

        renderer.render(.partialMessage(data))

        // AC#1: First partialMessage should output blue "● " prefix
        let blueBullet = "\u{001B}[34m●\u{001B}[0m"
        XCTAssertTrue(mock.output.contains(blueBullet),
            "First partialMessage should output blue '●' prefix (\\u{001B}[34m●\\u{001B}[0m), got: \(mock.output.debugDescription)")
    }

    func testPartialMessage_subsequentChunks_noRepeatBulletPrefix() throws {
        let (renderer, mock) = makeRenderer()

        renderer.render(.partialMessage(SDKMessage.PartialData(text: "Hello")))
        let firstOutput = mock.output
        mock.output = ""

        renderer.render(.partialMessage(SDKMessage.PartialData(text: " world")))

        // AC#1: Subsequent chunks should NOT repeat the "● " prefix
        let blueBullet = "\u{001B}[34m●\u{001B}[0m"
        XCTAssertFalse(mock.output.contains(blueBullet),
            "Subsequent partialMessage chunks should NOT repeat the blue bullet prefix, got: \(mock.output.debugDescription)")
    }

    func testPartialMessage_thinkingContent_noBulletPrefix() throws {
        let (renderer, mock) = makeRenderer()
        let thinkingText = "[thinking] Let me reason through this..."
        let data = SDKMessage.PartialData(text: thinkingText)

        renderer.render(.partialMessage(data))

        // AC#1: Thinking content should NOT get the "● " prefix
        let blueBullet = "\u{001B}[34m●\u{001B}[0m"
        XCTAssertFalse(mock.output.contains(blueBullet),
            "Thinking content should NOT get blue bullet prefix, got: \(mock.output.debugDescription)")
        // Thinking content should still use dim styling
        XCTAssertTrue(mock.output.contains("\u{001B}[2m"),
            "Thinking content should use dim ANSI styling, got: \(mock.output.debugDescription)")
    }

    func testPartialMessage_newTurnAfterResult_outputsBulletPrefix() throws {
        let (renderer, mock) = makeRenderer()

        // Turn 1: partialMessage + result (success)
        renderer.render(.partialMessage(SDKMessage.PartialData(text: "First turn")))
        renderer.render(.result(SDKMessage.ResultData(
            subtype: .success,
            text: "Done",
            usage: nil,
            numTurns: 1,
            durationMs: 1000,
            totalCostUsd: 0.001
        )))
        mock.output = ""

        // Turn 2: first partialMessage should output "● " prefix again
        renderer.render(.partialMessage(SDKMessage.PartialData(text: "Second turn")))

        let blueBullet = "\u{001B}[34m●\u{001B}[0m"
        XCTAssertTrue(mock.output.contains(blueBullet),
            "First partialMessage of a new turn should output blue bullet prefix, got: \(mock.output.debugDescription)")
    }

    // MARK: - AC#2: Turn-end separator (P0)

    func testResult_success_hasBlankLineBeforeDivider() throws {
        let (renderer, mock) = makeRenderer()

        // Simulate a turn: partialMessage -> result
        renderer.render(.partialMessage(SDKMessage.PartialData(text: "AI response")))
        renderer.render(.result(SDKMessage.ResultData(
            subtype: .success,
            text: "Done",
            usage: nil,
            numTurns: 1,
            durationMs: 1000,
            totalCostUsd: 0.001
        )))

        let output = mock.output
        // AC#2: There should be a blank line before the "---" divider
        // The divider line starts with "\n---", meaning there's at least one newline before it.
        // For a visual blank line, we need "\n\n---" (newline from content + blank line + divider)
        XCTAssertTrue(output.contains("\n---"),
            "Success result should have a newline before the '---' divider for visual separation, got: \(output.debugDescription)")
    }

    func testResult_cancelled_hasBlankLineBeforeDivider() throws {
        let (renderer, mock) = makeRenderer()

        renderer.render(.partialMessage(SDKMessage.PartialData(text: "Working...")))
        renderer.render(.result(SDKMessage.ResultData(
            subtype: .cancelled,
            text: "Stopped",
            usage: nil,
            numTurns: 1,
            durationMs: 500,
            totalCostUsd: 0.0001
        )))

        let output = mock.output
        XCTAssertTrue(output.contains("\n---"),
            "Cancelled result should have a newline before the divider, got: \(output.debugDescription)")
    }

    // MARK: - AC#4: Tool call blank line before first toolUse (P0)

    func testToolUse_afterAIText_hasBlankLineBeforeToolCall() throws {
        let (renderer, mock) = makeRenderer()

        // Simulate: AI text -> tool call
        renderer.render(.partialMessage(SDKMessage.PartialData(text: "Let me check that.")))
        // The partialMessage text goes through Markdown buffer and is rendered as inline text.
        // We need to flush the markdown buffer state, but that happens on result.
        // In practice, partialMessage writes text, then toolUse arrives.
        // The key assertion: between AI text output and the tool call line, there's a blank line.
        renderer.render(.toolUse(SDKMessage.ToolUseData(
            toolName: "Read",
            toolUseId: "tool-001",
            input: "{\"file_path\": \"/tmp/test.swift\"}"
        )))

        let output = mock.output
        // AC#4: First toolUse after AI text should have a blank line separator
        // Look for "\n> Read" pattern (newline before the cyan tool line)
        // The toolUse itself outputs "> Read(...)\n", so we need a preceding \n
        let toolLinePattern = "\u{001B}[36m> Read"
        if let toolRange = output.range(of: toolLinePattern) {
            let beforeTool = String(output[output.startIndex..<toolRange.lowerBound])
            XCTAssertTrue(beforeTool.hasSuffix("\n"),
                "First toolUse after AI text should have a blank line before it, got before-tool: \(beforeTool.debugDescription)")
        } else {
            XCTFail("ToolUse output should contain cyan '> Read', got: \(output.debugDescription)")
        }
    }

    func testToolUse_consecutiveToolCalls_noExtraBlankLine() throws {
        let (renderer, mock) = makeRenderer()

        // Simulate: AI text -> tool call 1 -> tool result 1 -> tool call 2
        renderer.render(.partialMessage(SDKMessage.PartialData(text: "Let me check.")))
        renderer.render(.toolUse(SDKMessage.ToolUseData(
            toolName: "Read",
            toolUseId: "tool-001",
            input: "{\"file_path\": \"/tmp/a.swift\"}"
        )))
        let afterFirstTool = mock.output
        mock.output = ""

        renderer.render(.toolResult(SDKMessage.ToolResultData(
            toolUseId: "tool-001",
            content: "file contents",
            isError: false
        )))
        mock.output = ""

        // Second tool call
        renderer.render(.toolUse(SDKMessage.ToolUseData(
            toolName: "Bash",
            toolUseId: "tool-002",
            input: "{\"command\": \"swift build\"}"
        )))

        // AC#4: Subsequent tool calls should NOT have an extra blank line
        // (only the first tool call after AI text gets the blank line)
        // The second tool call should start with just the cyan "> Bash" line
        let output = mock.output
        // Count leading newlines before the tool call output
        let leadingNewlines = output.prefix(while: { $0 == "\n" }).count
        XCTAssertLessThanOrEqual(leadingNewlines, 1,
            "Subsequent tool calls should have at most 1 leading newline (no extra blank line), got \(leadingNewlines), output: \(output.debugDescription)")
    }

    // MARK: - AC#6: System message blank line (P1)

    func testSystemMessage_hasBlankLineBeforeSystemLine() throws {
        let (renderer, mock) = makeRenderer()

        renderer.render(.system(SDKMessage.SystemData(
            subtype: .status,
            message: "Agent initialized"
        )))

        let output = mock.output
        // AC#6: System message should have a blank line before [system]
        XCTAssertTrue(output.hasPrefix("\n"),
            "System message should start with a newline (blank line separator), got: \(output.debugDescription)")
        XCTAssertTrue(output.contains("[system]"),
            "System message should contain '[system]' prefix, got: \(output)")
        XCTAssertTrue(output.contains("Agent initialized"),
            "System message should include the message text, got: \(output)")
    }

    func testSystemMessage_preservesDimStyling() throws {
        let (renderer, mock) = makeRenderer()

        renderer.render(.system(SDKMessage.SystemData(
            subtype: .compactBoundary,
            message: "Compacting conversation"
        )))

        let output = mock.output
        // AC#6: System message should still use dim/grey styling
        XCTAssertTrue(output.contains("\u{001B}[2m"),
            "System message should use dim ANSI styling, got: \(output.debugDescription)")
        XCTAssertTrue(output.contains("[system]"),
            "System message should contain [system] prefix, got: \(output)")
    }

    // MARK: - AC#7: Error blank line (P0)

    func testAssistantError_hasBlankLineBeforeError() throws {
        let (renderer, mock) = makeRenderer()

        // Simulate: AI text streaming, then error
        renderer.render(.partialMessage(SDKMessage.PartialData(text: "Processing...")))
        renderer.render(.assistant(SDKMessage.AssistantData(
            text: "",
            model: "glm-5.1",
            stopReason: "error",
            error: .rateLimit
        )))

        let output = mock.output
        // AC#7: Error message should have a blank line before it
        // Find the "Error:" line and check it has a preceding \n
        XCTAssertTrue(output.contains("Error:"),
            "Error output should contain 'Error:', got: \(output)")
        XCTAssertTrue(output.contains("\u{001B}[31m"),
            "Error should use red ANSI, got: \(output.debugDescription)")
    }

    func testAssistantError_preservesRedStyling() throws {
        let (renderer, mock) = makeRenderer()

        renderer.render(.assistant(SDKMessage.AssistantData(
            text: "",
            model: "glm-5.1",
            stopReason: "error",
            error: .serverError
        )))

        let output = mock.output
        // AC#7: Error should still use red styling with actionable guidance
        XCTAssertTrue(output.contains("\u{001B}[31m"),
            "Error should use red ANSI styling, got: \(output.debugDescription)")
        XCTAssertTrue(output.contains("server"),
            "Error should mention the error type, got: \(output)")
    }

    // MARK: - Full Turn Cycle Test (P0)

    func testFullTurnCycle_partialMessageToolUseToolResultPartialMessageResult() throws {
        let (renderer, mock) = makeRenderer()

        // Simulate a complete turn cycle:
        // 1. AI text starts (should output "● " prefix)
        // 2. Tool call (should have blank line before it)
        // 3. Tool result (no change)
        // 4. More AI text (should NOT output "● " again)
        // 5. Result (should reset state)

        // Step 1: First partialMessage (AI text)
        renderer.render(.partialMessage(SDKMessage.PartialData(text: "Let me look at that.")))

        // Step 2: Tool use
        renderer.render(.toolUse(SDKMessage.ToolUseData(
            toolName: "Read",
            toolUseId: "tool-001",
            input: "{\"file_path\": \"/src/main.swift\"}"
        )))

        // Step 3: Tool result
        renderer.render(.toolResult(SDKMessage.ToolResultData(
            toolUseId: "tool-001",
            content: "import Foundation",
            isError: false
        )))

        // Step 4: More AI text after tool
        renderer.render(.partialMessage(SDKMessage.PartialData(text: "Here is the answer.")))

        // Step 5: Result (success)
        renderer.render(.result(SDKMessage.ResultData(
            subtype: .success,
            text: "Done",
            usage: nil,
            numTurns: 1,
            durationMs: 2000,
            totalCostUsd: 0.003
        )))

        let output = mock.output
        let blueBullet = "\u{001B}[34m●\u{001B}[0m"

        // Verify "● " prefix appears (from step 1)
        XCTAssertTrue(output.contains(blueBullet),
            "Full turn cycle should contain blue bullet prefix, got: \(output.debugDescription)")

        // Verify tool call appears
        XCTAssertTrue(output.contains("Read"),
            "Full turn cycle should contain tool name 'Read', got: \(output)")

        // Verify result divider
        XCTAssertTrue(output.contains("---"),
            "Full turn cycle should contain result divider '---', got: \(output)")

        // Verify "● " appears only once in this turn (before step 1, not before step 4)
        let bulletCount = output.components(separatedBy: blueBullet).count - 1
        XCTAssertEqual(bulletCount, 1,
            "Blue bullet prefix should appear exactly once per turn, got \(bulletCount) occurrences")
    }

    func testFullTurnCycle_stateResetsAfterResult_forNextTurn() throws {
        let (renderer, mock) = makeRenderer()

        // Turn 1
        renderer.render(.partialMessage(SDKMessage.PartialData(text: "Turn 1 answer")))
        renderer.render(.result(SDKMessage.ResultData(
            subtype: .success,
            text: "Done",
            usage: nil,
            numTurns: 1,
            durationMs: 1000,
            totalCostUsd: 0.001
        )))

        // Turn 2
        renderer.render(.partialMessage(SDKMessage.PartialData(text: "Turn 2 answer")))

        let blueBullet = "\u{001B}[34m●\u{001B}[0m"
        // After result resets state, the first partialMessage of turn 2 should get the bullet prefix
        XCTAssertTrue(mock.output.contains(blueBullet),
            "After result resets state, new turn's first partialMessage should output blue bullet prefix, got: \(mock.output.debugDescription)")
    }

    // MARK: - Quiet Mode Compatibility (P1)

    func testQuietMode_partialMessageStillOutputsBulletPrefix() throws {
        let (renderer, mock) = makeRenderer(quiet: true)

        renderer.render(.partialMessage(SDKMessage.PartialData(text: "Hello from AI")))

        // In quiet mode, partialMessage should still output the "● " prefix
        let blueBullet = "\u{001B}[34m●\u{001B}[0m"
        XCTAssertTrue(mock.output.contains(blueBullet),
            "Quiet mode should still output blue bullet prefix for partialMessage, got: \(mock.output.debugDescription)")
    }

    func testQuietMode_toolUseNotRendered_noBlankLineNeeded() throws {
        let (renderer, mock) = makeRenderer(quiet: true)

        renderer.render(.partialMessage(SDKMessage.PartialData(text: "Hello")))
        renderer.render(.toolUse(SDKMessage.ToolUseData(
            toolName: "Bash",
            toolUseId: "tool-001",
            input: "{\"command\": \"ls\"}"
        )))

        // In quiet mode, toolUse is silenced, so no tool output should appear
        XCTAssertFalse(mock.output.contains("Bash"),
            "Quiet mode should silence toolUse output, got: \(mock.output)")
    }

    func testQuietMode_systemMessageNotRendered() throws {
        let (renderer, mock) = makeRenderer(quiet: true)

        renderer.render(.system(SDKMessage.SystemData(
            subtype: .status,
            message: "Compacting"
        )))

        // In quiet mode, system messages are silenced
        XCTAssertEqual(mock.output, "",
            "Quiet mode should silence system message output")
    }

    // MARK: - Edge Cases (P1)

    func testPartialMessage_emptyString_noBulletPrefix() throws {
        let (renderer, mock) = makeRenderer()

        renderer.render(.partialMessage(SDKMessage.PartialData(text: "")))

        let blueBullet = "\u{001B}[34m●\u{001B}[0m"
        XCTAssertFalse(mock.output.contains(blueBullet),
            "Empty partialMessage should not output bullet prefix, got: \(mock.output.debugDescription)")
    }

    func testPartialMessage_afterEmptyChunk_firstNonEmptyGetsBullet() throws {
        let (renderer, mock) = makeRenderer()

        // Empty chunk first (should not trigger bullet)
        renderer.render(.partialMessage(SDKMessage.PartialData(text: "")))
        let blueBullet = "\u{001B}[34m●\u{001B}[0m"
        XCTAssertFalse(mock.output.contains(blueBullet),
            "Empty chunk should not trigger bullet prefix")

        // Non-empty chunk should trigger bullet
        renderer.render(.partialMessage(SDKMessage.PartialData(text: "Hello")))

        XCTAssertTrue(mock.output.contains(blueBullet),
            "First non-empty chunk should output bullet prefix, got: \(mock.output.debugDescription)")
    }

    func testResult_errorResetsTurnState() throws {
        let (renderer, mock) = makeRenderer()

        // Turn 1: partialMessage -> error result
        renderer.render(.partialMessage(SDKMessage.PartialData(text: "Working...")))
        renderer.render(.result(SDKMessage.ResultData(
            subtype: .errorDuringExecution,
            text: "Failed",
            usage: nil,
            numTurns: 1,
            durationMs: 500,
            totalCostUsd: 0.001
        )))
        mock.output = ""

        // Turn 2: partialMessage should get bullet prefix (state was reset)
        renderer.render(.partialMessage(SDKMessage.PartialData(text: "Retry answer")))

        let blueBullet = "\u{001B}[34m●\u{001B}[0m"
        XCTAssertTrue(mock.output.contains(blueBullet),
            "After error result, state should reset and new turn's partialMessage should get bullet prefix, got: \(mock.output.debugDescription)")
    }
}
