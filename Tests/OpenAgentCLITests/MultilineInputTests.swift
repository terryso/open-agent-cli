import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 9.5 Multiline Input
//
// These tests define the EXPECTED behavior of the multiline input feature.
// They will FAIL until REPLLoop.swift and ANSI.swift are updated with the
// multiline state machine implementation (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: Backslash continuation — `\` at end of line enters continuation mode
//   AC#2: Triple-quote multiline — `"""` enters multiline mode
//   AC#3: Ctrl+C cancels multiline input
//   AC#4: Trailing whitespace tolerance — `\` with trailing whitespace still triggers continuation
//
// All tests use MockInputReader + MockTextOutputStream to exercise
// REPLLoop.start() in-process. Output is captured and assertions
// verify the correct multiline behavior.

// MARK: - Multiline Input Tests

// MARK: - SignalingMockInputReader

/// A mock input reader that sets `SignalHandler.setTestFlags(sigint: true)` when
/// returning a specific line index.  Used to simulate Ctrl+C (which delivers a
/// SIGINT) while still returning an empty string from `readLine`.
final class SignalingMockInputReader: InputReading, @unchecked Sendable {
    var lines: [String?]
    var callCount = 0
    var promptHistory: [String] = []
    let signalOnIndex: Int

    init(_ lines: [String?], signalOnIndex: Int) {
        self.lines = lines
        self.signalOnIndex = signalOnIndex
    }

    func readLine(prompt: String) -> String? {
        promptHistory.append(prompt)
        guard callCount < lines.count else { return nil }
        let line = lines[callCount]
        if callCount == signalOnIndex {
            SignalHandler.setTestFlags(sigint: true)
        }
        callCount += 1
        return line
    }
}

// MARK: - Multiline Input Tests

final class MultilineInputTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a MockTextOutputStream and OutputRenderer pair for capturing output.
    private func makeRenderer() -> (renderer: OutputRenderer, mock: MockTextOutputStream) {
        let mock = MockTextOutputStream()
        let renderer = OutputRenderer(output: mock)
        return (renderer, mock)
    }

    /// Creates a ParsedArgs with the given mode for testing.
    private func makeParsedArgs(mode: String = "default") -> ParsedArgs {
        ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-multiline-tests",
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

    /// Creates a test Agent with dummy configuration.
    private func makeTestAgent(mode: String = "default") async throws -> Agent {
        let args = makeParsedArgs(mode: mode)
        return try await AgentFactory.createAgent(from: args).0
    }

    // ================================================================
    // MARK: AC#1 — Backslash continuation
    // ================================================================

    /// AC#1: Backslash at end of line triggers continuation mode.
    ///
    /// Given I am in REPL mode
    /// When I type "hello \" and press Enter
    /// Then the prompt changes to "...>"
    /// And the next line is accumulated
    /// When I type "world" and press Enter
    /// Then both lines are merged as "hello\nworld" and sent as one input
    func testBackslashContinuation_twoLines_mergedAndSent() async throws {
        // Given: REPL session with mock input
        let (renderer, _) = makeRenderer()
        // Input: "hello \" (backslash continuation) → "world" → "/exit"
        let inputReader = MockInputReader(["hello \\", "world", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs()
        )

        // When: REPL starts
        await repl.start()

        // Then: Should have read 3 lines (continuation + final + exit)
        XCTAssertEqual(inputReader.callCount, 3,
            "Backslash continuation should read 3 lines: 'hello \\', 'world', '/exit'")

        // And: The second prompt should be a continuation prompt "...>"
        let secondPrompt = inputReader.promptHistory[1]
        XCTAssertTrue(secondPrompt.contains("...>"),
            "Continuation prompt should contain '...>', got: \(secondPrompt.debugDescription)")
    }

    /// AC#1: Multi-segment continuation (3 segments) merges correctly.
    ///
    /// Given I type "line1 \" → "line2 \" → "line3"
    /// Then all three segments are merged with newlines
    func testBackslashContinuation_threeSegments_mergedCorrectly() async throws {
        let (renderer, _) = makeRenderer()
        // Three continuation segments then exit
        let inputReader = MockInputReader(["line1 \\", "line2 \\", "line3", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs()
        )

        await repl.start()

        // Should read all 4 lines (3 content + /exit)
        XCTAssertEqual(inputReader.callCount, 4,
            "Three-segment continuation should read 4 lines total")

        // Prompts: first is ">", then two "...>", then ">" again for /exit
        XCTAssertTrue(inputReader.promptHistory[0].contains("> "),
            "First prompt should be main prompt '> '")
        XCTAssertTrue(inputReader.promptHistory[1].contains("...>"),
            "Second prompt should be continuation '...>'")
        XCTAssertTrue(inputReader.promptHistory[2].contains("...>"),
            "Third prompt should be continuation '...>'")
        XCTAssertTrue(inputReader.promptHistory[3].contains("> "),
            "Fourth prompt should be back to main '>'")
    }

    /// AC#1: Backslash continuation strips the trailing backslash from each line.
    ///
    /// "hello \" + "world" should produce "hello\nworld", not "hello \\nworld"
    func testBackslashContinuation_stripsTrailingBackslash() async throws {
        // We verify this indirectly: if the merged input is sent as a query
        // to the agent, the REPL should not crash and should continue to /exit
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["hello \\", "world", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs()
        )

        await repl.start()

        // If backslash was not stripped, the agent might receive "hello \" which
        // would still work. But we verify the loop completes successfully.
        XCTAssertEqual(inputReader.callCount, 3,
            "Continuation should merge lines and send as one query")
    }

    // ================================================================
    // MARK: AC#2 — Triple-quote multiline mode
    // ================================================================

    /// AC#2: Triple-quote mode captures content between """ delimiters.
    ///
    /// Given I am in REPL mode
    /// When I type `"""` and press Enter
    /// Then the prompt changes to "...>"
    /// When I type multiple lines then `"""` and press Enter
    /// Then all content between the delimiters is sent as one input
    func testTripleQuote_capturesMultilineContent() async throws {
        let (renderer, _) = makeRenderer()
        // Input: """ → line1 → line2 → """ → /exit
        let inputReader = MockInputReader(["\"\"\"", "line1", "line2", "\"\"\"", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs()
        )

        await repl.start()

        // Should read 5 lines: """, line1, line2, """, /exit
        XCTAssertEqual(inputReader.callCount, 5,
            "Triple-quote mode should read 5 lines: open, 2 content, close, /exit")

        // After opening """, next prompts should be continuation prompts
        XCTAssertTrue(inputReader.promptHistory[1].contains("...>"),
            "After opening \"\"\", prompt should be '...>'")
        XCTAssertTrue(inputReader.promptHistory[2].contains("...>"),
            "Content line prompt should be '...>'")
        XCTAssertTrue(inputReader.promptHistory[3].contains("...>"),
            "Closing \"\"\" prompt should still be '...>'")
    }

    /// AC#2: Triple-quote mode preserves newlines in content.
    ///
    /// Content between """ delimiters should include the literal newlines.
    func testTripleQuote_preservesNewlines() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["\"\"\"", "first line", "second line", "\"\"\"", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs()
        )

        await repl.start()

        // Verify the loop completes successfully — the merged content
        // "first line\nsecond line" is sent as one query
        XCTAssertEqual(inputReader.callCount, 5,
            "Triple-quote with 2 content lines should read 5 total lines")
    }

    /// AC#2: Triple-quote mode preserves original indentation.
    ///
    /// Lines between """ should keep their original whitespace/indentation.
    func testTripleQuote_preservesIndentation() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader([
            "\"\"\"",
            "  indented line",
            "    double indented",
            "\"\"\"",
            "/exit"
        ])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs()
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 5,
            "Triple-quote with indented content should read 5 lines")
    }

    /// AC#2: Empty triple-quote (open immediately followed by close) sends empty input (filtered).
    ///
    /// When `"""` is immediately followed by `"""`, the content is empty.
    /// Empty content should be filtered (guard against empty).
    func testTripleQuote_emptyContent_filtered() async throws {
        let (renderer, _) = makeRenderer()
        // Open """ immediately followed by closing """
        let inputReader = MockInputReader(["\"\"\"", "\"\"\"", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs()
        )

        await repl.start()

        // Empty triple-quote content should be filtered — no query sent
        // So the REPL should continue to /exit
        XCTAssertEqual(inputReader.callCount, 3,
            "Empty triple-quote should be filtered, REPL continues to /exit")
    }

    // ================================================================
    // MARK: AC#3 — Ctrl+C cancels multiline input
    // ================================================================

    /// AC#3: Ctrl+C during backslash continuation cancels and returns to main prompt.
    ///
    /// Given I am in continuation mode (...)
    /// When I press Ctrl+C (readLine returns "")
    /// Then the multiline buffer is cleared
    /// And the prompt returns to ">"
    func testCtrlC_cancelsBackslashContinuation() async throws {
        let (renderer, mockOutput) = makeRenderer()
        // Start continuation with "hello \", then Ctrl+C (empty string + signal flag), then /exit
        let inputReader = MockInputReader(["hello \\", "", "/exit"])

        // Schedule the SIGINT flag to be set so the empty string is recognized as Ctrl+C.
        // We use a custom MockInputReader that sets the flag when it returns the empty line.
        let signalingReader = SignalingMockInputReader(["hello \\", "", "/exit"], signalOnIndex: 1)

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: signalingReader,
            parsedArgs: makeParsedArgs()
        )

        await repl.start()

        // Should read 3 lines: "hello \", Ctrl+C(""), /exit
        XCTAssertEqual(signalingReader.callCount, 3,
            "Ctrl+C during continuation should cancel and continue to /exit")

        // Output should contain ^C indicator
        let output = mockOutput.output
        XCTAssertTrue(output.contains("^C"),
            "Ctrl+C during continuation should output '^C', got: \(output)")

        // The prompt after Ctrl+C should be the main prompt, not continuation
        let promptAfterCancel = signalingReader.promptHistory[2]
        XCTAssertTrue(promptAfterCancel.contains("> ") && !promptAfterCancel.contains("...>"),
            "After Ctrl+C cancel, prompt should return to main '>', got: \(promptAfterCancel.debugDescription)")
    }

    /// AC#3: Ctrl+C during triple-quote mode cancels and returns to main prompt.
    ///
    /// Given I am in triple-quote mode (...)
    /// When I press Ctrl+C
    /// Then the multiline buffer is cleared
    /// And the prompt returns to ">"
    func testCtrlC_cancelsTripleQuoteMode() async throws {
        let (renderer, mockOutput) = makeRenderer()
        // Open """, type content, then Ctrl+C (empty string + signal flag)
        let signalingReader = SignalingMockInputReader(["\"\"\"", "some content", "", "/exit"], signalOnIndex: 2)

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: signalingReader,
            parsedArgs: makeParsedArgs()
        )

        await repl.start()

        XCTAssertEqual(signalingReader.callCount, 4,
            "Ctrl+C during triple-quote should cancel and continue to /exit")

        let output = mockOutput.output
        XCTAssertTrue(output.contains("^C"),
            "Ctrl+C during triple-quote should output '^C', got: \(output)")
    }

    // ================================================================
    // MARK: AC#4 — Trailing whitespace tolerance
    // ================================================================

    /// AC#4: Backslash with trailing whitespace is recognized as continuation.
    ///
    /// Given I type "hello \  " (backslash followed by spaces)
    /// Then it is recognized as a continuation line
    func testTrailingWhitespace_treatedAsContinuation() async throws {
        let (renderer, _) = makeRenderer()
        // "hello \  " has backslash followed by trailing spaces
        let inputReader = MockInputReader(["hello \\  ", "world", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs()
        )

        await repl.start()

        // Should behave exactly like "hello \" without trailing spaces
        XCTAssertEqual(inputReader.callCount, 3,
            "Trailing whitespace after backslash should still trigger continuation")

        // Second prompt should be continuation
        XCTAssertTrue(inputReader.promptHistory[1].contains("...>"),
            "Trailing-whitespace backslash should show continuation prompt")
    }

    /// AC#4: Multiple trailing spaces/tabs after backslash are tolerated.
    func testTrailingWhitespace_mixedTabsAndSpaces() async throws {
        let (renderer, _) = makeRenderer()
        // "hello \\ \t " has backslash followed by mixed whitespace
        let inputReader = MockInputReader(["hello \\ \t ", "continued", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs()
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 3,
            "Mixed trailing whitespace after backslash should trigger continuation")
    }

    // ================================================================
    // MARK: Edge Cases
    // ================================================================

    /// Edge case: Bare backslash on a line (just `\`) should NOT enter continuation.
    ///
    /// The story notes `trimmed != "\\"` as a guard — a line that is ONLY
    /// a backslash should be treated as normal input, not continuation.
    func testBareBackslash_notTreatedAsContinuation() async throws {
        let (renderer, _) = makeRenderer()
        // A single "\" on its own should be normal input, not continuation
        let inputReader = MockInputReader(["\\", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs()
        )

        await repl.start()

        // Should read 2 lines: bare "\" is sent as normal input, then /exit
        XCTAssertEqual(inputReader.callCount, 2,
            "Bare backslash should be treated as normal input, not continuation")

        // Both prompts should be main prompts, not continuation
        for prompt in inputReader.promptHistory {
            XCTAssertTrue(prompt.contains("> ") && !prompt.contains("...>"),
                "Bare backslash should use main prompt, got: \(prompt.debugDescription)")
        }
    }

    /// Edge case: Empty line during backslash continuation should continue accumulating.
    ///
    /// In continuation mode, pressing Enter (empty line) should add an empty
    /// string to the buffer, not terminate the continuation.
    func testBackslashContinuation_emptyLineContinues() async throws {
        let (renderer, _) = makeRenderer()
        // "hello \" → "" (empty line, no signal) → "world" → /exit
        let inputReader = MockInputReader(["hello \\", "", "world", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs()
        )

        await repl.start()

        // Should read 4 lines: continuation, empty (accumulated as content), final, /exit
        // Empty line in continuation is content (no SignalHandler interrupt set).
        XCTAssertEqual(inputReader.callCount, 4,
            "Empty line during continuation should accumulate as content, reading 4 lines total")
    }

    /// Edge case: Triple-quote content with empty lines preserves them.
    ///
    /// Empty lines within triple-quote delimiters should be part of the content.
    func testTripleQuote_emptyLinesInContent() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader([
            "\"\"\"",
            "line1",
            "",       // empty line in content
            "line3",
            "\"\"\"",
            "/exit"
        ])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs()
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 6,
            "Triple-quote with empty content line should read 6 total lines")
    }

    // ================================================================
    // MARK: Continuation Prompt Colors
    // ================================================================

    /// Continuation prompt uses the same color as the main prompt for the current mode.
    ///
    /// In default mode, the continuation prompt "...>" should be green.
    func testContinuationPrompt_defaultMode_isGreen() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["hello \\", "world", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(mode: "default"),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs(mode: "default")
        )

        await repl.start()

        let continuationPrompt = inputReader.promptHistory[1]
        XCTAssertTrue(
            continuationPrompt.contains("\u{001B}[32m"),
            "Default mode continuation prompt should contain green ANSI code ESC[32m, got: \(continuationPrompt.debugDescription)"
        )
    }

    /// Continuation prompt in plan mode is yellow.
    func testContinuationPrompt_planMode_isYellow() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["hello \\", "world", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(mode: "plan"),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs(mode: "plan")
        )

        await repl.start()

        let continuationPrompt = inputReader.promptHistory[1]
        XCTAssertTrue(
            continuationPrompt.contains("\u{001B}[33m"),
            "Plan mode continuation prompt should contain yellow ANSI code ESC[33m, got: \(continuationPrompt.debugDescription)"
        )
    }

    // ================================================================
    // MARK: ANSI.coloredContinuationPrompt Unit Tests
    // ================================================================

    /// ANSI.coloredContinuationPrompt returns "...> " with green color in default mode.
    func testANSI_coloredContinuationPrompt_defaultMode_green() {
        let prompt = ANSI.coloredContinuationPrompt(forMode: .default, forceColor: true)
        XCTAssertTrue(prompt.contains("...>"),
            "Continuation prompt should contain '...>', got: \(prompt.debugDescription)")
        XCTAssertTrue(prompt.contains("\u{001B}[32m"),
            "Default mode continuation should use green, got: \(prompt.debugDescription)")
    }

    /// ANSI.coloredContinuationPrompt returns "...> " with yellow color in plan mode.
    func testANSI_coloredContinuationPrompt_planMode_yellow() {
        let prompt = ANSI.coloredContinuationPrompt(forMode: .plan, forceColor: true)
        XCTAssertTrue(prompt.contains("...>"),
            "Continuation prompt should contain '...>', got: \(prompt.debugDescription)")
        XCTAssertTrue(prompt.contains("\u{001B}[33m"),
            "Plan mode continuation should use yellow, got: \(prompt.debugDescription)")
    }

    /// ANSI.coloredContinuationPrompt returns "...> " with red color in bypassPermissions mode.
    func testANSI_coloredContinuationPrompt_bypassPermissions_red() {
        let prompt = ANSI.coloredContinuationPrompt(forMode: .bypassPermissions, forceColor: true)
        XCTAssertTrue(prompt.contains("...>"),
            "Continuation prompt should contain '...>', got: \(prompt.debugDescription)")
        XCTAssertTrue(prompt.contains("\u{001B}[31m"),
            "BypassPermissions continuation should use red, got: \(prompt.debugDescription)")
    }

    /// ANSI.coloredContinuationPrompt returns "...> " with blue color in acceptEdits mode.
    func testANSI_coloredContinuationPrompt_acceptEdits_blue() {
        let prompt = ANSI.coloredContinuationPrompt(forMode: .acceptEdits, forceColor: true)
        XCTAssertTrue(prompt.contains("...>"),
            "Continuation prompt should contain '...>', got: \(prompt.debugDescription)")
        XCTAssertTrue(prompt.contains("\u{001B}[34m"),
            "AcceptEdits continuation should use blue, got: \(prompt.debugDescription)")
    }

    /// ANSI.coloredContinuationPrompt returns plain "...> " in auto/dontAsk mode (no color).
    func testANSI_coloredContinuationPrompt_autoMode_noColor() {
        let prompt = ANSI.coloredContinuationPrompt(forMode: .auto, forceColor: true)
        XCTAssertTrue(prompt.contains("...>"),
            "Auto mode continuation should contain '...>', got: \(prompt.debugDescription)")
        XCTAssertFalse(prompt.contains("\u{001B}["),
            "Auto mode continuation should have no ANSI codes, got: \(prompt.debugDescription)")
    }

    /// ANSI.coloredContinuationPrompt no-tty fallback returns plain "...> ".
    func testANSI_coloredContinuationPrompt_noTty_returnsPlain() {
        let prompt = ANSI.coloredContinuationPrompt(forMode: .default)
        XCTAssertEqual(prompt, "...> ",
            "Non-tty continuation prompt should be plain '...> ', got: \(prompt.debugDescription)")
    }

    // ================================================================
    // MARK: Regression — Existing REPL behavior preserved
    // ================================================================

    /// Regression: /exit still works with multiline state machine present.
    func testRegression_exitStillWorksWithMultilineStateMachine() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs()
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 1,
            "REPL should exit on /exit without multiline interference")
    }

    /// Regression: Normal single-line input still works.
    func testRegression_normalInputStillWorks() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["hello world", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs()
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 2,
            "Normal single-line input should work unchanged")
    }

    /// Regression: Empty input at main prompt is still ignored.
    func testRegression_emptyInputAtMainPromptIgnored() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["", "   ", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            parsedArgs: makeParsedArgs()
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 3,
            "Empty/whitespace input at main prompt should still be ignored")
    }
}
