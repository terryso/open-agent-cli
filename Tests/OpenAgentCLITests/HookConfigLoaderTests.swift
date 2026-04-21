import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 6.1 Hook System Integration
//
// These tests define the EXPECTED behavior of HookConfigLoader.loadHooksConfig(from:)
// and its integration with AgentFactory. They will FAIL to compile until
// HookConfigLoader.swift is implemented (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: Hooks config JSON -> hooks registered via createHookRegistry()
//   AC#2: preToolUse hook -> hook script executes before tool runs
//   AC#3: Hook timeout/error -> warning logged, agent operation continues

final class HookConfigLoaderTests: XCTestCase {

    // MARK: - Helper: Write temp JSON file

    private func writeTempJSON(_ content: String, suffix: String = "") throws -> String {
        let dir = NSTemporaryDirectory()
        let path = dir + "hooks_test_\(UUID().uuidString)\(suffix).json"
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    // MARK: - Helper: Build ParsedArgs with common defaults

    private func makeArgs(
        apiKey: String? = "test-api-key",
        hooksConfigPath: String? = nil
    ) -> ParsedArgs {
        ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: apiKey,
            baseURL: "https://api.example.com/v1",
            provider: nil,
            mode: "default",
            tools: "core",
            mcpConfigPath: nil,
            hooksConfigPath: hooksConfigPath,
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
    }

    // MARK: - AC#1: Valid hooks config JSON -> parses correctly

    /// AC#1: A valid hooks config file with preToolUse should parse into
    /// the correct [String: [HookDefinition]] mapping.
    func testLoadHooks_validConfig() throws {
        let json = """
        {
          "hooks": {
            "preToolUse": [
              {
                "command": "echo 'Before tool'"
              }
            ]
          }
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try HookConfigLoader.loadHooksConfig(from: path)

        XCTAssertEqual(result.count, 1, "Should parse exactly one event type")
        let hooks = result["preToolUse"]
        XCTAssertNotNil(hooks, "Should find 'preToolUse' event entry")
        XCTAssertEqual(hooks?.count, 1, "preToolUse should have exactly one hook")

        // Verify the hook command is set
        // Note: HookDefinition.command is the shell command string
        // We verify the entry exists and has the expected structure
        XCTAssertEqual(hooks?.count, 1)
    }

    /// AC#1: A valid hooks config with all optional fields (matcher, timeout)
    /// should parse correctly and pass them through.
    func testLoadHooks_withMatcherAndTimeout() throws {
        let json = """
        {
          "hooks": {
            "preToolUse": [
              {
                "command": "/path/to/script.sh",
                "matcher": "Bash",
                "timeout": 5000
              }
            ]
          }
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try HookConfigLoader.loadHooksConfig(from: path)

        XCTAssertEqual(result.count, 1)
        let hooks = result["preToolUse"]
        XCTAssertNotNil(hooks)
        XCTAssertEqual(hooks?.count, 1)
        // The hook definition should have been created with command, matcher, and timeout
    }

    /// AC#1: Empty hooks object should return empty dictionary (not an error).
    func testLoadHooks_emptyHooks() throws {
        let json = """
        {
          "hooks": {}
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try HookConfigLoader.loadHooksConfig(from: path)

        XCTAssertTrue(result.isEmpty,
            "Empty hooks object should return empty dictionary")
    }

    // MARK: - AC#2: Multiple event types parsed correctly

    /// AC#2: Multiple event types should all be parsed correctly.
    func testLoadHooks_multipleEvents() throws {
        let json = """
        {
          "hooks": {
            "preToolUse": [
              {
                "command": "echo 'Before tool'"
              }
            ],
            "postToolUse": [
              {
                "command": "echo 'After tool'"
              }
            ],
            "sessionStart": [
              {
                "command": "logger 'session started'"
              }
            ]
          }
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try HookConfigLoader.loadHooksConfig(from: path)

        XCTAssertEqual(result.count, 3, "Should parse all three event types")
        XCTAssertNotNil(result["preToolUse"])
        XCTAssertNotNil(result["postToolUse"])
        XCTAssertNotNil(result["sessionStart"])
    }

    /// AC#2: Multiple hooks for a single event should all be parsed.
    func testLoadHooks_multipleHooksPerEvent() throws {
        let json = """
        {
          "hooks": {
            "preToolUse": [
              { "command": "echo 'first'" },
              { "command": "echo 'second'", "matcher": "Bash" }
            ]
          }
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try HookConfigLoader.loadHooksConfig(from: path)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result["preToolUse"]?.count, 2,
            "preToolUse should have two hooks")
    }

    // MARK: - AC#1: Error cases

    /// AC#1: A nonexistent hooks config file should throw fileNotFound error.
    func testLoadHooks_fileNotFound() throws {
        let nonexistentPath = "/tmp/nonexistent_hooks_\(UUID().uuidString).json"

        XCTAssertThrowsError(try HookConfigLoader.loadHooksConfig(from: nonexistentPath)) { error in
            let message = error.localizedDescription.lowercased()
            XCTAssertTrue(message.contains("not found") || message.contains("hooks config") || message.contains("file"),
                "Error message should mention 'not found' or 'file': \(message)")
        }
    }

    /// AC#1: Invalid JSON should throw invalidJSON error.
    func testLoadHooks_invalidJSON() throws {
        let json = "this is not valid json {{{"
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertThrowsError(try HookConfigLoader.loadHooksConfig(from: path)) { error in
            let message = error.localizedDescription
            XCTAssertTrue(message.count > 0,
                "Error message should be non-empty for invalid JSON: \(message)")
        }
    }

    /// AC#1: Missing "hooks" top-level key should throw an error.
    func testLoadHooks_missingHooksKey() throws {
        let json = """
        {
          "notHooks": {
            "preToolUse": [
              { "command": "echo 'test'" }
            ]
          }
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertThrowsError(try HookConfigLoader.loadHooksConfig(from: path)) { error in
            let message = error.localizedDescription.lowercased()
            XCTAssertTrue(
                message.contains("hooks") || message.contains("missing") || message.contains("required"),
                "Error should indicate missing hooks key: \(message)")
        }
    }

    /// AC#1: A hook entry missing the "command" field should throw missingCommand error.
    func testLoadHooks_missingCommand() throws {
        let json = """
        {
          "hooks": {
            "preToolUse": [
              {
                "matcher": "Bash",
                "timeout": 5000
              }
            ]
          }
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertThrowsError(try HookConfigLoader.loadHooksConfig(from: path)) { error in
            let message = error.localizedDescription.lowercased()
            XCTAssertTrue(
                message.contains("command") || message.contains("required") || message.contains("missing"),
                "Error should indicate missing command: \(message)")
        }
    }

    /// AC#1: A hook entry with empty command string should throw emptyCommand error.
    func testLoadHooks_emptyCommand() throws {
        let json = """
        {
          "hooks": {
            "preToolUse": [
              {
                "command": ""
              }
            ]
          }
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertThrowsError(try HookConfigLoader.loadHooksConfig(from: path)) { error in
            let message = error.localizedDescription.lowercased()
            XCTAssertTrue(
                message.contains("command") || message.contains("empty"),
                "Error should indicate empty command: \(message)")
        }
    }

    // MARK: - AC#3: Resilience (timeout/error behavior tested via integration)

    /// AC#3: A valid config that would cause a timeout at runtime should still
    /// load successfully (timeouts are enforced at execution time, not load time).
    func testLoadHooks_shortTimeout_stillLoads() throws {
        let json = """
        {
          "hooks": {
            "preToolUse": [
              {
                "command": "sleep 999",
                "timeout": 1
              }
            ]
          }
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        // Should load without error -- timeout enforcement happens at execution time
        let result = try HookConfigLoader.loadHooksConfig(from: path)
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - AC#1: Valid event names

    /// AC#1: All 22 valid HookEvent rawValues should be accepted as event names.
    func testLoadHooks_allValidEventNames() throws {
        // Build a JSON with all 22 valid event names from HookEvent enum
        let eventNames = HookEvent.allCases.map(\.rawValue)
        var hooksDict = ""
        for (index, name) in eventNames.enumerated() {
            let comma = index < eventNames.count - 1 ? "," : ""
            hooksDict += """
                "\(name)": [{ "command": "echo '\(name)'" }]\(comma)

            """
        }

        let json = """
        {
          "hooks": {
            \(hooksDict)
          }
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try HookConfigLoader.loadHooksConfig(from: path)

        XCTAssertEqual(result.count, eventNames.count,
            "All \(eventNames.count) valid event names should be parsed")
        for name in eventNames {
            XCTAssertNotNil(result[name], "Event '\(name)' should be present in result")
        }
    }

    /// AC#1: Invalid event names should be skipped silently — valid hooks must
    /// still load without being blocked by invalid entries.
    func testLoadHooks_invalidEventName_skippedGracefully() throws {
        let json = """
        {
          "hooks": {
            "preToolUse": [
              { "command": "echo 'valid'" }
            ],
            "nonExistentEvent": [
              { "command": "echo 'invalid'" }
            ]
          }
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try HookConfigLoader.loadHooksConfig(from: path)

        XCTAssertEqual(result.count, 1, "Only valid events should be in the result")
        XCTAssertNotNil(result["preToolUse"],
            "Valid events should still be present even when invalid events exist")
        XCTAssertNil(result["nonExistentEvent"],
            "Invalid event names should be skipped")
    }
}
