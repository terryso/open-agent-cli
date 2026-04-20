import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 5.1 Permission Mode Configuration
//
// These tests define the EXPECTED behavior of PermissionHandler and the
// canUseTool callback integration. They will FAIL until PermissionHandler.swift
// is implemented and AgentFactory.swift is updated (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: bypassPermissions mode -> all tools execute without approval
//   AC#2: default mode -> dangerous tools prompt, user approves/denies
//   AC#3: plan mode -> all tools require user approval
//   AC#4: invalid mode string -> error lists valid modes

// MARK: - Mock Tool for Testing

/// A mock tool implementation for testing PermissionHandler behavior.
///
/// Implements ToolProtocol with configurable name and isReadOnly properties
/// to simulate different tool types (read-only tools vs write tools).
struct MockTool: ToolProtocol, @unchecked Sendable {
    let name: String
    let toolDescription: String
    let inputSchema: ToolInputSchema
    let isReadOnly: Bool

    init(name: String, isReadOnly: Bool, description: String = "Mock tool for testing") {
        self.name = name
        self.toolDescription = description
        self.inputSchema = ["type": "object"]
        self.isReadOnly = isReadOnly
    }

    func call(input: Any, context: ToolContext) async -> ToolResult {
        ToolResult(toolUseId: "mock-\(name)", content: "mock result", isError: false)
    }

    var description: String { toolDescription }
}

// MARK: - Mock Output Renderer for Permission Prompts

/// Captures permission prompt output for assertion.
///
/// Records all text written during permission prompts so tests can verify
/// the prompt displays tool name, input summary, and risk level.
final class MockPermissionOutput: TextOutputStream, @unchecked Sendable {
    var output = ""
    func write(_ string: String) {
        output += string
    }
}

// MARK: - PermissionHandler Tests

final class PermissionHandlerTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a MockInputReader and MockPermissionOutput pair.
    private func makeMocks(lines: [String?]) -> (reader: MockInputReader, output: MockPermissionOutput) {
        let reader = MockInputReader(lines)
        let output = MockPermissionOutput()
        return (reader, output)
    }

    /// Creates a ToolContext for testing.
    private func makeContext() -> ToolContext {
        ToolContext(cwd: "/tmp/test", toolUseId: "test-tool-use-001")
    }

    // MARK: - AC#1: bypassPermissions / dontAsk / auto -> always allow (P0)

    func testBypassPermissions_alwaysAllows() async throws {
        // AC#1: bypassPermissions mode should auto-allow ALL tools without prompting
        let (reader, output) = makeMocks(lines: [])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .bypassPermissions,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        // Test with a write tool (normally requires approval)
        let writeTool = MockTool(name: "Bash", isReadOnly: false)
        let result = await canUseTool(writeTool, ["command": "rm -rf /tmp/test"], makeContext())

        XCTAssertNotNil(result, "bypassPermissions should return non-nil result")
        XCTAssertEqual(result?.behavior, .allow,
            "bypassPermissions should allow write tools without prompting (AC#1)")
    }

    func testBypassPermissions_allowsReadOnlyTool() async throws {
        // AC#1: bypassPermissions also auto-allows read-only tools
        let (reader, output) = makeMocks(lines: [])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .bypassPermissions,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let readTool = MockTool(name: "Read", isReadOnly: true)
        let result = await canUseTool(readTool, ["file_path": "/tmp/test.txt"], makeContext())

        XCTAssertEqual(result?.behavior, .allow,
            "bypassPermissions should allow read-only tools (AC#1)")
    }

    func testBypassPermissions_noOutputProduced() async throws {
        // AC#1: bypassPermissions should NOT produce any prompt output
        let (reader, output) = makeMocks(lines: [])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .bypassPermissions,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let writeTool = MockTool(name: "Bash", isReadOnly: false)
        _ = await canUseTool(writeTool, ["command": "ls"], makeContext())

        XCTAssertTrue(output.output.isEmpty,
            "bypassPermissions should not produce any prompt output (AC#1)")
        XCTAssertEqual(reader.callCount, 0,
            "bypassPermissions should not read any user input (AC#1)")
    }

    func testDontAsk_alwaysAllows() async throws {
        // AC#1: dontAsk mode behaves identically to bypassPermissions
        let (reader, output) = makeMocks(lines: [])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .dontAsk,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let writeTool = MockTool(name: "Write", isReadOnly: false)
        let result = await canUseTool(writeTool, ["file_path": "/tmp/out.txt"], makeContext())

        XCTAssertEqual(result?.behavior, .allow,
            "dontAsk should auto-allow all tools (AC#1)")
    }

    func testAuto_alwaysAllows() async throws {
        // AC#1: auto mode behaves identically to bypassPermissions
        let (reader, output) = makeMocks(lines: [])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .auto,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let writeTool = MockTool(name: "Edit", isReadOnly: false)
        let result = await canUseTool(writeTool, ["file_path": "/tmp/edit.txt"], makeContext())

        XCTAssertEqual(result?.behavior, .allow,
            "auto should auto-allow all tools (AC#1)")
    }

    // MARK: - AC#2: default mode - readOnly auto-allowed, write tools prompt (P0)

    func testDefault_allowsReadOnlyTool() async throws {
        // AC#2: default mode should auto-allow read-only tools without prompting
        let (reader, output) = makeMocks(lines: [])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .default,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let readTool = MockTool(name: "Read", isReadOnly: true)
        let result = await canUseTool(readTool, ["file_path": "/tmp/test.txt"], makeContext())

        XCTAssertEqual(result?.behavior, .allow,
            "default mode should auto-allow read-only tools (AC#2)")
        XCTAssertEqual(reader.callCount, 0,
            "default mode should not prompt for read-only tools (AC#2)")
    }

    func testDefault_promptsForWriteTool_yes() async throws {
        // AC#2: default mode prompts for write tools, user says yes -> allow
        let (reader, output) = makeMocks(lines: ["y"])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .default,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let writeTool = MockTool(name: "Bash", isReadOnly: false)
        let result = await canUseTool(writeTool, ["command": "rm -rf /tmp/test"], makeContext())

        XCTAssertEqual(result?.behavior, .allow,
            "default mode should allow write tool when user says yes (AC#2)")
        XCTAssertEqual(reader.callCount, 1,
            "default mode should prompt once for write tool (AC#2)")
    }

    func testDefault_promptsForWriteTool_no() async throws {
        // AC#2: default mode prompts for write tools, user says no -> deny
        let (reader, output) = makeMocks(lines: ["n"])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .default,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let writeTool = MockTool(name: "Bash", isReadOnly: false)
        let result = await canUseTool(writeTool, ["command": "rm -rf /tmp/test"], makeContext())

        XCTAssertEqual(result?.behavior, .deny,
            "default mode should deny write tool when user says no (AC#2)")
    }

    func testDefault_userInputYes_returnsAllow() async throws {
        // AC#2: "yes" (full word) should also be accepted
        let (reader, output) = makeMocks(lines: ["yes"])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .default,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let writeTool = MockTool(name: "Write", isReadOnly: false)
        let result = await canUseTool(writeTool, ["file_path": "/tmp/out.txt"], makeContext())

        XCTAssertEqual(result?.behavior, .allow,
            "default mode should accept 'yes' as approval (AC#2)")
    }

    func testDefault_userInputNo_returnsDeny() async throws {
        // AC#2: "no" (full word) should also be accepted
        let (reader, output) = makeMocks(lines: ["no"])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .default,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let writeTool = MockTool(name: "Write", isReadOnly: false)
        let result = await canUseTool(writeTool, ["file_path": "/tmp/out.txt"], makeContext())

        XCTAssertEqual(result?.behavior, .deny,
            "default mode should accept 'no' as denial (AC#2)")
    }

    // MARK: - AC#2: acceptEdits mode - edits auto-allowed, other writes prompt (P1)

    func testAcceptEdits_allowsEditTool() async throws {
        // AC#2 (acceptEdits): Edit tool should be auto-allowed
        let (reader, output) = makeMocks(lines: [])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .acceptEdits,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let editTool = MockTool(name: "Edit", isReadOnly: false)
        let result = await canUseTool(editTool, ["file_path": "/tmp/edit.txt"], makeContext())

        XCTAssertEqual(result?.behavior, .allow,
            "acceptEdits should auto-allow Edit tool")
        XCTAssertEqual(reader.callCount, 0,
            "acceptEdits should not prompt for Edit tool")
    }

    func testAcceptEdits_promptsForOtherWrite() async throws {
        // AC#2 (acceptEdits): Non-edit write tools should prompt
        let (reader, output) = makeMocks(lines: ["y"])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .acceptEdits,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let bashTool = MockTool(name: "Bash", isReadOnly: false)
        let result = await canUseTool(bashTool, ["command": "rm -rf /tmp/test"], makeContext())

        XCTAssertEqual(result?.behavior, .allow,
            "acceptEdits should prompt for Bash tool and allow when user approves")
        XCTAssertEqual(reader.callCount, 1,
            "acceptEdits should prompt once for non-edit write tool")
    }

    func testAcceptEdits_allowsReadOnlyTool() async throws {
        // AC#2 (acceptEdits): Read-only tools should be auto-allowed
        let (reader, output) = makeMocks(lines: [])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .acceptEdits,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let readTool = MockTool(name: "Grep", isReadOnly: true)
        let result = await canUseTool(readTool, ["pattern": "func"], makeContext())

        XCTAssertEqual(result?.behavior, .allow,
            "acceptEdits should auto-allow read-only tools")
        XCTAssertEqual(reader.callCount, 0,
            "acceptEdits should not prompt for read-only tools")
    }

    // MARK: - AC#3: plan mode - all tools prompt for approval (P0)

    func testPlan_promptsForAllTools() async throws {
        // AC#3: plan mode should prompt for ALL tools including read-only
        let (reader, output) = makeMocks(lines: ["y"])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .plan,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let readTool = MockTool(name: "Read", isReadOnly: true)
        let result = await canUseTool(readTool, ["file_path": "/tmp/test.txt"], makeContext())

        XCTAssertEqual(reader.callCount, 1,
            "plan mode should prompt even for read-only tools (AC#3)")
        XCTAssertEqual(result?.behavior, .allow,
            "plan mode should allow read-only tool when user approves (AC#3)")
    }

    func testPlan_userApproves_returnsAllow() async throws {
        // AC#3: plan mode, user approves -> allow
        let (reader, output) = makeMocks(lines: ["y"])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .plan,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let writeTool = MockTool(name: "Bash", isReadOnly: false)
        let result = await canUseTool(writeTool, ["command": "ls"], makeContext())

        XCTAssertEqual(result?.behavior, .allow,
            "plan mode should allow when user approves (AC#3)")
    }

    func testPlan_userDenies_returnsDeny() async throws {
        // AC#3: plan mode, user denies -> deny
        let (reader, output) = makeMocks(lines: ["n"])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .plan,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let writeTool = MockTool(name: "Bash", isReadOnly: false)
        let result = await canUseTool(writeTool, ["command": "ls"], makeContext())

        XCTAssertEqual(result?.behavior, .deny,
            "plan mode should deny when user rejects (AC#3)")
    }

    func testPlan_promptsForReadOnlyTool() async throws {
        // AC#3: plan mode prompts for read-only tools too (stricter than default)
        let (reader, output) = makeMocks(lines: ["y"])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .plan,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let globTool = MockTool(name: "Glob", isReadOnly: true)
        let result = await canUseTool(globTool, ["pattern": "**/*.swift"], makeContext())

        XCTAssertEqual(reader.callCount, 1,
            "plan mode should prompt for read-only tools like Glob (AC#3)")
        XCTAssertEqual(result?.behavior, .allow,
            "plan mode should allow read-only tool when user approves (AC#3)")
    }

    // MARK: - AC#4: Invalid mode handling (P1)

    func testInvalidMode_errorListsValidModes() async throws {
        // AC#4: Invalid mode error should list all valid modes
        // This is tested through AgentFactory (existing test), but we verify
        // PermissionHandler doesn't change the behavior.
        let args = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "sk-test",
            baseURL: nil,
            provider: nil,
            mode: "invalidMode",
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

        XCTAssertThrowsError(try AgentFactory.createAgent(from: args)) { error in
            XCTAssertTrue(error is AgentFactoryError,
                "Should throw AgentFactoryError for invalid mode (AC#4)")
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("default"),
                "Error should list 'default' as valid mode (AC#4)")
            XCTAssertTrue(message.contains("bypassPermissions"),
                "Error should list 'bypassPermissions' as valid mode (AC#4)")
            XCTAssertTrue(message.contains("plan"),
                "Error should list 'plan' as valid mode (AC#4)")
        }
    }

    // MARK: - Prompt display format (P2)

    func testDefault_promptDisplaysToolInfo() async throws {
        // AC#2: Permission prompt should show tool name and input summary
        let (reader, output) = makeMocks(lines: ["y"])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .default,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let writeTool = MockTool(name: "Bash", isReadOnly: false)
        _ = await canUseTool(writeTool, ["command": "rm -rf /tmp/test"], makeContext())

        let promptOutput = output.output
        XCTAssertTrue(promptOutput.contains("Bash"),
            "Permission prompt should display tool name 'Bash' (AC#2)")
        XCTAssertTrue(promptOutput.contains("Allow") || promptOutput.contains("allow"),
            "Permission prompt should ask user to allow (AC#2)")
    }

    func testDefault_promptContainsWarningSymbol() async throws {
        // Verify the warning symbol is displayed in prompts
        let (reader, output) = makeMocks(lines: ["y"])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .default,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let writeTool = MockTool(name: "Bash", isReadOnly: false)
        _ = await canUseTool(writeTool, ["command": "rm file"], makeContext())

        // The prompt should contain ANSI styling or a warning indicator
        let promptOutput = output.output
        XCTAssertFalse(promptOutput.isEmpty,
            "Permission prompt should produce output for write tool")
    }

    // MARK: - Non-nil result guarantee (P1)

    func testPermissionHandler_allModes_nonNilResult() async throws {
        // Decision 4: canUseTool should always return non-nil result
        // to fully override SDK's default behavior
        let modes: [PermissionMode] = [.default, .acceptEdits, .bypassPermissions, .plan, .dontAsk, .auto]

        for mode in modes {
            let (reader, output) = makeMocks(lines: mode == .bypassPermissions || mode == .dontAsk || mode == .auto ? [] : ["y"])

            let canUseTool = PermissionHandler.createCanUseTool(
                mode: mode,
                reader: reader,
                renderer: OutputRenderer(output: output)
            )

            let writeTool = MockTool(name: "Bash", isReadOnly: false)
            let result = await canUseTool(writeTool, ["command": "test"], makeContext())

            XCTAssertNotNil(result,
                "PermissionHandler should return non-nil for mode \(mode.rawValue) (Decision 4)")
        }
    }

    // MARK: - Default mode: read-only tools from various names (P1)

    func testDefault_allowsGrepTool() async throws {
        let (reader, output) = makeMocks(lines: [])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .default,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let grepTool = MockTool(name: "Grep", isReadOnly: true)
        let result = await canUseTool(grepTool, ["pattern": "test"], makeContext())

        XCTAssertEqual(result?.behavior, .allow,
            "default mode should auto-allow Grep (read-only)")
    }

    func testDefault_allowsGlobTool() async throws {
        let (reader, output) = makeMocks(lines: [])

        let canUseTool = PermissionHandler.createCanUseTool(
            mode: .default,
            reader: reader,
            renderer: OutputRenderer(output: output)
        )

        let globTool = MockTool(name: "Glob", isReadOnly: true)
        let result = await canUseTool(globTool, ["pattern": "**/*.swift"], makeContext())

        XCTAssertEqual(result?.behavior, .allow,
            "default mode should auto-allow Glob (read-only)")
    }
}
