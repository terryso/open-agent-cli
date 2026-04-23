import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 9.4 Tab Completion
//
// These tests define the EXPECTED behavior of TabCompletionProvider and
// the LinenoiseInputReader completion callback integration. They will FAIL until:
//   1. TabCompletionProvider.swift is created implementing the completion logic
//   2. LinenoiseInputReader.swift adds setCompletionCallback method
//
// Acceptance Criteria Coverage:
//   AC#1: Unique prefix match auto-completes (e.g., /mod → /mode)
//   AC#2: Bare "/" lists all 13 slash commands
//   AC#3: /mcp <prefix> completes MCP subcommands (status, reconnect)
//   AC#4: /mode <prefix> completes PermissionMode values
//   AC#5: Non-/ input returns no completions
//   AC#6: Multiple prefix matches listed (/s → /sessions, /skills)

final class TabCompletionTests: XCTestCase {

    // MARK: - System Under Test

    /// TabCompletionProvider is a pure-logic struct with no state.
    /// Create a fresh instance for each test.
    private var provider: TabCompletionProvider!

    override func setUp() {
        super.setUp()
        provider = TabCompletionProvider()
    }

    override func tearDown() {
        provider = nil
        super.tearDown()
    }

    // MARK: - AC#1: Unique prefix match auto-completes

    func testCompletions_inputM_returnsModeAndModel() {
        // AC#1: Input "/m" matches /mode, /model, and /mcp
        let results = provider.completions(for: "/m")
        XCTAssertTrue(results.contains("/mode"),
                       "Expected /mode in results for '/m'")
        XCTAssertTrue(results.contains("/model"),
                       "Expected /model in results for '/m'")
        XCTAssertTrue(results.contains("/mcp"),
                       "Expected /mcp in results for '/m'")
        XCTAssertEqual(results.count, 3, "'/m' should match exactly 3 commands")
    }

    func testCompletions_inputMo_returnsModeAndModel() {
        // AC#1: Input "/mo" matches both /mode and /model
        let results = provider.completions(for: "/mo")
        XCTAssertTrue(results.contains("/mode"),
                       "Expected /mode in results for '/mo'")
        XCTAssertTrue(results.contains("/model"),
                       "Expected /model in results for '/mo'")
        XCTAssertEqual(results.count, 2, "'/mo' should match exactly 2 commands")
    }

    func testCompletions_inputMod_returnsModeAndModel() {
        // AC#1: Input "/mod" matches both /mode and /model
        let results = provider.completions(for: "/mod")
        XCTAssertTrue(results.contains("/mode"),
                       "Expected /mode in results for '/mod'")
        XCTAssertTrue(results.contains("/model"),
                       "Expected /model in results for '/mod'")
        XCTAssertEqual(results.count, 2, "'/mod' should match exactly 2 commands")
    }

    // MARK: - AC#2: Bare "/" lists all commands

    func testCompletions_bareSlash_returnsAllCommands() {
        // AC#2: Input "/" returns all 13 slash commands
        let results = provider.completions(for: "/")
        let expectedCommands: [String] = [
            "/help", "/exit", "/quit", "/tools", "/skills",
            "/model", "/mode", "/cost", "/clear",
            "/sessions", "/resume", "/fork", "/mcp"
        ]
        XCTAssertEqual(results.count, 13,
                       "'/' should return all 13 commands, got \(results)")
        for cmd in expectedCommands {
            XCTAssertTrue(results.contains(cmd),
                          "'/' results should contain \(cmd)")
        }
    }

    // MARK: - AC#3: MCP subcommand completion

    func testCompletions_mcpSpace_returnsMcpSubcommands() {
        // AC#3: Input "/mcp " lists MCP subcommands
        let results = provider.completions(for: "/mcp ")
        XCTAssertTrue(results.contains("status"),
                       "Expected 'status' in /mcp subcommands")
        XCTAssertTrue(results.contains("reconnect"),
                       "Expected 'reconnect' in /mcp subcommands")
        XCTAssertEqual(results.count, 2, "/mcp should have exactly 2 subcommands")
    }

    func testCompletions_mcpSpaceS_returnsStatus() {
        // AC#3: Input "/mcp s" matches "status"
        let results = provider.completions(for: "/mcp s")
        XCTAssertEqual(results, ["status"],
                       "'/mcp s' should match 'status' only")
    }

    func testCompletions_mcpSpaceR_returnsReconnect() {
        // AC#3: Input "/mcp r" matches "reconnect"
        let results = provider.completions(for: "/mcp r")
        XCTAssertEqual(results, ["reconnect"],
                       "'/mcp r' should match 'reconnect' only")
    }

    func testCompletions_mcpSpaceUnknown_returnsEmpty() {
        // AC#3 edge: unknown MCP subcommand prefix returns empty
        let results = provider.completions(for: "/mcp z")
        XCTAssertEqual(results, [],
                       "'/mcp z' should return no subcommands")
    }

    // MARK: - AC#4: Mode subcommand completion

    func testCompletions_modeSpace_returnsAllPermissionModes() {
        // AC#4: Input "/mode " lists all valid PermissionMode values
        let results = provider.completions(for: "/mode ")
        let expectedModes = PermissionMode.allCases.map(\.rawValue)
        XCTAssertEqual(results.sorted(), expectedModes.sorted(),
                       "'/mode ' should return all PermissionMode rawValues")
    }

    func testCompletions_modeSpacePl_returnsPlan() {
        // AC#4: Input "/mode pl" matches "plan"
        let results = provider.completions(for: "/mode pl")
        XCTAssertEqual(results, ["plan"],
                       "'/mode pl' should match 'plan' only")
    }

    func testCompletions_modeSpaceD_returnsDefaultAndDontAsk() {
        // AC#4: Input "/mode d" matches "default" and "dontAsk"
        let results = provider.completions(for: "/mode d")
        XCTAssertTrue(results.contains("default"),
                       "'/mode d' should contain 'default'")
        XCTAssertTrue(results.contains("dontAsk"),
                       "'/mode d' should contain 'dontAsk'")
    }

    func testCompletions_modeSpaceAuto_returnsAuto() {
        // AC#4: Input "/mode a" matches "auto" and "acceptEdits"
        let results = provider.completions(for: "/mode a")
        XCTAssertTrue(results.contains("auto"),
                       "'/mode a' should contain 'auto'")
        XCTAssertTrue(results.contains("acceptEdits"),
                       "'/mode a' should contain 'acceptEdits'")
    }

    func testCompletions_modeSpaceUnknown_returnsEmpty() {
        // AC#4 edge: unknown mode prefix returns empty
        let results = provider.completions(for: "/mode xyz")
        XCTAssertEqual(results, [],
                       "'/mode xyz' should return no modes")
    }

    // MARK: - AC#5: Non-/ input returns no completions

    func testCompletions_plainText_returnsEmpty() {
        // AC#5: Input without / prefix returns empty
        let results = provider.completions(for: "hello")
        XCTAssertEqual(results, [],
                       "Non-/ input 'hello' should return no completions")
    }

    func testCompletions_emptyString_returnsEmpty() {
        // AC#5: Empty string returns empty
        let results = provider.completions(for: "")
        XCTAssertEqual(results, [],
                       "Empty input should return no completions")
    }

    func testCompletions_whitespaceOnly_returnsEmpty() {
        // AC#5: Whitespace-only input returns empty
        let results = provider.completions(for: "   ")
        XCTAssertEqual(results, [],
                       "Whitespace input should return no completions")
    }

    func testCompletions_commandWithoutSlash_returnsEmpty() {
        // AC#5: "help" (without /) returns empty
        let results = provider.completions(for: "help")
        XCTAssertEqual(results, [],
                       "'help' without / should return no completions")
    }

    // MARK: - AC#6: Multiple prefix matches

    func testCompletions_inputS_returnsSessionsAndSkills() {
        // AC#6: Input "/s" matches /sessions and /skills
        let results = provider.completions(for: "/s")
        XCTAssertTrue(results.contains("/sessions"),
                       "'/s' should contain /sessions")
        XCTAssertTrue(results.contains("/skills"),
                       "'/s' should contain /skills")
        // Input should remain "/s" — linenoise handles display
        // Our job is just to return the matching candidates
    }

    func testCompletions_inputC_returnsCostAndClear() {
        // AC#6 variant: Input "/c" matches /cost and /clear
        let results = provider.completions(for: "/c")
        XCTAssertTrue(results.contains("/cost"),
                       "'/c' should contain /cost")
        XCTAssertTrue(results.contains("/clear"),
                       "'/c' should contain /clear")
    }

    // MARK: - Edge cases

    func testCompletions_exactMatch_returnsSingleMatch() {
        // Exact match "/help" returns ["/help"]
        let results = provider.completions(for: "/help")
        XCTAssertEqual(results, ["/help"],
                       "'/help' exact match should return [\"/help\"]")
    }

    func testCompletions_modelSpace_returnsEmpty() {
        // /model has no subcommands — returns empty
        let results = provider.completions(for: "/model ")
        XCTAssertEqual(results, [],
                       "'/model ' should return no subcommands")
    }

    func testCompletions_inputMc_returnsMcp() {
        // Input "/mc" matches "/mcp"
        let results = provider.completions(for: "/mc")
        XCTAssertEqual(results, ["/mcp"],
                       "'/mc' should match /mcp only")
    }

    func testCompletions_unknownCommandPrefix_returnsEmpty() {
        // Input "/xyz" matches nothing
        let results = provider.completions(for: "/xyz")
        XCTAssertEqual(results, [],
                       "'/xyz' should return no matches")
    }

    func testCompletions_caseInsensitive_uppercaseInput() {
        // Input "/M" should match /mode and /model (case-insensitive)
        let results = provider.completions(for: "/M")
        XCTAssertTrue(results.contains("/mode"),
                       "'/M' (uppercase) should match /mode")
        XCTAssertTrue(results.contains("/model"),
                       "'/M' (uppercase) should match /model")
    }

    func testCompletions_caseInsensitive_mixedCaseInput() {
        // Input "/HeL" should match /help (case-insensitive)
        let results = provider.completions(for: "/HeL")
        XCTAssertTrue(results.contains("/help"),
                       "'/HeL' (mixed case) should match /help")
    }

    // MARK: - LinenoiseInputReader.setCompletionCallback integration

    func testLinenoiseInputReader_hasSetCompletionCallbackMethod() {
        // Verify that LinenoiseInputReader exposes setCompletionCallback
        let tempDir = NSTemporaryDirectory()
            + "tab-completion-tests-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(
            atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let reader = LinenoiseInputReader(historyPath: tempDir + "/history")

        // This test verifies the method exists and is callable.
        // If it doesn't exist, compilation fails (RED phase).
        reader.setCompletionCallback { _ in
            return []
        }

        // We cannot simulate a Tab keypress in unit tests (linenoise requires a TTY),
        // but the callback registration itself should not crash.
        // The actual Tab-triggered invocation is verified via E2E/integration tests.
    }

    func testTabCompletionProvider_isIndependentStruct() {
        // Verify TabCompletionProvider is a value type (struct),
        // confirming it's a pure-logic component with no shared mutable state.
        let provider1 = TabCompletionProvider()
        let provider2 = TabCompletionProvider()

        // Both instances should produce identical results
        XCTAssertEqual(provider1.completions(for: "/m"),
                       provider2.completions(for: "/m"),
                       "Two TabCompletionProvider instances should produce identical results")
    }
}
