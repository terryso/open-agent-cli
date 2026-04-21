import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 1.5 Single-Shot Mode
//
// These tests define the EXPECTED behavior of single-shot mode in CLI.
// They will FAIL until CLI.swift is updated to use agent.prompt() and
// OutputRenderer is extended with summary rendering from QueryResult.
//
// Acceptance Criteria Coverage:
//   AC#1: CLI accepts positional prompt argument, processes via agent.prompt()
//   AC#2: Successful response: output text + summary line, exit code 0
//   AC#3: Error status: error to stderr, exit code 1
//   AC#4: Empty response with success status: exit code 0

final class CLISingleShotTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a MockTextOutputStream and OutputRenderer pair for capturing output.
    private func makeRenderer() -> (renderer: OutputRenderer, mock: MockTextOutputStream) {
        let mock = MockTextOutputStream()
        let renderer = OutputRenderer(output: mock)
        return (renderer, mock)
    }

    /// Creates a test Agent with a dummy API key.
    private func makeTestAgent() async throws -> Agent {
        let args = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-singleshottests",
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
        return try await AgentFactory.createAgent(from: args).0
    }

    // MARK: - AC#1: CLI accepts positional prompt for single-shot mode

    func testArgumentParser_positionalArg_setsPrompt() throws {
        // AC#1: A positional argument is interpreted as the prompt for single-shot mode
        let result = ArgumentParser.parse(["openagent", "what is 2+2?"])

        XCTAssertEqual(result.prompt, "what is 2+2?",
            "Positional argument should set prompt for single-shot mode (AC#1)")
        XCTAssertFalse(result.shouldExit,
            "Single-shot mode should not signal shouldExit from parser (AC#1)")
    }

    func testArgumentParser_positionalArgWithFlags_setsPrompt() throws {
        // AC#1: Flags and positional arg coexist -- prompt still set
        let result = ArgumentParser.parse(["openagent", "--model", "glm-5.1", "explain quantum computing"])

        XCTAssertEqual(result.prompt, "explain quantum computing",
            "Prompt should be set even with flags present (AC#1)")
        XCTAssertEqual(result.model, "glm-5.1",
            "Flags should still be parsed alongside prompt (AC#1)")
    }

    func testArgumentParser_noPositionalArg_REPLMode() throws {
        // AC#1 complement: No positional arg means REPL mode (no prompt)
        let result = ArgumentParser.parse(["openagent"])

        XCTAssertNil(result.prompt,
            "No positional arg should result in nil prompt (REPL mode)")
    }

    // MARK: - AC#2: Successful response -- output text + summary line, exit code 0

    func testSingleShotSummary_success_containsTurnsCostDuration() throws {
        // AC#2: Summary line format: Turns: N | Cost: $X.XXXX | Duration: Xs
        let (renderer, mock) = makeRenderer()

        let queryResult = QueryResult(
            text: "The answer is 4",
            usage: TokenUsage(inputTokens: 100, outputTokens: 50),
            numTurns: 1,
            durationMs: 3200,
            messages: [],
            status: .success,
            totalCostUsd: 0.0023
        )

        renderer.renderSingleShotSummary(queryResult)

        let output = mock.output
        XCTAssertTrue(output.contains("Turns: 1"),
            "Summary should contain 'Turns: 1', got: \(output)")
        XCTAssertTrue(output.contains("Cost:"),
            "Summary should contain 'Cost:', got: \(output)")
        XCTAssertTrue(output.contains("Duration:"),
            "Summary should contain 'Duration:', got: \(output)")
    }

    func testSingleShotSummary_success_costFormattedCorrectly() throws {
        // AC#2: Cost formatted as $X.XXXX (4 decimal places)
        let (renderer, mock) = makeRenderer()

        let queryResult = QueryResult(
            text: "Hello",
            usage: TokenUsage(inputTokens: 50, outputTokens: 20),
            numTurns: 1,
            durationMs: 1000,
            messages: [],
            status: .success,
            totalCostUsd: 0.0023
        )

        renderer.renderSingleShotSummary(queryResult)

        XCTAssertTrue(mock.output.contains("$0.0023"),
            "Cost should be formatted as $0.0023, got: \(mock.output)")
    }

    func testSingleShotSummary_success_durationFormattedCorrectly() throws {
        // AC#2: Duration converted from ms to seconds
        let (renderer, mock) = makeRenderer()

        let queryResult = QueryResult(
            text: "Hello",
            usage: TokenUsage(inputTokens: 50, outputTokens: 20),
            numTurns: 1,
            durationMs: 4200,
            messages: [],
            status: .success,
            totalCostUsd: 0.0
        )

        renderer.renderSingleShotSummary(queryResult)

        XCTAssertTrue(mock.output.contains("4.2s"),
            "Duration should be 4.2s (4200ms), got: \(mock.output)")
    }

    func testSingleShotSummary_success_multipleTurns() throws {
        // AC#2: Summary shows correct turn count for multi-turn interactions
        let (renderer, mock) = makeRenderer()

        let queryResult = QueryResult(
            text: "Done",
            usage: TokenUsage(inputTokens: 300, outputTokens: 150),
            numTurns: 5,
            durationMs: 12000,
            messages: [],
            status: .success,
            totalCostUsd: 0.0450
        )

        renderer.renderSingleShotSummary(queryResult)

        XCTAssertTrue(mock.output.contains("Turns: 5"),
            "Summary should show Turns: 5, got: \(mock.output)")
    }

    // MARK: - Exit code mapping: QueryStatus -> exit code

    func testExitCodeForStatus_success_returnsZero() throws {
        // AC#2: Success status maps to exit code 0
        let exitCode = CLIExitCode.forQueryStatus(.success)
        XCTAssertEqual(exitCode, 0,
            "Success status should map to exit code 0 (AC#2)")
    }

    func testExitCodeForStatus_errorMaxTurns_returnsOne() throws {
        // AC#3: Error status maps to exit code 1
        let exitCode = CLIExitCode.forQueryStatus(.errorMaxTurns)
        XCTAssertEqual(exitCode, 1,
            "errorMaxTurns should map to exit code 1 (AC#3)")
    }

    func testExitCodeForStatus_errorDuringExecution_returnsOne() throws {
        // AC#3: Error status maps to exit code 1
        let exitCode = CLIExitCode.forQueryStatus(.errorDuringExecution)
        XCTAssertEqual(exitCode, 1,
            "errorDuringExecution should map to exit code 1 (AC#3)")
    }

    func testExitCodeForStatus_errorMaxBudgetUsd_returnsOne() throws {
        // AC#3: Error status maps to exit code 1
        let exitCode = CLIExitCode.forQueryStatus(.errorMaxBudgetUsd)
        XCTAssertEqual(exitCode, 1,
            "errorMaxBudgetUsd should map to exit code 1 (AC#3)")
    }

    func testExitCodeForStatus_cancelled_returnsOne() throws {
        // AC#3: Cancelled status maps to exit code 1
        let exitCode = CLIExitCode.forQueryStatus(.cancelled)
        XCTAssertEqual(exitCode, 1,
            "cancelled should map to exit code 1 (AC#3)")
    }

    // MARK: - AC#3: Error status -- error output, exit code 1

    func testSingleShotSummary_errorMaxTurns_showsErrorTag() throws {
        // AC#3: Error status renders with error indicator
        let (renderer, mock) = makeRenderer()

        let queryResult = QueryResult(
            text: "",
            usage: TokenUsage(inputTokens: 100, outputTokens: 50),
            numTurns: 10,
            durationMs: 5000,
            messages: [],
            status: .errorMaxTurns,
            totalCostUsd: 0.01
        )

        renderer.renderSingleShotSummary(queryResult)

        let output = mock.output
        XCTAssertTrue(output.contains("errorMaxTurns") || output.lowercased().contains("max turns"),
            "Error summary should mention errorMaxTurns, got: \(output)")
    }

    func testSingleShotSummary_errorDuringExecution_showsErrorTag() throws {
        // AC#3: Error status renders with error indicator
        let (renderer, mock) = makeRenderer()

        let queryResult = QueryResult(
            text: "",
            usage: TokenUsage(inputTokens: 0, outputTokens: 0),
            numTurns: 0,
            durationMs: 1000,
            messages: [],
            status: .errorDuringExecution,
            totalCostUsd: 0.0
        )

        renderer.renderSingleShotSummary(queryResult)

        let output = mock.output
        XCTAssertTrue(output.contains("errorDuringExecution") || output.lowercased().contains("execution"),
            "Error summary should mention errorDuringExecution, got: \(output)")
    }

    func testSingleShotSummary_cancelled_showsCancelledTag() throws {
        // AC#3: Cancelled status renders with cancelled indicator
        let (renderer, mock) = makeRenderer()

        let queryResult = QueryResult(
            text: "",
            usage: TokenUsage(inputTokens: 50, outputTokens: 20),
            numTurns: 2,
            durationMs: 3000,
            messages: [],
            status: .cancelled,
            totalCostUsd: 0.001
        )

        renderer.renderSingleShotSummary(queryResult)

        let output = mock.output
        XCTAssertTrue(output.lowercased().contains("cancelled"),
            "Cancelled summary should show cancelled indicator, got: \(output)")
    }

    func testSingleShotErrorOutput_stderrContainsStatusDescription() throws {
        // AC#3: Error messages go to stderr
        let (renderer, mock) = makeRenderer()

        let queryResult = QueryResult(
            text: "",
            usage: TokenUsage(inputTokens: 0, outputTokens: 0),
            numTurns: 10,
            durationMs: 5000,
            messages: [],
            status: .errorMaxTurns,
            totalCostUsd: 0.01
        )

        // The stderr output should describe the error status
        let errorMessage = CLISingleShot.formatErrorMessage(queryResult)
        XCTAssertFalse(errorMessage.isEmpty,
            "Error message should not be empty for error status (AC#3)")
        XCTAssertTrue(errorMessage.contains("errorMaxTurns") || errorMessage.lowercased().contains("max turns"),
            "Error message should reference the error status (AC#3)")
    }

    func testSingleShotErrorOutput_allErrorStatusesHaveMessages() throws {
        // AC#3: Every non-success status produces a non-empty error message
        let errorStatuses: [QueryStatus] = [
            .errorMaxTurns,
            .errorDuringExecution,
            .errorMaxBudgetUsd,
            .cancelled
        ]

        for status in errorStatuses {
            let queryResult = QueryResult(
                text: "",
                usage: TokenUsage(inputTokens: 0, outputTokens: 0),
                numTurns: 0,
                durationMs: 0,
                messages: [],
                status: status,
                totalCostUsd: 0.0
            )

            let errorMessage = CLISingleShot.formatErrorMessage(queryResult)
            XCTAssertFalse(errorMessage.isEmpty,
                "Error message for \(status) should not be empty (AC#3)")
        }
    }

    // MARK: - AC#4: Empty response with success -- exit code 0

    func testExitCode_successWithEmptyText_returnsZero() throws {
        // AC#4: Empty text + success status = exit code 0
        let queryResult = QueryResult(
            text: "",
            usage: TokenUsage(inputTokens: 0, outputTokens: 0),
            numTurns: 1,
            durationMs: 500,
            messages: [],
            status: .success,
            totalCostUsd: 0.0
        )

        let exitCode = CLIExitCode.forQueryStatus(queryResult.status)
        XCTAssertEqual(exitCode, 0,
            "Empty response with success status should map to exit code 0 (AC#4)")
    }

    func testSingleShotSummary_emptyResponse_success_stillShowsSummary() throws {
        // AC#4: Even with empty text, summary line should be rendered
        let (renderer, mock) = makeRenderer()

        let queryResult = QueryResult(
            text: "",
            usage: TokenUsage(inputTokens: 0, outputTokens: 0),
            numTurns: 1,
            durationMs: 500,
            messages: [],
            status: .success,
            totalCostUsd: 0.0
        )

        renderer.renderSingleShotSummary(queryResult)

        // The summary line should still be rendered
        XCTAssertTrue(mock.output.contains("Turns:") || mock.output.contains("---"),
            "Summary should be rendered even for empty response (AC#4), got: \(mock.output)")
    }

    func testSingleShotErrorOutput_successStatus_returnsEmptyError() throws {
        // AC#4: Success status produces no error message
        let queryResult = QueryResult(
            text: "",
            usage: TokenUsage(inputTokens: 0, outputTokens: 0),
            numTurns: 1,
            durationMs: 500,
            messages: [],
            status: .success,
            totalCostUsd: 0.0
        )

        let errorMessage = CLISingleShot.formatErrorMessage(queryResult)
        XCTAssertTrue(errorMessage.isEmpty,
            "Success status should produce no error message (AC#4)")
    }

    // MARK: - isCancelled handling

    func testExitCode_isCancelled_true_returnsOne() throws {
        // Cancelled query should exit code 1
        let queryResult = QueryResult(
            text: "partial",
            usage: TokenUsage(inputTokens: 50, outputTokens: 20),
            numTurns: 2,
            durationMs: 3000,
            messages: [],
            status: .cancelled,
            totalCostUsd: 0.001,
            isCancelled: true
        )

        let exitCode = CLIExitCode.forQueryStatus(queryResult.status)
        XCTAssertEqual(exitCode, 1,
            "isCancelled=true with .cancelled status should exit code 1")
    }

    // MARK: - Integration: ArgumentParser identifies single-shot mode correctly

    func testIntegration_parsedArgs_promptSet_singleShotMode() throws {
        // Verify the full pipeline recognizes single-shot mode
        let args = ArgumentParser.parse(["openagent", "what is 2+2?"])

        XCTAssertTrue(args.prompt != nil,
            "ParsedArgs should have prompt set for single-shot invocation")
        XCTAssertEqual(args.prompt, "what is 2+2?")
        XCTAssertFalse(args.helpRequested,
            "Single-shot mode should not trigger help")
        XCTAssertFalse(args.shouldExit,
            "Single-shot mode should not signal shouldExit at parse time")
    }

    func testIntegration_parsedArgs_quietMode_withPrompt() throws {
        // Quiet mode + single-shot should work together
        let args = ArgumentParser.parse(["openagent", "--quiet", "do something"])

        XCTAssertEqual(args.prompt, "do something")
        XCTAssertTrue(args.quiet, "--quiet should be set")
    }

    // MARK: - Summary line consistency with streaming renderer

    func testSingleShotSummary_matchesStreamSummaryFormat() throws {
        // AC#2: The single-shot summary should use the same format as the streaming result summary.
        // Verify by comparing output of both renderers with equivalent data.
        let (renderer, mock) = makeRenderer()

        let queryResult = QueryResult(
            text: "Done",
            usage: TokenUsage(inputTokens: 100, outputTokens: 50),
            numTurns: 3,
            durationMs: 4200,
            messages: [],
            status: .success,
            totalCostUsd: 0.0023
        )

        // Render single-shot summary
        renderer.renderSingleShotSummary(queryResult)
        let singleShotOutput = mock.output

        // Now render streaming result for equivalent data
        mock.output = ""
        let resultData = SDKMessage.ResultData(
            subtype: .success,
            text: "Done",
            usage: TokenUsage(inputTokens: 100, outputTokens: 50),
            numTurns: 3,
            durationMs: 4200,
            totalCostUsd: 0.0023
        )
        renderer.render(.result(resultData))
        let streamOutput = mock.output

        // Both should contain the same key metrics
        XCTAssertTrue(singleShotOutput.contains("Turns: 3"),
            "Single-shot summary should contain 'Turns: 3'")
        XCTAssertTrue(streamOutput.contains("Turns: 3"),
            "Stream result should contain 'Turns: 3'")
        XCTAssertTrue(singleShotOutput.contains("$0.0023"),
            "Single-shot summary should contain cost")
        XCTAssertTrue(streamOutput.contains("$0.0023"),
            "Stream result should contain cost")
        XCTAssertTrue(singleShotOutput.contains("4.2s"),
            "Single-shot summary should contain duration")
        XCTAssertTrue(streamOutput.contains("4.2s"),
            "Stream result should contain duration")
    }
}
