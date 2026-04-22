import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 8-1 AC#5 Non-Interactive Permission Auto-Approval
//
// These tests define the EXPECTED behavior after fixing the non-interactive
// permission mode. Currently, non-interactive default/plan modes DENY write
// tools. The fix should AUTO-APPROVE with a warning instead.
//
// They will FAIL until PermissionHandler.swift is updated (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#5: Non-interactive single-shot mode auto-approves tools with warning
//
// NOTE: These tests assert the OPPOSITE behavior of existing tests in
// PermissionHandlerTests.swift (which test the current deny behavior).
// When the fix is applied, the existing deny tests should be updated to
// match the new auto-approve behavior.

final class TechnicalDebtAC5Tests: XCTestCase {

    // MARK: - Helpers

    private func makeMocks(lines: [String?]) -> (reader: MockInputReader, output: MockPermissionOutput) {
        let reader = MockInputReader(lines)
        let output = MockPermissionOutput()
        return (reader, output)
    }

    private func makeContext() -> ToolContext {
        ToolContext(cwd: "/tmp/test", toolUseId: "test-tool-use-ac5")
    }

    // MARK: - P0: Non-interactive default mode auto-approves write tools

    /// AC#5: In non-interactive default mode, write tools should be AUTO-APPROVED
    /// (not denied). The current behavior denies them, which breaks single-shot
    /// mode where the user expects the agent to actually perform actions.
    ///
    /// This test will FAIL until the fix is applied (currently returns .deny).
    func testNonInteractive_defaultMode_autoApprovesWriteTool() async throws {
        let (reader, output) = makeMocks(lines: [])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .default,
            reader: reader,
            renderer: OutputRenderer(output: output),
            isInteractive: false
        )

        let writeTool = MockTool(name: "Write", isReadOnly: false)
        let result = await canUseTool(writeTool, ["file_path": "/tmp/out.txt"], makeContext())

        XCTAssertEqual(result?.behavior, .allow,
            "Non-interactive default mode should AUTO-APPROVE write tools (AC#5). " +
            "Current behavior denies them, breaking single-shot mode.")
    }

    /// AC#5: In non-interactive plan mode, ALL tools (including read-only)
    /// should be AUTO-APPROVED (not denied). Single-shot plan mode should work.
    ///
    /// This test will FAIL until the fix is applied (currently returns .deny).
    func testNonInteractive_planMode_autoApprovesAllTools() async throws {
        let (reader, output) = makeMocks(lines: [])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .plan,
            reader: reader,
            renderer: OutputRenderer(output: output),
            isInteractive: false
        )

        // Test with a read-only tool
        let readTool = MockTool(name: "Read", isReadOnly: true)
        let readResult = await canUseTool(readTool, ["file_path": "/tmp/test.txt"], makeContext())

        XCTAssertEqual(readResult?.behavior, .allow,
            "Non-interactive plan mode should AUTO-APPROVE read-only tools (AC#5)")

        // Test with a write tool
        let writeTool = MockTool(name: "Write", isReadOnly: false)
        let writeResult = await canUseTool(writeTool, ["file_path": "/tmp/out.txt"], makeContext())

        XCTAssertEqual(writeResult?.behavior, .allow,
            "Non-interactive plan mode should AUTO-APPROVE write tools (AC#5)")
    }

    // MARK: - P1: Warning message is shown

    /// AC#5: When auto-approving in non-interactive mode, a warning should be
    /// displayed so the user knows tools are being auto-approved.
    func testNonInteractive_defaultMode_showsWarning() async throws {
        let (reader, output) = makeMocks(lines: [])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .default,
            reader: reader,
            renderer: OutputRenderer(output: output),
            isInteractive: false
        )

        let writeTool = MockTool(name: "Write", isReadOnly: false)
        _ = await canUseTool(writeTool, ["file_path": "/tmp/out.txt"], makeContext())

        // The output should contain a warning about auto-approval
        let promptOutput = output.output.lowercased()
        XCTAssertTrue(
            promptOutput.contains("auto-approv") ||
            promptOutput.contains("non-interactive") ||
            promptOutput.contains("bypasspermissions"),
            "Non-interactive auto-approval should show a warning (AC#5). Got: \(output.output)"
        )
    }

    /// AC#5: Non-interactive plan mode should also show a warning.
    func testNonInteractive_planMode_showsWarning() async throws {
        let (reader, output) = makeMocks(lines: [])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .plan,
            reader: reader,
            renderer: OutputRenderer(output: output),
            isInteractive: false
        )

        let writeTool = MockTool(name: "Bash", isReadOnly: false)
        _ = await canUseTool(writeTool, ["command": "ls"], makeContext())

        let promptOutput = output.output.lowercased()
        XCTAssertTrue(
            promptOutput.contains("auto-approv") ||
            promptOutput.contains("non-interactive") ||
            promptOutput.contains("bypasspermissions"),
            "Non-interactive plan auto-approval should show a warning (AC#5). Got: \(output.output)"
        )
    }
}
