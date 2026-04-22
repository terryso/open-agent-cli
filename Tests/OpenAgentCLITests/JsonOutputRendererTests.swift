import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 7.2 JSON Output Mode
//
// These tests define the EXPECTED behavior of JsonOutputRenderer and the
// --output json CLI flag. They will FAIL until JsonOutputRenderer.swift is
// created and CLI.swift is updated to use it when args.output == "json".
//
// Acceptance Criteria Coverage:
//   AC#1: --output json -> result as JSON with text, toolCalls, cost, turns
//   AC#2: Error in JSON mode -> {"error": "..."} to stdout
//   AC#3: No intermediate streaming output in JSON mode
//   AC#4: JSON is sole stdout content, exit code 0 on success
//   AC#5: --output json --quiet == --output json

// MARK: - Mock TextOutputStream for Testing

/// A reference-type mock that captures all written output into a string for assertion.
/// Uses a class (not struct) so that writes through `AnyTextOutputStream` are visible
/// to the test -- value types would be copied and writes would be lost.
///
/// Reuses the same MockTextOutputStream pattern from OutputRendererTests.
final class JsonMockTextOutputStream: TextOutputStream {
    var output = ""
    func write(_ string: String) {
        output += string
    }
}

final class JsonOutputRendererTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a JsonOutputRenderer backed by a JsonMockTextOutputStream.
    /// Returns both the renderer and the mock so tests can assert on output.
    private func makeRenderer() -> (renderer: JsonOutputRenderer, mock: JsonMockTextOutputStream) {
        let mock = JsonMockTextOutputStream()
        let renderer = JsonOutputRenderer(output: mock)
        return (renderer, mock)
    }

    /// Creates a successful QueryResult for testing.
    private func makeSuccessResult(
        text: String = "Hello from agent",
        numTurns: Int = 1,
        totalCostUsd: Double = 0.005,
        durationMs: Int = 1200,
        messages: [SDKMessage] = []
    ) -> QueryResult {
        QueryResult(
            text: text,
            usage: TokenUsage(inputTokens: 100, outputTokens: 50),
            numTurns: numTurns,
            durationMs: durationMs,
            messages: messages,
            status: .success,
            totalCostUsd: totalCostUsd
        )
    }

    /// Creates an error QueryResult for testing.
    private func makeErrorResult(
        status: QueryStatus = .errorDuringExecution,
        numTurns: Int = 1,
        totalCostUsd: Double = 0.003,
        durationMs: Int = 500,
        messages: [SDKMessage] = []
    ) -> QueryResult {
        QueryResult(
            text: "",
            usage: TokenUsage(inputTokens: 50, outputTokens: 20),
            numTurns: numTurns,
            durationMs: durationMs,
            messages: messages,
            status: status,
            totalCostUsd: totalCostUsd
        )
    }

    /// Parses captured output as JSON. Fails the test if output is not valid JSON.
    private func parseJson(_ output: String) throws -> [String: Any] {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("Output is not valid JSON object: \(output)")
            return [:]
        }
        return json
    }

    // MARK: - AC#1: Successful JSON Output with Required Fields (P0)

    func testSuccessQuery_outputsValidJson() throws {
        // AC#1: Given --output json, when query succeeds, output is valid JSON
        let (renderer, mock) = makeRenderer()
        let result = makeSuccessResult()

        renderer.renderSingleShotJson(result)

        let json = try parseJson(mock.output)
        XCTAssertFalse(json.isEmpty, "Output should be a non-empty JSON object (AC#1)")
    }

    func testSuccessQuery_jsonHasRequiredFields() throws {
        // AC#1: JSON must contain text, toolCalls, cost, turns
        let (renderer, mock) = makeRenderer()
        let result = makeSuccessResult(text: "Test response", numTurns: 3, totalCostUsd: 0.0123)

        renderer.renderSingleShotJson(result)

        let json = try parseJson(mock.output)
        XCTAssertNotNil(json["text"], "JSON must have 'text' field (AC#1)")
        XCTAssertNotNil(json["toolCalls"], "JSON must have 'toolCalls' field (AC#1)")
        XCTAssertNotNil(json["cost"], "JSON must have 'cost' field (AC#1)")
        XCTAssertNotNil(json["turns"], "JSON must have 'turns' field (AC#1)")
    }

    func testSuccessQuery_textFieldContainsAgentResponse() throws {
        // AC#1: text field contains the agent's text response
        let (renderer, mock) = makeRenderer()
        let expectedText = "The answer is 42."
        let result = makeSuccessResult(text: expectedText)

        renderer.renderSingleShotJson(result)

        let json = try parseJson(mock.output)
        XCTAssertEqual(json["text"] as? String, expectedText,
            "JSON 'text' field should contain agent response (AC#1)")
    }

    func testSuccessQuery_toolCallsExtracted() throws {
        // AC#1: tool calls are extracted from messages into JSON array
        let (renderer, mock) = makeRenderer()

        let toolUseData = SDKMessage.ToolUseData(
            toolName: "Bash",
            toolUseId: "tu-001",
            input: "{\"command\": \"ls -la\"}"
        )
        let toolResultData = SDKMessage.ToolResultData(
            toolUseId: "tu-001",
            content: "file1.txt\nfile2.txt",
            isError: false
        )
        let messages: [SDKMessage] = [
            .toolUse(toolUseData),
            .toolResult(toolResultData),
        ]
        let result = makeSuccessResult(messages: messages)

        renderer.renderSingleShotJson(result)

        let json = try parseJson(mock.output)
        let toolCalls = json["toolCalls"] as? [[String: Any]]
        XCTAssertNotNil(toolCalls, "toolCalls should be an array of objects (AC#1)")
        XCTAssertEqual(toolCalls?.count, 1, "Should extract 1 tool call (AC#1)")
        XCTAssertEqual(toolCalls?.first?["name"] as? String, "Bash",
            "Tool call name should be 'Bash' (AC#1)")
    }

    // MARK: - AC#2: Error JSON Output (P0)

    func testErrorQuery_outputsErrorJson() throws {
        // AC#2: Error query outputs {"error": "..."} format to stdout
        let (renderer, mock) = makeRenderer()
        let result = makeErrorResult(status: .errorDuringExecution)

        renderer.renderSingleShotJson(result)

        let json = try parseJson(mock.output)
        XCTAssertNotNil(json["error"], "Error output must have 'error' field (AC#2)")
        guard let errorMsg = json["error"] as? String else {
            XCTFail("Error field should be a string (AC#2)")
            return
        }
        XCTAssertFalse(errorMsg.isEmpty, "Error message should not be empty (AC#2)")
    }

    func testCancelledQuery_outputsErrorJson() throws {
        // AC#2: Cancelled query outputs error JSON
        let (renderer, mock) = makeRenderer()
        let result = makeErrorResult(status: .cancelled)

        renderer.renderSingleShotJson(result)

        let json = try parseJson(mock.output)
        XCTAssertNotNil(json["error"], "Cancelled output must have 'error' field (AC#2)")
    }

    func testMaxBudgetError_outputsErrorJson() throws {
        // AC#2: Budget exceeded outputs error JSON
        let (renderer, mock) = makeRenderer()
        let result = makeErrorResult(status: .errorMaxBudgetUsd)

        renderer.renderSingleShotJson(result)

        let json = try parseJson(mock.output)
        XCTAssertNotNil(json["error"], "Budget exceeded output must have 'error' field (AC#2)")
    }

    // MARK: - AC#3: No Intermediate Streaming Output (P1)

    func testRender_silencesAllIntermediateMessages() {
        // AC#3: render() produces no output for any SDKMessage type in JSON mode
        let (renderer, mock) = makeRenderer()

        // Send various SDKMessage types that would normally produce output
        renderer.render(.partialMessage(SDKMessage.PartialData(text: "partial text")))
        renderer.render(.assistant(SDKMessage.AssistantData(
            text: "response", model: "claude", stopReason: "end_turn"
        )))
        renderer.render(.system(SDKMessage.SystemData(
            subtype: .status, message: "system msg"
        )))
        renderer.render(.toolUse(SDKMessage.ToolUseData(
            toolName: "Bash", toolUseId: "tu-001", input: "{}"
        )))
        renderer.render(.toolResult(SDKMessage.ToolResultData(
            toolUseId: "tu-001", content: "result", isError: false
        )))
        renderer.render(.result(SDKMessage.ResultData(
            subtype: .success,
            text: "done",
            usage: nil,
            numTurns: 1,
            durationMs: 100,
            totalCostUsd: 0.01
        )))

        XCTAssertTrue(mock.output.isEmpty,
            "render() should produce NO output in JSON mode -- all intermediate content silenced (AC#3)")
    }

    func testRenderStream_silencesIntermediateAndOutputsFinalJson() async throws {
        // AC#3: renderStream() produces no output during streaming
        let (renderer, mock) = makeRenderer()

        let stream = AsyncStream<SDKMessage> { continuation in
            continuation.yield(.partialMessage(SDKMessage.PartialData(text: "chunk 1")))
            continuation.yield(.partialMessage(SDKMessage.PartialData(text: "chunk 2")))
            continuation.yield(.toolUse(SDKMessage.ToolUseData(
                toolName: "Read", toolUseId: "tu-002", input: "{\"path\": \"/tmp/test\"}"
            )))
            continuation.yield(.toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-002", content: "file content", isError: false
            )))
            continuation.yield(.result(SDKMessage.ResultData(
                subtype: .success,
                text: "done",
                usage: nil,
                numTurns: 1,
                durationMs: 100,
                totalCostUsd: 0.01
            )))
            continuation.finish()
        }

        await renderer.renderStream(stream)

        // In JSON mode, basic renderStream should produce no output
        // (collectAndRender would produce final JSON, but renderStream is silent)
        XCTAssertTrue(mock.output.isEmpty,
            "renderStream() should produce NO intermediate output in JSON mode (AC#3)")
    }

    // MARK: - AC#4: stdout Purity (P1)

    func testSuccessQuery_noNonJsonOutputOnStdout() throws {
        // AC#4: JSON output is the sole content of stdout -- no ANSI codes, no extra text
        let (renderer, mock) = makeRenderer()
        let result = makeSuccessResult(text: "Clean response")

        renderer.renderSingleShotJson(result)

        let output = mock.output.trimmingCharacters(in: .whitespacesAndNewlines)

        // Should not contain ANSI escape codes
        XCTAssertFalse(output.contains("\u{001B}["), "JSON output must not contain ANSI codes (AC#4)")

        // Should be parseable as JSON
        let json = try parseJson(output)
        XCTAssertNotNil(json["text"], "Output should be valid JSON with text field (AC#4)")

        // Should not contain non-JSON text like "--- Turns:" summary lines
        XCTAssertFalse(output.contains("---"), "JSON output must not contain text-mode summary lines (AC#4)")
        XCTAssertFalse(output.contains("Turns:"), "JSON output must not contain text-mode summary (AC#4)")
    }

    func testErrorQuery_noNonJsonOutputOnStdout() throws {
        // AC#4: Error JSON is the sole content of stdout
        let (renderer, mock) = makeRenderer()
        let result = makeErrorResult(status: .errorMaxTurns)

        renderer.renderSingleShotJson(result)

        let output = mock.output.trimmingCharacters(in: .whitespacesAndNewlines)

        // Should not contain ANSI escape codes
        XCTAssertFalse(output.contains("\u{001B}["), "Error JSON must not contain ANSI codes (AC#4)")

        // Should be parseable as JSON
        let json = try parseJson(output)
        XCTAssertNotNil(json["error"], "Error output should have 'error' field (AC#4)")
    }

    // MARK: - AC#5: --output json + --quiet Combination (P2)

    func testQuietCombination_sameAsJsonOnly() throws {
        // AC#5: --output json --quiet produces identical output to --output json
        let (renderer1, mock1) = makeRenderer()
        let (renderer2, mock2) = makeRenderer()
        let result = makeSuccessResult(text: "Same output", numTurns: 2, totalCostUsd: 0.01)

        // Simulate --output json (no quiet effect since JsonOutputRenderer ignores quiet)
        renderer1.renderSingleShotJson(result)

        // Simulate --output json --quiet (same renderer, quiet is irrelevant for JSON mode)
        renderer2.renderSingleShotJson(result)

        XCTAssertEqual(mock1.output, mock2.output,
            "--output json and --output json --quiet should produce identical output (AC#5)")
    }

    // MARK: - Additional Coverage (P2/P3)

    func testEmptyToolCalls_emptyArray() throws {
        // When no tool calls in messages, toolCalls should be []
        let (renderer, mock) = makeRenderer()
        let result = makeSuccessResult(text: "No tools used", messages: [])

        renderer.renderSingleShotJson(result)

        let json = try parseJson(mock.output)
        let toolCalls = json["toolCalls"] as? [[String: Any]]
        XCTAssertEqual(toolCalls?.count, 0,
            "No tool calls should produce empty array (AC#1)")
    }

    func testToolCallInput_preservedAsRawString() throws {
        // Tool call input should be preserved as raw string, not parsed
        let (renderer, mock) = makeRenderer()
        let rawInput = "{\"command\": \"echo 'hello'\", \"timeout\": 30}"
        let messages: [SDKMessage] = [
            .toolUse(SDKMessage.ToolUseData(
                toolName: "Bash", toolUseId: "tu-003", input: rawInput
            )),
        ]
        let result = makeSuccessResult(messages: messages)

        renderer.renderSingleShotJson(result)

        let json = try parseJson(mock.output)
        let toolCalls = json["toolCalls"] as? [[String: Any]]
        XCTAssertEqual(toolCalls?.first?["input"] as? String, rawInput,
            "Tool call input should be preserved as raw string")
    }

    // MARK: - Regression (P3)

    func testRegression_textModeStillWorks() {
        // Verify that text mode OutputRenderer is not affected by JsonOutputRenderer
        let mock = JsonMockTextOutputStream()
        let renderer = OutputRenderer(output: mock)

        renderer.render(.partialMessage(SDKMessage.PartialData(text: "Hello")))

        // Text mode should still produce output (not silenced)
        XCTAssertFalse(mock.output.isEmpty,
            "Text mode OutputRenderer should still produce output (regression)")
    }

    func testRegression_existingOutputRendererTestsPass() {
        // This is a meta-test: the existence of JsonOutputRenderer should not
        // break existing OutputRenderer behavior. The actual regression check
        // is that the existing OutputRendererTests suite still passes.
        //
        // We verify the OutputRendering protocol is still implemented correctly:
        let mock = JsonMockTextOutputStream()
        let textRenderer = OutputRenderer(output: mock)

        // text mode renders partial messages
        textRenderer.render(.partialMessage(SDKMessage.PartialData(text: "test")))
        XCTAssertTrue(mock.output.contains("test"),
            "Text mode should render partial messages (regression)")
    }
}
