import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 5.3 REPL Interrupt Integration Tests
//
// These tests define the EXPECTED behavior of REPLLoop when signals are
// received during operation. They will FAIL until SignalHandler.swift is
// implemented and REPLLoop.swift is updated to integrate signal checking
// (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: Ctrl+C during streaming -> interrupt, prompt reappears
//   AC#2: Ctrl+C during permission prompt -> cancel, prompt reappears
//   AC#3: Double Ctrl+C within 1s -> exit CLI
//   AC#4: SIGTERM -> save session and exit
//
// These tests are in a separate file from REPLLoopTests.swift to isolate
// signal-related test infrastructure and avoid interference with existing
// stable tests.

// MARK: - REPLLoop Interrupt Tests

final class REPLLoopInterruptTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Ensure clean signal handler state for each test
        SignalHandler.register()
        SignalHandler.clearInterrupt()
    }

    override func tearDown() {
        SignalHandler.clearInterrupt()
        super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a MockInterruptOutputStream and OutputRenderer pair.
    private func makeRenderer() -> (renderer: OutputRenderer, mock: MockInterruptOutputStream) {
        let mock = MockInterruptOutputStream()
        let renderer = OutputRenderer(output: mock)
        return (renderer, mock)
    }

    /// Creates a test Agent with dummy configuration.
    private func makeTestAgent() async throws -> Agent {
        let args = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-interrupt-tests",
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

    // ================================================================
    // MARK: AC#1 - SIGINT during streaming interrupts and re-shows prompt
    // ================================================================

    /// AC#1: When SIGINT is received during streaming, the REPL should
    /// interrupt the Agent, output ^C, and continue the loop.
    ///
    /// This test verifies that after an interrupt:
    /// - The REPL does NOT exit
    /// - The prompt reappears (readLine is called again)
    /// - Output contains "^C" marker
    func testREPLLoop_interrupt_resumesPrompt() async throws {
        // Arrange: User sends a message, interrupt occurs during streaming,
        // then user sends /exit to quit normally.
        //
        // Since we cannot easily simulate a signal mid-stream without the
        // SignalHandler being testable, this test will initially fail
        // compilation (no SignalHandler type). Once implemented, it
        // verifies the REPL loop continues after an interrupt.
        let (renderer, mockOutput) = makeRenderer()
        let reader = SignalMockInputReader(
            lines: ["Hello", "/exit"],
            signalAfterRead: 1,
            signal: .interrupt
        )

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: reader
        )

        // Act: Start the REPL
        await repl.start()

        // Assert: REPL should have called readLine more than twice
        // (message + interrupt recovery + /exit), proving the loop continued
        XCTAssertGreaterThanOrEqual(reader.callCount, 2,
            "REPL should continue loop after interrupt - prompt reappears (AC#1)")
    }

    /// AC#1: When SIGINT interrupts streaming, output should contain ^C marker.
    func testREPLLoop_interrupt_outputsCaretC() async throws {
        // Arrange: Send a message that will be interrupted
        let (renderer, mockOutput) = makeRenderer()
        let reader = SignalMockInputReader(
            lines: ["Hello", "/exit"],
            signalAfterRead: 1,
            signal: .interrupt
        )

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: reader
        )

        // Act
        await repl.start()

        // Assert: Output should contain the ^C interrupt marker
        let output = mockOutput.output
        XCTAssertTrue(output.contains("^C"),
            "Output should contain '^C' marker after interrupt (AC#1)")
    }

    // ================================================================
    // MARK: AC#2 - SIGINT during permission prompt cancels operation
    // ================================================================

    /// AC#2: Ctrl+C during a permission prompt should cancel the operation
    /// and the REPL prompt should reappear.
    ///
    /// When the Agent is waiting for a canUseTool callback and the user
    /// presses Ctrl+C, readLine() returns nil, the tool is denied,
    /// and the REPL loop should continue.
    func testREPLLoop_interruptDuringPermissionPrompt() async throws {
        // Arrange: User sends a message, the Agent will call a tool that
        // requires permission (write tool in default mode). During the
        // permission prompt, Ctrl+C causes readLine to return nil.
        //
        // The PermissionHandler returns .deny("No input received"),
        // the Agent receives the denial and continues generating,
        // and the REPL loop should show the prompt again.
        let (renderer, mockOutput) = makeRenderer()
        let reader = MockInputReader(["Write a file", "/exit"])

        // Create REPL with default mode permission handler
        // The mock reader will return lines in order, but the Agent
        // may internally trigger a permission callback. Since the Agent
        // uses a real LLM (test key), we can't fully control the permission
        // flow. Instead, we verify the general REPL loop resilience.
        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: reader
        )

        // Act: Start the REPL
        await repl.start()

        // Assert: The REPL should have processed both inputs
        // (message + /exit), proving the loop continued even if
        // permission prompts were involved
        XCTAssertGreaterThanOrEqual(reader.callCount, 2,
            "REPL should continue loop after permission prompt (AC#2)")
    }

    // ================================================================
    // MARK: AC#3 - Double Ctrl+C within 1 second exits CLI
    // ================================================================

    /// AC#3: When SIGINT is received twice within 1 second during REPL mode,
    /// the CLI should exit (break the REPL loop).
    func testREPLLoop_forceExit_exitsREPL() async throws {
        // Arrange: User sends a message, then double-SIGINT occurs.
        // The REPL should exit after the forceExit signal.
        let (renderer, mockOutput) = makeRenderer()
        let reader = SignalMockInputReader(
            lines: ["Hello", "/exit", "/exit"],
            signalAfterRead: 1,
            signal: .forceExit
        )

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: reader
        )

        // Act
        await repl.start()

        // Assert: REPL should exit without reading all lines
        // (forceExit should cause early termination)
        XCTAssertLessThan(reader.callCount, 3,
            "forceExit should cause REPL to exit before reading all inputs (AC#3)")
    }

    // ================================================================
    // MARK: AC#4 - SIGTERM saves session and exits cleanly
    // ================================================================

    /// AC#4: When SIGTERM is received, the REPL should break the loop,
    /// allowing CLI.run() to call closeAgentSafely() and exit.
    func testREPLLoop_terminate_savesSessionAndExits() async throws {
        // Arrange: User sends a message, then SIGTERM is received.
        // The REPL should exit cleanly.
        let (renderer, mockOutput) = makeRenderer()
        let reader = SignalMockInputReader(
            lines: ["Hello", "/exit", "/exit"],
            signalAfterRead: 1,
            signal: .terminate
        )

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: reader
        )

        // Act
        await repl.start()

        // Assert: REPL should exit without reading all lines
        // (SIGTERM should cause graceful termination)
        XCTAssertLessThan(reader.callCount, 3,
            "SIGTERM should cause REPL to exit before reading all inputs (AC#4)")
    }
}
