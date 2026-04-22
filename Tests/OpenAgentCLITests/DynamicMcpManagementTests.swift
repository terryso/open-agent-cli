import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 7.6 Dynamic MCP Management
//
// These tests define the EXPECTED behavior of the /mcp command group:
//   /mcp status            -- show MCP server connection status
//   /mcp reconnect <name>  -- reconnect a disconnected MCP server
//
// They will FAIL until REPLLoop.swift is updated with /mcp handling (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: /mcp status displays connected server status (requires real MCP -- smoke test)
//   AC#2: /mcp reconnect <name> reconnects a server (requires real MCP -- smoke test)
//   AC#3: /mcp reconnect nonexistent shows "Server not found"
//   AC#4: /mcp status with no servers shows "No MCP servers configured."
//   AC#5: /mcp with no/invalid subcommand shows help
//   AC#6: /mcp reconnect with no arg shows usage hint
//
// All tests use MockInputReader + MockTextOutputStream to exercise
// REPLLoop.start() in-process. Output is captured and assertions
// verify the correct user-facing messages are produced.
//
// Test strategy: Tests use a real Agent with no MCP servers configured.
// - agent.mcpServerStatus() returns empty dictionary [:]
// - agent.reconnectMcpServer(name:) throws MCPClientManagerError.serverNotFound

final class DynamicMcpManagementTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a MockTextOutputStream and OutputRenderer pair for capturing output.
    private func makeRenderer() -> (renderer: OutputRenderer, mock: MockTextOutputStream) {
        let mock = MockTextOutputStream()
        let renderer = OutputRenderer(output: mock)
        return (renderer, mock)
    }

    /// Creates a test Agent with dummy configuration and no MCP servers.
    ///
    /// Without MCP config, the agent's mcpClientManager is nil, which means:
    /// - mcpServerStatus() returns [:] (empty dictionary)
    /// - reconnectMcpServer(name:) throws MCPClientManagerError.serverNotFound
    private func makeTestAgent() async throws -> Agent {
        let args = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-mcp-tests",
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
            debug: false,
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
    // MARK: AC#4 — /mcp status with no servers shows "No MCP servers configured."
    // ================================================================

    /// AC#4: /mcp status with no MCP servers configured shows the "no servers" message.
    ///
    /// Given no MCP servers are configured
    /// When the user enters "/mcp status"
    /// Then the output contains "No MCP servers configured."
    func testMcpStatus_noServers_showsNoConfigured() async throws {
        // Given: A REPL session with no MCP servers
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/mcp status", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        // When: User enters /mcp status
        await repl.start()

        // Then: Output should contain the "no servers" message
        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("no mcp servers configured"),
            "/mcp status with no servers should show 'No MCP servers configured.' (AC#4). Got: \(mockOutput.output)")
    }

    // ================================================================
    // MARK: AC#3 — /mcp reconnect nonexistent shows "Server not found"
    // ================================================================

    /// AC#3: /mcp reconnect with a nonexistent server name shows "Server not found".
    ///
    /// Given no MCP servers are configured (or the name doesn't exist)
    /// When the user enters "/mcp reconnect nonexistent"
    /// Then the output contains "Server not found"
    func testMcpReconnect_nonexistent_showsNotFound() async throws {
        // Given: A REPL session with no MCP servers
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/mcp reconnect nonexistent", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        // When: User enters /mcp reconnect with a name that doesn't exist
        await repl.start()

        // Then: Output should contain "Server not found" error
        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("server not found"),
            "/mcp reconnect nonexistent should show 'Server not found' (AC#3). Got: \(mockOutput.output)")
    }

    // ================================================================
    // MARK: AC#6 — /mcp reconnect with no arg shows usage
    // ================================================================

    /// AC#6: /mcp reconnect without a server name shows usage hint.
    ///
    /// Given the user is in a REPL session
    /// When they type "/mcp reconnect" with no server name
    /// Then a usage message "Usage: /mcp reconnect <name>" is shown
    func testMcpReconnect_noArg_showsUsage() async throws {
        // Given: A REPL session
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/mcp reconnect", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        // When: User enters /mcp reconnect with no server name
        await repl.start()

        // Then: Output should contain "usage" or a specific usage hint (not just "Unknown command")
        // The expected output is "Usage: /mcp reconnect <name>"
        let output = mockOutput.output.lowercased()
        let hasUsage = output.contains("usage: /mcp reconnect") || output.contains("usage")
        let isNotUnknownCommand = !output.contains("unknown command")
        XCTAssertTrue(hasUsage && isNotUnknownCommand,
            "/mcp reconnect with no arg should show usage hint, not 'Unknown command' (AC#6). Got: \(mockOutput.output)")
    }

    // ================================================================
    // MARK: AC#5 — /mcp with no subcommand shows help
    // ================================================================

    /// AC#5: /mcp with no subcommand shows help listing available subcommands.
    ///
    /// Given the user is in a REPL session
    /// When they type "/mcp" with no subcommand
    /// Then a help message listing /mcp subcommands is shown
    func testMcp_noSubcommand_showsHelp() async throws {
        // Given: A REPL session
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/mcp", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        // When: User enters /mcp with no subcommand
        await repl.start()

        // Then: Output should show MCP help with available subcommands
        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("status") && output.contains("reconnect"),
            "/mcp with no subcommand should show help listing 'status' and 'reconnect' (AC#5). Got: \(mockOutput.output)")
    }

    // ================================================================
    // MARK: AC#5 — /mcp with unknown subcommand shows help
    // ================================================================

    /// AC#5: /mcp with an unknown subcommand shows help listing available subcommands.
    ///
    /// Given the user is in a REPL session
    /// When they type "/mcp unknown"
    /// Then a help message listing /mcp subcommands is shown
    func testMcp_unknownSubcommand_showsHelp() async throws {
        // Given: A REPL session
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/mcp unknown", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        // When: User enters /mcp with an unknown subcommand
        await repl.start()

        // Then: Output should show MCP help with available subcommands
        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("status") && output.contains("reconnect"),
            "/mcp with unknown subcommand should show help listing 'status' and 'reconnect' (AC#5). Got: \(mockOutput.output)")
    }

    // ================================================================
    // MARK: /help includes /mcp commands (AC#1, #2 discoverability)
    // ================================================================

    /// /help output should include /mcp status and /mcp reconnect commands.
    func testHelp_includesMcpCommands() async throws {
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/help", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("/mcp") || output.contains("mcp"),
            "/help should list /mcp command. Got: \(mockOutput.output)")
        XCTAssertTrue(output.contains("status"),
            "/help should mention /mcp status. Got: \(mockOutput.output)")
    }

    // ================================================================
    // MARK: /mcp does not exit REPL (non-destructive)
    // ================================================================

    /// /mcp commands should not exit the REPL.
    func testMcp_doesNotExit() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/mcp status", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 2,
            "/mcp status should not exit REPL -- /exit should be read as second input")
    }

    // ================================================================
    // MARK: Regression — existing commands still work
    // ================================================================

    /// Ensure /exit still works after adding /mcp commands.
    func testRegression_exitCommandStillWorks() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 1,
            "/exit should still exit after adding /mcp commands")
    }

    /// Ensure /help still works after adding /mcp commands.
    func testRegression_helpCommandStillWorks() async throws {
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/help", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        let output = mockOutput.output
        XCTAssertTrue(output.contains("/exit"),
            "/help should still list /exit. Got: \(output)")
        XCTAssertTrue(output.contains("/quit"),
            "/help should still list /quit. Got: \(output)")
    }
}
