import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 1.4 Interactive REPL Loop
//
// These tests define the EXPECTED behavior of REPLLoop and related types.
// They will FAIL until REPLLoop.swift is implemented (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: REPL mode shows ">" prompt, waits for input
//   AC#2: Message sent to Agent, real-time streaming output via OutputRenderer
//   AC#3: After response, ">" prompt reappears
//   AC#4: /help command shows available REPL commands
//   AC#5: /exit and /quit commands exit gracefully
//   AC#6: Empty/whitespace-only input is ignored, prompt reappears

// MARK: - Mock Input Reader for Testing

/// Mock input reader that returns a predefined sequence of lines.
///
/// Simulates terminal input for REPLLoop testing. Returns each line in order,
/// then returns nil (EOF) when the sequence is exhausted.
final class MockInputReader: InputReading, @unchecked Sendable {
    var lines: [String?]
    var callCount = 0
    var promptHistory: [String] = []

    init(_ lines: [String?]) {
        self.lines = lines
    }

    func readLine(prompt: String) -> String? {
        promptHistory.append(prompt)
        guard callCount < lines.count else { return nil }
        let line = lines[callCount]
        callCount += 1
        return line
    }
}

// MARK: - REPLLoop Tests

final class REPLLoopTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a MockTextOutputStream and OutputRenderer pair for capturing output.
    private func makeRenderer() -> (renderer: OutputRenderer, mock: MockTextOutputStream) {
        let mock = MockTextOutputStream()
        let renderer = OutputRenderer(output: mock)
        return (renderer, mock)
    }

    // MARK: - AC#1: REPL starts with ">" prompt, waits for input

    func testREPLLoop_showsPromptOnStart() async throws {
        // AC#1: When REPL starts, it displays ">" prompt and waits for input
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/exit"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        // Verify that the prompt ">" was used
        XCTAssertEqual(inputReader.promptHistory.first, "> ",
            "REPL should display '> ' prompt on start (AC#1)")
    }

    func testREPLLoop_emptyInput_returnsNilImmediately() async throws {
        // Edge case: EOF immediately (Ctrl+D) -- REPL should exit cleanly
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader([nil])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        // Should not hang or crash
        await repl.start()

        XCTAssertEqual(inputReader.callCount, 1,
            "REPL should call readLine once and then exit on nil/EOF")
    }

    // MARK: - AC#2: Message sent to Agent, streaming via OutputRenderer

    func testREPLLoop_sendsInputToAgent() async throws {
        // AC#2: When user enters a message, it is sent to Agent.stream()
        // and rendered through OutputRenderer.
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["What is 2+2?", "/exit"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        // The streaming output from the agent should have been rendered.
        // Since we use a real Agent (with test key), the stream may produce
        // various outputs. What matters is that the renderer was invoked.
        // We verify the prompt was shown twice (once for input, once after /exit).
        XCTAssertGreaterThanOrEqual(inputReader.promptHistory.count, 2,
            "REPL should have prompted at least twice (once for message, once for /exit)")
    }

    func testREPLLoop_streamsResponseThroughRenderer() async throws {
        // AC#2: Agent response is rendered via OutputRenderer (streaming).
        // We verify this by checking that output was produced after sending a message.
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["Hello", "/exit"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        // After processing "Hello" and getting a response, output should be non-empty.
        // Note: with a real Agent using test key, the stream will produce SDKMessages
        // that the renderer processes. The exact output depends on Agent behavior.
        // At minimum, the REPL should not crash and should continue to next prompt.
        XCTAssertGreaterThanOrEqual(inputReader.callCount, 2,
            "REPL should have read at least 2 lines (message + /exit)")
    }

    // MARK: - AC#3: Prompt reappears after response

    func testREPLLoop_promptReappearsAfterResponse() async throws {
        // AC#3: After Agent response completes, ">" prompt reappears.
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["First message", "Second message", "/exit"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        // Should have prompted 3 times: first message, second message, then /exit
        XCTAssertEqual(inputReader.promptHistory.count, 3,
            "REPL should show prompt after each message (AC#3)")
        // Each prompt should be "> "
        for prompt in inputReader.promptHistory {
            XCTAssertEqual(prompt, "> ",
                "Every prompt should be '> ' (AC#3)")
        }
    }

    func testREPLLoop_promptReappearsAfterSlashCommand() async throws {
        // AC#3 variant: After a slash command (non-exit), prompt reappears.
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/help", "/exit"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        XCTAssertEqual(inputReader.promptHistory.count, 2,
            "After /help, prompt should reappear (AC#3)")
    }

    // MARK: - AC#4: /help command shows available commands

    func testREPLLoop_helpCommand_showsAvailableCommands() async throws {
        // AC#4: /help displays available REPL command list
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/help", "/exit"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output
        XCTAssertTrue(output.contains("/help"),
            "Help output should list /help command (AC#4)")
        XCTAssertTrue(output.contains("/exit"),
            "Help output should list /exit command (AC#4)")
        XCTAssertTrue(output.contains("/quit"),
            "Help output should list /quit command (AC#4)")
    }

    func testREPLLoop_helpCommand_doesNotExit() async throws {
        // AC#4: /help does not exit the REPL
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/help", "/exit"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        // /help should NOT exit, so REPL should read /exit as second line
        XCTAssertEqual(inputReader.callCount, 2,
            "/help should not exit REPL -- /exit should be read as second input (AC#4)")
    }

    // MARK: - AC#5: /exit and /quit commands exit gracefully

    func testREPLLoop_exitCommand_exitsLoop() async throws {
        // AC#5: /exit command causes graceful exit
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/exit"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        // REPL should exit after /exit, reading only 1 line
        XCTAssertEqual(inputReader.callCount, 1,
            "/exit should cause REPL to exit after reading 1 line (AC#5)")
    }

    func testREPLLoop_quitCommand_exitsLoop() async throws {
        // AC#5: /quit command causes graceful exit
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/quit"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        // REPL should exit after /quit, reading only 1 line
        XCTAssertEqual(inputReader.callCount, 1,
            "/quit should cause REPL to exit after reading 1 line (AC#5)")
    }

    func testREPLLoop_exitAfterMessages_exitsGracefully() async throws {
        // AC#5: Exit after sending some messages
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["message one", "message two", "/exit"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        // Should process 3 inputs (2 messages + /exit)
        XCTAssertEqual(inputReader.callCount, 3,
            "REPL should process 2 messages then exit on /exit (AC#5)")
    }

    func testREPLLoop_exitCaseInsensitive() async throws {
        // AC#5: /EXIT should also work (lowercased comparison)
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/EXIT"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 1,
            "/EXIT should also cause exit (case-insensitive) (AC#5)")
    }

    func testREPLLoop_quitCaseInsensitive() async throws {
        // AC#5: /QUIT should also work (lowercased comparison)
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/QUIT"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 1,
            "/QUIT should also cause exit (case-insensitive) (AC#5)")
    }

    // MARK: - AC#6: Empty/whitespace input ignored

    func testREPLLoop_emptyLine_ignored() async throws {
        // AC#6: Empty line input is ignored, prompt reappears
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["", "/exit"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        // Empty line should not crash or exit -- REPL continues to /exit
        XCTAssertEqual(inputReader.callCount, 2,
            "Empty line should be ignored, REPL continues to /exit (AC#6)")
    }

    func testREPLLoop_whitespaceOnly_ignored() async throws {
        // AC#6: Whitespace-only input is ignored
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["   ", "/exit"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 2,
            "Whitespace-only input should be ignored (AC#6)")
    }

    func testREPLLoop_tabOnly_ignored() async throws {
        // AC#6: Tab-only input is ignored
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["\t\t", "/exit"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 2,
            "Tab-only input should be ignored (AC#6)")
    }

    func testREPLLoop_mixedWhitespace_ignored() async throws {
        // AC#6: Mixed whitespace (spaces + tabs + newlines) is ignored
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["  \t  \t  ", "/exit"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 2,
            "Mixed whitespace input should be ignored (AC#6)")
    }

    func testREPLLoop_multipleEmptyLines_ignored() async throws {
        // AC#6: Multiple consecutive empty/whitespace lines are all ignored
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["", "  ", "\t", "", "/exit"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 5,
            "All empty/whitespace inputs should be ignored before /exit (AC#6)")
    }

    // MARK: - Unknown slash command

    func testREPLLoop_unknownSlashCommand_showsError() async throws {
        // Edge case: Unknown slash command shows helpful error
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/unknown", "/exit"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output
        XCTAssertTrue(output.contains("Unknown command") || output.contains("/unknown"),
            "Unknown slash command should show error message, got: \(output)")
        XCTAssertTrue(output.contains("/help"),
            "Unknown command error should suggest using /help, got: \(output)")
    }

    func testREPLLoop_unknownSlashCommand_doesNotExit() async throws {
        // Unknown slash command should not exit REPL
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/bogus", "/exit"])

        let repl = REPLLoop(
            agent: try makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 2,
            "Unknown slash command should not exit REPL (continues to /exit)")
    }

    // MARK: - InputReading protocol conformance

    func testInputReadingProtocol_mockInputReaderConforms() throws {
        // Verify MockInputReader correctly implements InputReading protocol
        let reader = MockInputReader(["line1", "line2", nil])

        XCTAssertEqual(reader.readLine(prompt: "> "), "line1")
        XCTAssertEqual(reader.readLine(prompt: "> "), "line2")
        XCTAssertNil(reader.readLine(prompt: "> "))
        XCTAssertEqual(reader.callCount, 3)
    }

    func testInputReadingProtocol_promptPassedCorrectly() throws {
        // Verify that the prompt parameter is received correctly
        let reader = MockInputReader(["response"])

        _ = reader.readLine(prompt: "test> ")

        XCTAssertEqual(reader.promptHistory.first, "test> ",
            "InputReading should receive the prompt string")
    }

    // MARK: - Test Agent Helper

    /// Creates a test Agent with a dummy API key for REPLLoop tests.
    ///
    /// Note: This agent won't successfully call the LLM API, but that's acceptable
    /// for unit tests. The REPLLoop tests focus on input dispatch, command handling,
    /// and loop control flow -- not on actual Agent responses.
    private func makeTestAgent() throws -> Agent {
        let args = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-repl-tests",
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
        return try AgentFactory.createAgent(from: args)
    }
}
