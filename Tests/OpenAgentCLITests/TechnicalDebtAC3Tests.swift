import XCTest
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 8-1 AC#3 Fix stdin Infinite Blocking on Terminal
//
// These tests define the EXPECTED behavior after adding an isatty() check
// to prevent stdin from blocking infinitely when run from a terminal (TTY).
//
// They will FAIL until CLI.swift is updated with the isatty() guard (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#3: --stdin without piped input should show error and exit (not block)
//
// Proposed solution: Add isatty(STDIN_FILENO) check in readStdin() or before it.

final class TechnicalDebtAC3Tests: XCTestCase {

    // MARK: - P0: isatty check exists

    /// AC#3: CLI should have an isTerminalStdin() or equivalent check.
    ///
    /// When stdin is a terminal (TTY), readStdin() should NOT call
    /// FileHandle.standardInput.readDataToEndOfFile() which blocks forever.
    ///
    /// This test verifies the method exists. It will FAIL (not compile)
    /// until the isatty check method is added.
    func testReadStdin_terminalInput_returnsError() {
        // Verify that CLI has a method to check if stdin is a terminal.
        // This could be:
        //   - CLI.isStdinTerminal() -> Bool
        //   - Or the check is inside readStdin() itself
        //
        // We verify the behavior through CLI.readStdin() which should
        // throw or return nil when stdin is a terminal.

        // Since we can't easily mock FileHandle.standardInput in unit tests,
        // we verify the architectural contract:
        // 1. ParsedArgs has stdin property (already tested in StdinInputTests)
        // 2. CLI.StdinError should have a terminalInput case or equivalent
        //
        // NOTE: In unit tests, FileHandle.standardInput IS a terminal,
        // so calling readStdin() directly would block. We test the error
        // type exists instead.

        // Verify StdinError has a case for terminal input
        // This will FAIL until the new error case is added
        let error = CLI.StdinError.terminalInput
        XCTAssertNotNil(error.errorDescription,
            "StdinError.terminalInput should have a localized description")
    }

    // MARK: - P0: Error message mentions piped input

    /// AC#3: The error message when stdin is a terminal should be clear
    /// and tell the user to pipe input.
    func testReadStdin_isattyCheck_errorMessage() {
        // Verify the error message is user-friendly
        let error = CLI.StdinError.terminalInput
        let message = error.errorDescription ?? ""

        XCTAssertTrue(message.lowercased().contains("stdin") ||
                      message.lowercased().contains("pipe") ||
                      message.lowercased().contains("piped"),
            "Terminal stdin error should mention stdin/pipe/piped. Got: \(message)")

        // Should suggest how to fix it
        XCTAssertTrue(message.contains("echo") || message.contains("|") || message.contains("pipe"),
            "Error should suggest piping input. Got: \(message)")
    }

    // MARK: - P1: Piped stdin still works (regression)

    /// AC#3: When stdin is NOT a terminal (piped input), readStdin() should
    /// still work as before. This is a regression guard.
    ///
    /// Note: In the unit test environment, stdin IS a terminal, so we
    /// cannot directly test piped stdin here. This test verifies the
    /// error type structure is correct and the original error case
    /// (invalidEncoding) still exists.
    func testReadStdin_pipeInput_succeeds() {
        // Verify the original StdinError.invalidEncoding still exists
        // (regression: adding isatty check should not break existing errors)
        let encodingError = CLI.StdinError.invalidEncoding
        XCTAssertNotNil(encodingError.errorDescription,
            "StdinError.invalidEncoding should still exist after adding isatty check")

        // Verify both error cases coexist
        // This implicitly tests that the enum is not corrupted
        let terminalError = CLI.StdinError.terminalInput
        XCTAssertNotEqual(encodingError.errorDescription, terminalError.errorDescription,
            "invalidEncoding and terminalInput should have different error messages")
    }
}
