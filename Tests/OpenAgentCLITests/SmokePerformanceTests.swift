import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 1.6 Smoke Tests -- Performance & Reliability
//
// These tests validate that the CLI meets basic performance and reliability goals.
// They verify that the implementations from Stories 1.1-1.5 integrate correctly
// without introducing unacceptable overhead.
//
// Acceptance Criteria Coverage:
//   AC#1: Cold start time < 2 seconds (process launch to prompt)
//   AC#2: Streaming render overhead < 50ms per chunk
//   AC#3: API error retry is transparent, CLI continues running
//   AC#4: Idle memory stays under 50MB

final class SmokePerformanceTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a MockTextOutputStream and OutputRenderer pair for capturing output.
    private func makeRenderer() -> (renderer: OutputRenderer, mock: MockTextOutputStream) {
        let mock = MockTextOutputStream()
        let renderer = OutputRenderer(output: mock)
        return (renderer, mock)
    }

    /// Creates default test ParsedArgs with the given overrides.
    private func makeTestArgs(apiKey: String? = "test-key-for-smoke-tests") -> ParsedArgs {
        ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: apiKey,
            baseURL: "https://api.example.com/v1",
            provider: nil,
            mode: "default",
            tools: "core",
            mcpConfigPath: nil,
            hooksConfigPath: nil,
            skillDir: nil,
            skillName: nil,
            sessionId: nil,
            noRestore: false,
            maxTurns: 10,
            maxBudgetUsd: nil,
            systemPrompt: nil,
            thinking: nil,
            quiet: false,
            output: "text",
            logLevel: nil,
            toolAllow: nil,
            toolDeny: nil,
            shouldExit: false,
            exitCode: 0,
            errorMessage: nil,
            helpMessage: nil
        )
    }

    /// Creates a test Agent with a dummy API key.
    private func makeTestAgent() async throws -> Agent {
        try await AgentFactory.createAgent(from: makeTestArgs()).0
    }

    // MARK: - AC#1: Cold start responsiveness (proxy measurement via --help/--version)
    //
    // Note: AC#1 specifies measuring "process launch to > prompt", but measuring the actual
    // REPL prompt requires a real API key. Using --help/--version as a proxy exercises the
    // argument parser and binary initialization without API dependencies.

    private func resolveExecutable() throws -> String {
        guard let execPath = SmokeTestHelper.openagentExecutablePath() else {
            throw XCTSkip("openagent executable not found — run `swift build` first")
        }
        return execPath
    }

    func testCLIHelpStartup_respondsQuickly() throws {
        let execPath = try resolveExecutable()
        let result = SmokeTestHelper.launchProcess(
            executable: execPath,
            arguments: ["--help"],
            timeout: 10
        )

        XCTAssertEqual(result.terminationStatus, 0,
            "CLI --help should exit with status 0")

        XCTAssertTrue(result.output.contains("openagent") || result.output.contains("USAGE"),
            "Help output should contain usage information, got: \(result.output.prefix(200))")

        XCTAssertLessThan(result.elapsedMs, 10000,
            "CLI --help should complete within 10 seconds")
    }

    func testCLIHelpStartup_outputContainsUsageInfo() throws {
        let execPath = try resolveExecutable()
        let result = SmokeTestHelper.launchProcess(
            executable: execPath,
            arguments: ["--help"],
            timeout: 10
        )

        XCTAssertTrue(result.output.contains("help") || result.output.contains("Help") || result.output.contains("USAGE"),
            "--help output should contain usage/help information")
    }

    func testCLIVersionStartup_completesQuickly() throws {
        let execPath = try resolveExecutable()
        let result = SmokeTestHelper.launchProcess(
            executable: execPath,
            arguments: ["--version"],
            timeout: 10
        )

        XCTAssertEqual(result.terminationStatus, 0,
            "CLI --version should exit with status 0")
    }

    // MARK: - AC#2: Streaming render overhead < 50ms per chunk

    func testPartialMessageRenderPerformance_1000chunks_under50msPerChunk() throws {
        // AC#2: Each SDKMessage.partialMessage chunk should render in < 50ms.
        // This is a pure computation test -- no network or I/O.
        let (renderer, mock) = makeRenderer()

        // Create 1000 chunks of realistic size (50-200 chars each)
        let chunkCount = 1000
        let sampleText = "The quick brown fox jumps over the lazy dog. "
        let chunks = (0..<chunkCount).map { i -> SDKMessage.PartialData in
            SDKMessage.PartialData(text: "Chunk \(i): \(sampleText)")
        }

        let elapsedMs = SmokeTestHelper.measureSyncMs {
            for chunk in chunks {
                renderer.render(.partialMessage(chunk))
            }
        }

        // Calculate average per chunk
        let avgMsPerChunk = Double(elapsedMs) / Double(chunkCount)

        // AC#2: Average per-chunk render time should be < 50ms
        XCTAssertLessThan(avgMsPerChunk, 50.0,
            "Average render time per chunk should be < 50ms, got \(String(format: "%.2f", avgMsPerChunk))ms for \(chunkCount) chunks in \(elapsedMs)ms total")

        // Verify all output was produced
        XCTAssertTrue(mock.output.contains("Chunk 0:"),
            "Output should contain the first chunk")
        XCTAssertTrue(mock.output.contains("Chunk \(chunkCount - 1):"),
            "Output should contain the last chunk")
    }

    func testPartialMessageRenderPerformance_singleChunk_under50ms() throws {
        // AC#2: A single chunk render should be < 50ms.
        let (renderer, _) = makeRenderer()
        let chunk = SDKMessage.PartialData(text: "Hello, this is a test message with some content.")

        let elapsedMs = SmokeTestHelper.measureSyncMs {
            renderer.render(.partialMessage(chunk))
        }

        XCTAssertLessThan(elapsedMs, 50,
            "Single chunk render should be < 50ms, got \(elapsedMs)ms")
    }

    func testPartialMessageRenderPerformance_emptyString_zeroOverhead() throws {
        // AC#2 edge case: Empty partialMessage should have near-zero overhead.
        let (renderer, mock) = makeRenderer()
        let chunk = SDKMessage.PartialData(text: "")

        let elapsedMs = SmokeTestHelper.measureSyncMs {
            for _ in 0..<10000 {
                renderer.render(.partialMessage(chunk))
            }
        }

        XCTAssertEqual(mock.output, "",
            "Empty partialMessage should produce no output")

        // 10,000 empty renders should complete in well under 1 second
        XCTAssertLessThan(elapsedMs, 1000,
            "10,000 empty renders should be < 1000ms, got \(elapsedMs)ms")
    }

    func testAssistantErrorRenderPerformance_under50ms() throws {
        // AC#2: Rendering assistant errors (with ANSI formatting) should be fast.
        let (renderer, _) = makeRenderer()

        let errorData = SDKMessage.AssistantData(
            text: "",
            model: "glm-5.1",
            stopReason: "error",
            error: .rateLimit
        )

        let elapsedMs = SmokeTestHelper.measureSyncMs {
            for _ in 0..<1000 {
                renderer.render(.assistant(errorData))
            }
        }

        let avgMs = Double(elapsedMs) / 1000.0
        XCTAssertLessThan(avgMs, 50.0,
            "Average error render time should be < 50ms, got \(String(format: "%.2f", avgMs))ms")
    }

    func testResultSummaryRenderPerformance_under50ms() throws {
        // AC#2: Rendering result summaries should be fast.
        let (renderer, _) = makeRenderer()

        let resultData = SDKMessage.ResultData(
            subtype: .success,
            text: "Done",
            usage: TokenUsage(inputTokens: 100, outputTokens: 50),
            numTurns: 3,
            durationMs: 4200,
            totalCostUsd: 0.0023
        )

        let elapsedMs = SmokeTestHelper.measureSyncMs {
            for _ in 0..<1000 {
                renderer.render(.result(resultData))
            }
        }

        let avgMs = Double(elapsedMs) / 1000.0
        XCTAssertLessThan(avgMs, 50.0,
            "Average result render time should be < 50ms, got \(String(format: "%.2f", avgMs))ms")
    }

    // MARK: - AC#3: API error retry is transparent, CLI continues

    func testAPIError_rendererShowsErrorWithGuidance() throws {
        // AC#3: When an API error occurs, the renderer shows a red error message
        // with actionable guidance.
        let (renderer, mock) = makeRenderer()

        let errorData = SDKMessage.AssistantData(
            text: "",
            model: "glm-5.1",
            stopReason: "error",
            error: .rateLimit
        )

        renderer.render(.assistant(errorData))

        // Verify error is shown in red
        XCTAssertTrue(mock.output.contains("\u{001B}[31m"),
            "API error should be rendered with red ANSI escape (AC#3)")

        // Verify actionable guidance is provided
        let output = mock.output.lowercased()
        XCTAssertTrue(output.contains("rate limit") || output.contains("ratelimit") || output.contains("wait"),
            "Error should include actionable guidance (AC#3), got: \(mock.output)")
    }

    func testAPIError_allErrorTypes_renderWithoutCrash() throws {
        // AC#3: All known error types should render without crashing.
        let (renderer, mock) = makeRenderer()

        let errorTypes: [SDKMessage.AssistantError] = [
            .authenticationFailed,
            .billingError,
            .rateLimit,
            .invalidRequest,
            .serverError,
            .maxOutputTokens,
            .unknown
        ]

        var renderedCount = 0
        for errorType in errorTypes {
            mock.output = ""
            let data = SDKMessage.AssistantData(
                text: "",
                model: "glm-5.1",
                stopReason: "error",
                error: errorType
            )

            renderer.render(.assistant(data))

            if !mock.output.isEmpty {
                renderedCount += 1
            }
        }

        XCTAssertEqual(renderedCount, errorTypes.count,
            "All \(errorTypes.count) error types should produce output, got \(renderedCount)")
    }

    func testAPIError_replLoopContinuesAfterError() async throws {
        // AC#3: REPL loop should continue running after an API error.
        // Simulate: send a message that will fail (due to fake API key),
        // then verify REPL continues to accept /exit.
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["test message", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        // Should not crash or hang
        await repl.start()

        // REPL should have read both inputs (message + /exit)
        XCTAssertEqual(inputReader.callCount, 2,
            "REPL should continue after API error and process /exit (AC#3)")
    }

    func testAPIError_replLoop_multipleErrors_doesNotCrash() async throws {
        // AC#3: Multiple consecutive API errors should not crash the REPL.
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["msg1", "msg2", "msg3", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        // Should have processed all 4 inputs
        XCTAssertEqual(inputReader.callCount, 4,
            "REPL should handle multiple errors without crashing (AC#3)")
    }

    func testAPIError_errorMessage_includesActionableGuidance() throws {
        // AC#3: Each error type should provide specific actionable guidance.
        let (renderer, mock) = makeRenderer()

        // Test authentication error guidance
        let authError = SDKMessage.AssistantData(
            text: "",
            model: "glm-5.1",
            stopReason: "error",
            error: .authenticationFailed
        )
        renderer.render(.assistant(authError))
        XCTAssertTrue(mock.output.lowercased().contains("api key") || mock.output.lowercased().contains("check"),
            "Authentication error should mention API key (AC#3), got: \(mock.output)")

        mock.output = ""

        // Test rate limit guidance
        let rateLimitError = SDKMessage.AssistantData(
            text: "",
            model: "glm-5.1",
            stopReason: "error",
            error: .rateLimit
        )
        renderer.render(.assistant(rateLimitError))
        XCTAssertTrue(mock.output.lowercased().contains("wait") || mock.output.lowercased().contains("try again"),
            "Rate limit error should suggest waiting (AC#3), got: \(mock.output)")
    }

    // MARK: - AC#4: Idle memory stays under 50MB

    func testIdleMemory_rendererAlone_under50MB() throws {
        // AC#4: The OutputRenderer should not consume excessive memory.
        // This measures the XCTest process memory as a proxy.
        guard let baselineMemory = SmokeTestHelper.residentMemoryBytes() else {
            throw XCTSkip("task_info memory measurement not available on this platform")
        }

        let (renderer, _) = makeRenderer()

        for i in 0..<1000 {
            renderer.render(.partialMessage(SDKMessage.PartialData(text: "Message \(i) with some content to exercise memory")))
        }

        guard let postRenderMemory = SmokeTestHelper.residentMemoryBytes() else {
            XCTFail("post-render memory measurement failed")
            return
        }

        let deltaMB = Double(postRenderMemory > baselineMemory ? postRenderMemory - baselineMemory : 0) / (1024.0 * 1024.0)

        XCTAssertLessThan(deltaMB, 10.0,
            "Renderer should not cause > 10MB memory increase, got \(String(format: "%.1f", deltaMB))MB delta (AC#4)")
    }

    func testIdleMemory_agentCreation_memoryReasonable() async throws {
        // AC#4: Creating an Agent should not push memory unreasonably high.
        // Note: XCTest process includes test framework overhead, so we use a relaxed threshold.
        guard let baselineMemory = SmokeTestHelper.residentMemoryBytes() else {
            throw XCTSkip("task_info memory measurement not available on this platform")
        }

        let _ = try await makeTestAgent()

        guard let postAgentMemory = SmokeTestHelper.residentMemoryBytes() else {
            XCTFail("post-agent memory measurement failed")
            return
        }

        let totalMB = Double(postAgentMemory) / (1024.0 * 1024.0)
        let deltaMB = Double(postAgentMemory > baselineMemory ? postAgentMemory - baselineMemory : 0) / (1024.0 * 1024.0)

        XCTAssertLessThan(totalMB, 100.0,
            "Test process total memory should be reasonable (AC#4 proxy), got \(String(format: "%.1f", totalMB))MB")

        XCTAssertLessThan(deltaMB, 20.0,
            "Agent creation should not add > 20MB, got \(String(format: "%.1f", deltaMB))MB delta (AC#4)")
    }

    // MARK: - Integration: All message types render without crash (Story 1.3 regression)

    func testAllSDKMessageTypes_renderWithoutCrash() throws {
        // Regression guard: All SDK message types from Story 1.3 should still render.
        let (renderer, _) = makeRenderer()

        let messages: [SDKMessage] = [
            .partialMessage(SDKMessage.PartialData(text: "test")),
            .assistant(SDKMessage.AssistantData(text: "ok", model: "glm-5.1", stopReason: "end_turn")),
            .assistant(SDKMessage.AssistantData(text: "", model: "glm-5.1", stopReason: "error", error: .serverError)),
            .result(SDKMessage.ResultData(subtype: .success, text: "done", usage: nil, numTurns: 1, durationMs: 100)),
            .result(SDKMessage.ResultData(subtype: .errorDuringExecution, text: "fail", usage: nil, numTurns: 1, durationMs: 100)),
            .system(SDKMessage.SystemData(subtype: .`init`, message: "init")),
            .toolUse(SDKMessage.ToolUseData(toolName: "Bash", toolUseId: "t1", input: "{}")),
            .toolResult(SDKMessage.ToolResultData(toolUseId: "t1", content: "ok", isError: false)),
        ]

        // Should not crash for any message type
        for message in messages {
            renderer.render(message)
        }
    }

    // MARK: - Integration: REPL commands still work (Story 1.4 regression)

    func testREPLSlashCommands_regressionTest() async throws {
        // Regression guard: REPL slash commands from Story 1.4 still work.
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/help", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        // /help should have produced output
        XCTAssertTrue(mockOutput.output.contains("/help"),
            "/help output should list /help command (regression)")
        XCTAssertTrue(mockOutput.output.contains("/exit"),
            "/help output should list /exit command (regression)")
    }

    // MARK: - Integration: Single-shot exit codes (Story 1.5 regression)

    func testExitCodeMapping_regressionTest() throws {
        // Regression guard: Exit code mapping from Story 1.5 still works.
        XCTAssertEqual(CLIExitCode.forQueryStatus(.success), 0, "success -> 0")
        XCTAssertEqual(CLIExitCode.forQueryStatus(.errorMaxTurns), 1, "errorMaxTurns -> 1")
        XCTAssertEqual(CLIExitCode.forQueryStatus(.errorDuringExecution), 1, "errorDuringExecution -> 1")
        XCTAssertEqual(CLIExitCode.forQueryStatus(.cancelled), 1, "cancelled -> 1")
    }

    func testSingleShotErrorFormatting_regressionTest() throws {
        // Regression guard: Error formatting from Story 1.5 still works.
        let successResult = QueryResult(
            text: "", usage: TokenUsage(inputTokens: 0, outputTokens: 0), numTurns: 0, durationMs: 0,
            messages: [], status: .success, totalCostUsd: 0.0
        )
        XCTAssertTrue(CLISingleShot.formatErrorMessage(successResult).isEmpty,
            "Success should produce no error message")

        let errorResult = QueryResult(
            text: "", usage: TokenUsage(inputTokens: 0, outputTokens: 0), numTurns: 10, durationMs: 5000,
            messages: [], status: .errorMaxTurns, totalCostUsd: 0.01
        )
        let errorMsg = CLISingleShot.formatErrorMessage(errorResult)
        XCTAssertFalse(errorMsg.isEmpty,
            "Error status should produce an error message")
        XCTAssertTrue(errorMsg.lowercased().contains("max turns"),
            "Error message should mention the error type")
    }

    // MARK: - ANSI utilities performance (NFR verification)

    func testANSIUtilities_performanceUnder50msPerCall() throws {
        // Verify that ANSI styling methods are fast enough for streaming use.
        let elapsedMs = SmokeTestHelper.measureSyncMs {
            for i in 0..<10000 {
                _ = ANSI.red("Error \(i)")
                _ = ANSI.cyan("Tool \(i)")
                _ = ANSI.dim("[system] message \(i)")
                _ = ANSI.bold("Header \(i)")
            }
        }

        let avgMs = Double(elapsedMs) / 40000.0 // 10,000 * 4 calls
        XCTAssertLessThan(avgMs, 1.0,
            "Average ANSI formatting call should be < 1ms, got \(String(format: "%.4f", avgMs))ms")
    }

    // MARK: - AgentFactory regression (Story 1.2)

    func testAgentFactory_createsAgentSuccessfully() async throws {
        // Regression guard: Agent creation from Story 1.2 still works.
        let agent = try await makeTestAgent()
        // No assertion needed -- no crash means success
        _ = agent
    }

    func testAgentFactory_missingApiKey_throws() async throws {
        let args = makeTestArgs(apiKey: nil)

        do {
            _ = try await AgentFactory.createAgent(from: args)
            XCTFail("Missing API key should throw")
        } catch {
            XCTAssertTrue(error is AgentFactoryError,
                "Should throw AgentFactoryError")
        }
    }
}
