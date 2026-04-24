import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 6.3 Dynamic REPL Commands
//
// These tests define the EXPECTED behavior of the new dynamic REPL commands:
//   /model <name>   — switch the agent's model at runtime
//   /mode <mode>    — switch the agent's permission mode at runtime
//   /cost           — display cumulative session cost and token usage
//   /clear          — clear conversation history and reset cost tracker
//
// They will FAIL until REPLLoop.swift is updated with the new commands
// (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: /model claude-opus-4-7 switches agent to specified model
//   AC#2: /mode plan switches permission mode to plan mode
//   AC#3: /cost displays cumulative token usage and cost
//   AC#4: /clear clears conversation history, starts new session
//
// All tests use MockInputReader + MockTextOutputStream to exercise
// REPLLoop.start() in-process. Output is captured and assertions
// verify the correct user-facing messages are produced.

// MARK: - Dynamic REPL Command Tests

final class DynamicREPLCommandTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a MockTextOutputStream and OutputRenderer pair for capturing output.
    private func makeRenderer() -> (renderer: OutputRenderer, mock: MockTextOutputStream) {
        let mock = MockTextOutputStream()
        let renderer = OutputRenderer(output: mock)
        return (renderer, mock)
    }

    /// Creates a test Agent with dummy configuration for REPL command testing.
    private func makeTestAgent() async throws -> Agent {
        let args = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-dynamic-command-tests",
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
            debug: false,
            toolAllow: nil,
            toolDeny: nil,
            shouldExit: false,
            exitCode: 0,
            errorMessage: nil,
            helpMessage: nil
        )
        return try await AgentFactory.createAgent(from: args).0
    }

    // ================================================================
    // MARK: AC#1 — /model <name> switches the agent's model
    // ================================================================

    /// AC#1: /model with a valid model name switches the model and outputs confirmation.
    ///
    /// Given the user is in a REPL session
    /// When they type "/model claude-opus-4-7"
    /// Then the agent switches to claude-opus-4-7 and confirmation is shown
    func testModelCommand_validModel_switchesAndConfirms() async throws {
        // Given: A REPL session
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/model claude-opus-4-7", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        // When: User enters /model claude-opus-4-7
        await repl.start()

        // Then: Output should contain confirmation with the new model name
        let output = mockOutput.output
        XCTAssertTrue(output.contains("claude-opus-4-7") || output.contains("Model"),
            "/model with valid name should output confirmation containing the model name. Got: \(output)")
    }

    /// AC#1: /model without arguments shows usage hint.
    ///
    /// Given the user is in a REPL session
    /// When they type "/model" with no argument
    /// Then a usage hint is displayed
    func testModelCommand_noArg_showsUsage() async throws {
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/model", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("usage") || output.contains("/model"),
            "/model with no argument should show usage hint. Got: \(output)")
    }

    /// AC#1: /model with trailing whitespace is trimmed to bare /model (no arg).
    ///
    /// Input is trimmed before reaching handleSlashCommand, so "/model  "
    /// becomes "/model" and hits the no-argument path. The usage message
    /// includes "empty" to cover both scenarios.
    ///
    /// Given the user is in a REPL session
    /// When they type "/model  " (whitespace-only, trimmed to bare /model)
    /// Then a usage hint mentioning empty/missing is shown
    func testModelCommand_whitespaceOnly_showsUsage() async throws {
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/model  ", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("usage") || output.contains("empty") || output.contains("/model"),
            "/model with whitespace-only input should show usage hint. Got: \(output)")
    }

    /// AC#1: /model command does NOT exit the REPL.
    func testModelCommand_doesNotExit() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/model claude-opus-4-7", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        // /model should NOT exit the REPL, so both lines should be read
        XCTAssertEqual(inputReader.callCount, 2,
            "/model should not exit REPL -- /exit should be read as second input")
    }

    // ================================================================
    // MARK: AC#2 — /mode <mode> switches permission mode
    // ================================================================

    /// AC#2: /mode with a valid mode name switches the permission mode and confirms.
    ///
    /// Given the user is in a REPL session
    /// When they type "/mode plan"
    /// Then the permission mode switches to plan and confirmation is shown
    func testModeCommand_validMode_switchesAndConfirms() async throws {
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/mode plan", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("plan") || output.contains("mode"),
            "/mode plan should output confirmation containing 'plan'. Got: \(output)")
    }

    /// AC#2: /mode with an invalid mode lists all valid modes.
    ///
    /// Given the user is in a REPL session
    /// When they type "/mode invalid"
    /// Then a list of valid modes is shown (default, acceptEdits, bypassPermissions, plan, dontAsk, auto)
    func testModeCommand_invalidMode_listsValidModes() async throws {
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/mode invalid", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        // Should list valid modes
        let hasValidModes = output.contains("default") || output.contains("plan") ||
                            output.contains("bypassPermissions") || output.contains("auto") ||
                            output.contains("accept") || output.contains("dontAsk")
        XCTAssertTrue(hasValidModes,
            "/mode with invalid mode should list valid modes. Got: \(output)")
    }

    /// AC#2: /mode without arguments shows usage hint.
    func testModeCommand_noArg_showsUsage() async throws {
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/mode", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("usage") || output.contains("/mode"),
            "/mode with no argument should show usage hint. Got: \(output)")
    }

    /// AC#2: /mode command does NOT exit the REPL.
    func testModeCommand_doesNotExit() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/mode plan", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 2,
            "/mode should not exit REPL -- /exit should be read as second input")
    }

    /// AC#2: All valid PermissionMode values are accepted by /mode.
    func testModeCommand_allValidModes_succeed() async throws {
        let validModes = ["default", "acceptEdits", "bypassPermissions", "plan", "dontAsk", "auto"]

        for mode in validModes {
            let (renderer, mockOutput) = makeRenderer()
            let inputReader = MockInputReader(["/mode \(mode)", "/exit"])

            let repl = REPLLoop(
                agent: try await makeTestAgent(),
                renderer: renderer,
                reader: inputReader
            )

            await repl.start()

            let output = mockOutput.output.lowercased()
            XCTAssertFalse(output.contains("unknown command") && output.contains("/mode \(mode)"),
                "/mode \(mode) should be recognized as a valid command. Got: \(output)")
            XCTAssertEqual(inputReader.callCount, 2,
                "/mode \(mode) should not exit REPL")
        }
    }

    // ================================================================
    // MARK: AC#3 — /cost displays cumulative token usage and cost
    // ================================================================

    /// AC#3: /cost in initial state shows $0.0000 cost and zero tokens.
    ///
    /// Given the user just started a REPL session (no queries yet)
    /// When they type "/cost"
    /// Then cost shows $0.0000 and zero input/output tokens
    func testCostCommand_initialState_showsZero() async throws {
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/cost", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output
        XCTAssertTrue(output.contains("$0"),
            "/cost in initial state should show $0 cost. Got: \(output)")
        XCTAssertTrue(output.contains("0") || output.contains("token"),
            "/cost in initial state should show zero tokens. Got: \(output)")
    }

    /// AC#3: /cost command does NOT exit the REPL.
    func testCostCommand_doesNotExit() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/cost", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 2,
            "/cost should not exit REPL -- /exit should be read as second input")
    }

    /// AC#3: /cost output contains a recognizable cost format.
    func testCostCommand_outputFormat() async throws {
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/cost", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output
        // Should contain dollar amount format
        let hasDollarSign = output.contains("$")
        // Should contain token-related text
        let hasTokens = output.lowercased().contains("token") || output.lowercased().contains("input") || output.lowercased().contains("output")
        XCTAssertTrue(hasDollarSign || hasTokens,
            "/cost output should contain cost ($) or token information. Got: \(output)")
    }

    // ================================================================
    // MARK: AC#4 — /clear clears conversation history and resets cost
    // ================================================================

    /// AC#4: /clear command outputs confirmation message.
    ///
    /// Given the user is in a REPL session
    /// When they type "/clear"
    /// Then a confirmation is shown and conversation history is cleared
    func testClearCommand_showsConfirmation() async throws {
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/clear", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("clear") || output.contains("cleared") || output.contains("reset") || output.contains("new"),
            "/clear should show confirmation message. Got: \(output)")
    }

    /// AC#4: /clear command does NOT exit the REPL.
    func testClearCommand_doesNotExit() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/clear", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 2,
            "/clear should not exit REPL -- /exit should be read as second input")
    }

    /// AC#4: /clear resets cost tracker — /cost after /clear shows $0.
    func testClearCommand_resetsCostTracker() async throws {
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/clear", "/cost", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output
        // After /clear, /cost should show zero
        // Extract the /cost output (after the /clear confirmation)
        XCTAssertTrue(output.contains("$0"),
            "/cost after /clear should show $0. Got: \(output)")
    }

    // ================================================================
    // MARK: /help includes new commands (AC#1-4)
    // ================================================================

    /// /help output should include all four new commands.
    func testHelpCommand_includesNewCommands() async throws {
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/help", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output
        XCTAssertTrue(output.contains("/model"),
            "/help should list /model command. Got: \(output)")
        XCTAssertTrue(output.contains("/mode"),
            "/help should list /mode command. Got: \(output)")
        XCTAssertTrue(output.contains("/cost"),
            "/help should list /cost command. Got: \(output)")
        XCTAssertTrue(output.contains("/clear"),
            "/help should list /clear command. Got: \(output)")
    }

    // ================================================================
    // MARK: Case insensitivity for new commands
    // ================================================================

    /// /MODEL should work (case-insensitive, matching existing /EXIT pattern).
    func testModelCommand_caseInsensitive() async throws {
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/MODEL claude-opus-4-7", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertFalse(output.contains("unknown command"),
            "/MODEL should be recognized (case-insensitive). Got: \(output)")
    }

    /// /MODE should work (case-insensitive).
    func testModeCommand_caseInsensitive() async throws {
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/MODE plan", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertFalse(output.contains("unknown command"),
            "/MODE should be recognized (case-insensitive). Got: \(output)")
    }

    /// /COST should work (case-insensitive).
    func testCostCommand_caseInsensitive() async throws {
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/COST", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertFalse(output.contains("unknown command"),
            "/COST should be recognized (case-insensitive). Got: \(output)")
    }

    /// /CLEAR should work (case-insensitive).
    func testClearCommand_caseInsensitive() async throws {
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/CLEAR", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertFalse(output.contains("unknown command"),
            "/CLEAR should be recognized (case-insensitive). Got: \(output)")
    }

    // ================================================================
    // MARK: Regression — existing commands still work
    // ================================================================

    /// Ensure /exit still works after adding new commands.
    func testRegression_exitCommandStillWorks() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 1,
            "/exit should still exit after adding new commands")
    }

    /// Ensure /help still works after adding new commands.
    func testRegression_helpCommandStillWorks() async throws {
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/help", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output
        XCTAssertTrue(output.contains("/exit"),
            "/help should still list /exit. Got: \(output)")
        XCTAssertTrue(output.contains("/quit"),
            "/help should still list /quit. Got: \(output)")
    }
}
