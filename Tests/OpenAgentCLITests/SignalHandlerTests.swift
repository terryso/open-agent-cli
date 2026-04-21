import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 5.3 Graceful Interrupt Handling
//
// These tests define the EXPECTED behavior of SignalHandler and the
// interrupt integration in REPLLoop. They will FAIL until
// SignalHandler.swift is implemented and REPLLoop.swift is updated
// (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: Ctrl+C during streaming interrupts Agent, prompt reappears
//   AC#2: Ctrl+C during permission prompt cancels operation
//   AC#3: Double Ctrl+C within 1 second exits CLI
//   AC#4: SIGTERM saves session and exits cleanly
//
// New Types Required:
//   - SignalEvent enum: .none, .interrupt, .forceExit, .terminate
//   - SignalHandler enum: register(), check() -> SignalEvent, clearInterrupt()

final class SignalHandlerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Register signal handlers before each test to ensure clean state
        SignalHandler.register()
    }

    override func tearDown() {
        // Clear any pending interrupt state between tests
        SignalHandler.clearInterrupt()
        super.tearDown()
    }

    // ================================================================
    // MARK: AC#1 - SIGINT during streaming interrupts Agent
    // ================================================================

    /// AC#1: After register(), SignalHandler should respond to SIGINT.
    ///
    /// When SIGINT is raised, `check()` should return `.interrupt`.
    func testSignalHandler_singleSIGINT_returnsInterrupt() {
        // Arrange: SignalHandler is registered in setUp()

        // Act: Send SIGINT to the process
        raise(SIGINT)

        // Assert: check() should return .interrupt
        let event = SignalHandler.check()
        XCTAssertEqual(event, .interrupt,
            "Single SIGINT should return .interrupt (AC#1)")
    }

    /// AC#1: When no signal is sent, check() returns .none.
    func testSignalHandler_noSignal_returnsNone() {
        // Arrange: SignalHandler is registered, no signals sent

        // Act & Assert: check() should return .none
        let event = SignalHandler.check()
        XCTAssertEqual(event, .none,
            "No signal should return .none")
    }

    /// AC#1: After handling an interrupt, clearInterrupt() resets state.
    func testSignalHandler_clearInterrupt_resetsState() {
        // Arrange: Send SIGINT and consume it
        raise(SIGINT)
        _ = SignalHandler.check()

        // Act: Clear the interrupt state
        SignalHandler.clearInterrupt()

        // Assert: check() should return .none after clearing
        let event = SignalHandler.check()
        XCTAssertEqual(event, .none,
            "After clearInterrupt(), check() should return .none (AC#1)")
    }

    /// AC#1: Register should be callable multiple times without error (idempotent).
    func testSignalHandler_registersHandlers_idempotent() {
        // Arrange & Act: Register multiple times (setUp already called once)
        SignalHandler.register()
        SignalHandler.register()

        // Assert: Should still work correctly
        raise(SIGINT)
        let event = SignalHandler.check()
        XCTAssertEqual(event, .interrupt,
            "Register should be idempotent - still returns .interrupt after multiple register() calls")
    }

    // ================================================================
    // MARK: AC#3 - Double Ctrl+C within 1 second exits CLI
    // ================================================================

    /// AC#3: Two SIGINTs within 1 second should return .forceExit.
    func testSignalHandler_doubleSIGINT_returnsForceExit() {
        // Arrange: SignalHandler is registered in setUp()

        // Act: Send two SIGINTs in quick succession
        raise(SIGINT)
        raise(SIGINT)

        // Assert: check() should return .forceExit
        let event = SignalHandler.check()
        XCTAssertEqual(event, .forceExit,
            "Double SIGINT within 1 second should return .forceExit (AC#3)")
    }

    /// AC#3: Two SIGINTs more than 1 second apart should return .interrupt twice.
    func testSignalHandler_slowDoubleSIGINT_returnsInterrupt() {
        // Arrange: SignalHandler is registered in setUp()

        // Act: Send first SIGINT and consume it
        raise(SIGINT)
        let first = SignalHandler.check()
        XCTAssertEqual(first, .interrupt,
            "First SIGINT should return .interrupt")

        // Simulate passage of time by waiting > 1 second
        // Note: In a real test we'd mock the clock, but for ATDD we use
        // a short sleep to demonstrate the behavior.
        // For fast test execution, we clear and wait a brief moment.
        SignalHandler.clearInterrupt()

        // Wait just over 1 second to exceed the double-press window
        let expectation = self.expectation(description: "wait for double-press window to expire")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        // Act: Send second SIGINT after the window expired
        raise(SIGINT)
        let second = SignalHandler.check()

        // Assert: Should return .interrupt (not .forceExit) because window expired
        XCTAssertEqual(second, .interrupt,
            "SIGINT after 1+ second should return .interrupt (not .forceExit) (AC#3)")
    }

    // ================================================================
    // MARK: AC#4 - SIGTERM saves session and exits cleanly
    // ================================================================

    /// AC#4: SIGTERM should return .terminate.
    func testSignalHandler_SIGTERM_returnsTerminate() {
        // Arrange: SignalHandler is registered in setUp()

        // Act: Send SIGTERM
        raise(SIGTERM)

        // Assert: check() should return .terminate
        let event = SignalHandler.check()
        XCTAssertEqual(event, .terminate,
            "SIGTERM should return .terminate (AC#4)")
    }

    // ================================================================
    // MARK: AC#2 - Interrupt during permission prompt
    // ================================================================

    /// AC#2: Permission prompt readLine returning nil (Ctrl+C behavior) should deny.
    ///
    /// This verifies that the existing PermissionHandler behavior (readLine
    /// returning nil -> .deny) is preserved, which is the natural Ctrl+C
    /// handling in permission prompts. The signal handler sets the interrupt
    /// flag, and readLine() returns nil due to SIGINT.
    func testPermissionPrompt_readLineNil_returnsDeny() async throws {
        // Arrange: MockInputReader that returns nil (simulating Ctrl+C)
        let reader = MockInputReader([nil])
        let output = MockPermissionOutput()

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .default,
            reader: reader,
            renderer: OutputRenderer(output: output),
            isInteractive: true
        )

        let writeTool = MockTool(name: "Bash", isReadOnly: false)
        let context = ToolContext(cwd: "/tmp/test", toolUseId: "test-001")

        // Act: canUseTool with nil input (Ctrl+C during prompt)
        let result = await canUseTool(writeTool, ["command": "rm -rf /tmp/test"], context)

        // Assert: Should deny the tool
        XCTAssertEqual(result?.behavior, .deny,
            "readLine returning nil (Ctrl+C) should deny the tool (AC#2)")
    }
}
