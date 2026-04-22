import XCTest
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 8-1 AC#4 --stdin + --skill Mutual Exclusion
//
// These tests define the EXPECTED behavior when both --stdin and --skill
// flags are passed together. This combination is ambiguous (both provide
// prompt content) and should be rejected with a clear error.
//
// They will FAIL until validation is added in CLI.swift or ArgumentParser.swift
// (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#4: --stdin + --skill together should show clear error and exit(1)

final class TechnicalDebtAC4Tests: XCTestCase {

    // MARK: - P0: Both flags set returns error

    /// AC#4: When both --stdin and --skill are provided, ArgumentParser should
    /// set shouldExit=true with an error message.
    ///
    /// This test will FAIL until the mutual exclusion validation is added.
    func testStdinAndSkill_bothSet_returnsError() throws {
        let result = ArgumentParser.parse([
            "openagent", "--stdin", "--skill", "my-skill"
        ])

        XCTAssertTrue(result.shouldExit,
            "--stdin + --skill should trigger shouldExit (AC#4)")
        XCTAssertEqual(result.exitCode, 1,
            "--stdin + --skill should set exit code 1 (AC#4)")
    }

    /// AC#4: The error message for --stdin + --skill should clearly state
    /// they cannot be used together.
    func testStdinAndSkill_errorMessage() throws {
        let result = ArgumentParser.parse([
            "openagent", "--stdin", "--skill", "my-skill"
        ])

        let message = result.errorMessage ?? ""
        XCTAssertTrue(
            message.lowercased().contains("stdin") &&
            message.lowercased().contains("skill"),
            "Error message should mention both --stdin and --skill (AC#4). Got: \(message)"
        )
        XCTAssertTrue(
            message.lowercased().contains("together") ||
            message.lowercased().contains("cannot") ||
            message.lowercased().contains("incompatible") ||
            message.lowercased().contains("mutually"),
            "Error message should indicate they cannot be combined (AC#4). Got: \(message)"
        )
    }

    // MARK: - P1: --stdin alone is fine

    /// AC#4 regression: --stdin without --skill should not error.
    func testStdinWithoutSkill_noError() throws {
        let result = ArgumentParser.parse(["openagent", "--stdin"])

        XCTAssertFalse(result.shouldExit,
            "--stdin alone should not trigger shouldExit (AC#4 regression)")
        XCTAssertNil(result.errorMessage,
            "--stdin alone should not produce error message (AC#4 regression)")
        XCTAssertTrue(result.stdin,
            "--stdin flag should still be set")
    }

    // MARK: - P1: --skill alone is fine

    /// AC#4 regression: --skill without --stdin should not error.
    func testSkillWithoutStdin_noError() throws {
        let result = ArgumentParser.parse(["openagent", "--skill", "my-skill"])

        XCTAssertFalse(result.shouldExit,
            "--skill alone should not trigger shouldExit (AC#4 regression)")
        XCTAssertNil(result.errorMessage,
            "--skill alone should not produce error message (AC#4 regression)")
        XCTAssertEqual(result.skillName, "my-skill",
            "--skill flag should still be parsed")
    }
}
