import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 9.2 Colored Prompt
//
// These tests define the EXPECTED behavior of the colored prompt feature.
// They will FAIL until ANSI.swift and REPLLoop.swift are updated with the
// colored prompt implementation (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: default mode — green prompt (ESC[32m)
//   AC#2: plan mode — yellow prompt (ESC[33m)
//   AC#3: bypassPermissions mode — red prompt (ESC[31m)
//   AC#4: acceptEdits mode — blue prompt (ESC[34m)
//   AC#5: auto/dontAsk mode — default/white prompt (ESC[0m)
//   AC#6: /mode dynamic switching changes prompt color
//   AC#7: no-ANSI fallback returns plain "> "
//
// All tests use MockInputReader + MockTextOutputStream to exercise
// REPLLoop.start() in-process. Output is captured and assertions
// verify the correct prompt colors are produced per permission mode.

// MARK: - Colored Prompt Tests

final class ColoredPromptTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a MockTextOutputStream and OutputRenderer pair for capturing output.
    private func makeRenderer() -> (renderer: OutputRenderer, mock: MockTextOutputStream) {
        let mock = MockTextOutputStream()
        let renderer = OutputRenderer(output: mock)
        return (renderer, mock)
    }

    /// Creates a ParsedArgs with the given mode for colored prompt testing.
    private func makeParsedArgs(mode: String = "default") -> ParsedArgs {
        ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-colored-prompt-tests",
            baseURL: "https://api.example.com/v1",
            provider: nil,
            mode: mode,
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
    }

    /// Creates a test Agent with dummy configuration for colored prompt testing.
    private func makeTestAgent(mode: String = "default") async throws -> Agent {
        let args = makeParsedArgs(mode: mode)
        return try await AgentFactory.createAgent(from: args).0
    }

    // ================================================================
    // MARK: AC#1 — default mode: green prompt
    // ================================================================

    /// AC#1: When CLI starts in default mode, the prompt uses green ANSI color.
    ///
    /// Given CLI starts with default mode
    /// When the ">" prompt is displayed
    /// Then the prompt contains green ANSI escape code \u{001B}[32m
    func testColoredPrompt_defaultMode_usesGreenAnsiCode() async throws {
        // Given: A REPL session in default mode
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(mode: "default"),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs(mode: "default")
        )

        // When: REPL starts and displays the prompt
        await repl.start()

        // Then: The prompt passed to readLine should contain green ANSI code
        let prompts = inputReader.promptHistory
        XCTAssertFalse(prompts.isEmpty, "REPL should have prompted at least once")
        let firstPrompt = prompts.first!
        XCTAssertTrue(
            firstPrompt.contains("\u{001B}[32m"),
            "Default mode prompt should contain green ANSI escape code ESC[32m, got: \(firstPrompt.debugDescription)"
        )
    }

    /// AC#1: The green prompt ends with an ANSI reset code.
    func testColoredPrompt_defaultMode_endsWithReset() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(mode: "default"),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs(mode: "default")
        )

        await repl.start()

        let firstPrompt = inputReader.promptHistory.first!
        XCTAssertTrue(
            firstPrompt.contains("\u{001B}[0m"),
            "Default mode prompt should contain ANSI reset code ESC[0m, got: \(firstPrompt.debugDescription)"
        )
    }

    // ================================================================
    // MARK: AC#2 — plan mode: yellow prompt
    // ================================================================

    /// AC#2: When CLI starts in plan mode, the prompt uses yellow ANSI color.
    func testColoredPrompt_planMode_usesYellowAnsiCode() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(mode: "plan"),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs(mode: "plan")
        )

        await repl.start()

        let firstPrompt = inputReader.promptHistory.first!
        XCTAssertTrue(
            firstPrompt.contains("\u{001B}[33m"),
            "Plan mode prompt should contain yellow ANSI escape code ESC[33m, got: \(firstPrompt.debugDescription)"
        )
    }

    // ================================================================
    // MARK: AC#3 — bypassPermissions mode: red prompt
    // ================================================================

    /// AC#3: When CLI starts in bypassPermissions mode, the prompt uses red ANSI color.
    func testColoredPrompt_bypassPermissionsMode_usesRedAnsiCode() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(mode: "bypassPermissions"),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs(mode: "bypassPermissions")
        )

        await repl.start()

        let firstPrompt = inputReader.promptHistory.first!
        XCTAssertTrue(
            firstPrompt.contains("\u{001B}[31m"),
            "BypassPermissions mode prompt should contain red ANSI escape code ESC[31m, got: \(firstPrompt.debugDescription)"
        )
    }

    // ================================================================
    // MARK: AC#4 — acceptEdits mode: blue prompt
    // ================================================================

    /// AC#4: When CLI starts in acceptEdits mode, the prompt uses blue ANSI color.
    func testColoredPrompt_acceptEditsMode_usesBlueAnsiCode() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(mode: "acceptEdits"),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs(mode: "acceptEdits")
        )

        await repl.start()

        let firstPrompt = inputReader.promptHistory.first!
        XCTAssertTrue(
            firstPrompt.contains("\u{001B}[34m"),
            "AcceptEdits mode prompt should contain blue ANSI escape code ESC[34m, got: \(firstPrompt.debugDescription)"
        )
    }

    // ================================================================
    // MARK: AC#5 — auto/dontAsk mode: default color (reset)
    // ================================================================

    /// AC#5: When CLI starts in auto mode, the prompt uses default/white (no color codes).
    func testColoredPrompt_autoMode_usesDefaultColor() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(mode: "auto"),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs(mode: "auto")
        )

        await repl.start()

        let firstPrompt = inputReader.promptHistory.first!
        XCTAssertFalse(
            firstPrompt.contains("\u{001B}["),
            "Auto mode prompt should have no ANSI escape codes (default color), got: \(firstPrompt.debugDescription)"
        )
        XCTAssertTrue(
            firstPrompt.contains("> "),
            "Auto mode prompt should contain '> ', got: \(firstPrompt.debugDescription)"
        )
    }

    /// AC#5: When CLI starts in dontAsk mode, the prompt uses default/white (no color codes).
    func testColoredPrompt_dontAskMode_usesDefaultColor() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(mode: "dontAsk"),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs(mode: "dontAsk")
        )

        await repl.start()

        let firstPrompt = inputReader.promptHistory.first!
        XCTAssertFalse(
            firstPrompt.contains("\u{001B}["),
            "DontAsk mode prompt should have no ANSI escape codes (default color), got: \(firstPrompt.debugDescription)"
        )
        XCTAssertTrue(
            firstPrompt.contains("> "),
            "DontAsk mode prompt should contain '> ', got: \(firstPrompt.debugDescription)"
        )
    }

    // ================================================================
    // MARK: AC#6 — /mode dynamic switching changes prompt color
    // ================================================================

    /// AC#6: Switching mode via /mode command changes the next prompt color.
    ///
    /// Given I am in a REPL session in default mode (green prompt)
    /// When I execute /mode plan
    /// Then the next prompt should use yellow (ESC[33m)
    func testColoredPrompt_modeSwitch_changesNextPromptColor() async throws {
        let (renderer, _) = makeRenderer()
        // First input: switch to plan mode. Second: exit.
        let inputReader = MockInputReader(["/mode plan", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(mode: "default"),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs(mode: "default")
        )

        await repl.start()

        // After /mode plan, the next prompt (for /exit) should be yellow
        XCTAssertEqual(inputReader.promptHistory.count, 2,
            "REPL should have prompted twice (once for /mode plan, once for /exit)")

        let secondPrompt = inputReader.promptHistory[1]
        XCTAssertTrue(
            secondPrompt.contains("\u{001B}[33m"),
            "After /mode plan, next prompt should contain yellow ANSI code ESC[33m, got: \(secondPrompt.debugDescription)"
        )
    }

    /// AC#6: Switching mode from default to bypassPermissions changes prompt to red.
    func testColoredPrompt_modeSwitch_defaultToBypass_usesRedPrompt() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/mode bypassPermissions", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(mode: "default"),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs(mode: "default")
        )

        await repl.start()

        let secondPrompt = inputReader.promptHistory[1]
        XCTAssertTrue(
            secondPrompt.contains("\u{001B}[31m"),
            "After /mode bypassPermissions, next prompt should contain red ANSI code ESC[31m, got: \(secondPrompt.debugDescription)"
        )
    }

    /// AC#6: Switching mode from plan to acceptEdits changes prompt to blue.
    func testColoredPrompt_modeSwitch_planToAcceptEdits_usesBluePrompt() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/mode acceptEdits", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(mode: "plan"),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs(mode: "plan")
        )

        await repl.start()

        let secondPrompt = inputReader.promptHistory[1]
        XCTAssertTrue(
            secondPrompt.contains("\u{001B}[34m"),
            "After /mode acceptEdits, next prompt should contain blue ANSI code ESC[34m, got: \(secondPrompt.debugDescription)"
        )
    }

    // ================================================================
    // MARK: AC#7 — no-ANSI fallback returns plain "> "
    // ================================================================

    /// AC#7: ANSI.coloredPrompt(forMode:) returns plain "> " when isatty returns 0.
    ///
    /// Note: In test environments, stdout is typically not a tty, so isatty()
    /// returns 0. This test validates the fallback behavior.
    func testColoredPrompt_noTty_returnsPlainPrompt() async throws {
        // In a test environment, STDOUT_FILENO is typically not a tty,
        // so ANSI.coloredPrompt should return plain "> ".
        // We test this via the ANSI.coloredPrompt function directly.

        // Given: ANSI.coloredPrompt function exists
        // When: called with any mode (in a non-tty environment)
        // Then: returns "> " without ANSI codes

        // This test will FAIL until ANSI.coloredPrompt(forMode:) is implemented
        let prompt = ANSI.coloredPrompt(forMode: .default)
        XCTAssertEqual(
            prompt, "> ",
            "In non-tty environment, coloredPrompt should return plain '> ', got: \(prompt.debugDescription)"
        )
    }

    /// AC#7: Fallback prompt contains no ANSI escape sequences.
    func testColoredPrompt_noTty_containsNoAnsiEscapes() async throws {
        let prompt = ANSI.coloredPrompt(forMode: .plan)
        XCTAssertFalse(
            prompt.contains("\u{001B}["),
            "Non-tty fallback prompt should not contain any ANSI escape sequences, got: \(prompt.debugDescription)"
        )
    }

    // ================================================================
    // MARK: ANSI.blue() helper
    // ================================================================

    /// Verify that ANSI.blue() static method exists and wraps text with blue color.
    func testANSI_blue_wrapsTextWithBlueAnsiCode() {
        let result = ANSI.blue("test")
        XCTAssertEqual(
            result, "\u{001B}[34mtest\u{001B}[0m",
            "ANSI.blue() should wrap text with ESC[34m and ESC[0m, got: \(result.debugDescription)"
        )
    }

    // ================================================================
    // MARK: Prompt contains "> " text
    // ================================================================

    /// The colored prompt should always contain the "> " text regardless of color.
    func testColoredPrompt_containsPromptText() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(mode: "default"),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs(mode: "default")
        )

        await repl.start()

        let firstPrompt = inputReader.promptHistory.first!
        XCTAssertTrue(
            firstPrompt.contains("> "),
            "Prompt should contain '> ' text, got: \(firstPrompt.debugDescription)"
        )
    }

    // ================================================================
    // MARK: Regression — existing REPL behavior preserved
    // ================================================================

    /// Regression: /exit still works with colored prompt.
    func testRegression_exitCommandStillWorksWithColoredPrompt() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(mode: "default"),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs(mode: "default")
        )

        // Should not hang or crash
        await repl.start()

        XCTAssertEqual(inputReader.callCount, 1,
            "REPL should call readLine once and exit cleanly")
    }

    /// Regression: Empty input is still ignored with colored prompt.
    func testRegression_emptyInputIgnoredWithColoredPrompt() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["", "   ", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(mode: "default"),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs(mode: "default")
        )

        await repl.start()

        // Should have prompted 3 times (empty, whitespace, then /exit)
        XCTAssertEqual(inputReader.promptHistory.count, 3,
            "REPL should show prompt after each ignored input")
    }
}
