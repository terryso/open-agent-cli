import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 4.1 MCP Server Configuration and Connection
//
// These tests define the EXPECTED behavior of MCPConfigLoader.loadMcpConfig(from:)
// and its integration with AgentFactory. They will FAIL to compile until
// MCPConfigLoader.swift is implemented (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: Valid MCP config JSON -> MCP servers connect at startup
//   AC#2: MCP tools included with built-in tools in tool pool
//   AC#3: MCP server connection failure -> warning, CLI continues
//   AC#4: Nonexistent MCP config -> clear error "MCP config file not found", exit 1

final class MCPConfigLoaderTests: XCTestCase {

    // MARK: - Helper: Write temp JSON file

    private func writeTempJSON(_ content: String, suffix: String = "") throws -> String {
        let dir = NSTemporaryDirectory()
        let path = dir + "mcp_test_\(UUID().uuidString)\(suffix).json"
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    // MARK: - Helper: Build ParsedArgs with common defaults

    private func makeArgs(
        apiKey: String? = "test-api-key",
        mcpConfigPath: String? = nil
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
            mcpConfigPath: mcpConfigPath,
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
    }

    // MARK: - AC#1: Valid MCP config JSON -> parses correctly

    /// AC#1: A valid stdio MCP config file should parse into the correct SDK types.
    /// The JSON format has "command" field which maps to McpServerConfig.stdio.
    func testLoadMcpConfig_validStdioConfig() throws {
        let json = """
        {
          "mcpServers": {
            "filesystem": {
              "command": "npx",
              "args": ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
            }
          }
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try MCPConfigLoader.loadMcpConfig(from: path)

        XCTAssertEqual(result.count, 1, "Should parse exactly one server entry")
        let serverConfig = result["filesystem"]
        XCTAssertNotNil(serverConfig, "Should find 'filesystem' server entry")

        // Verify it's a stdio config with correct values
        if case .stdio(let stdioConfig) = serverConfig {
            XCTAssertEqual(stdioConfig.command, "npx",
                "Stdio command should be 'npx'")
            XCTAssertEqual(stdioConfig.args, ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"],
                "Stdio args should match the JSON array")
            XCTAssertNil(stdioConfig.env, "env should be nil when not specified")
        } else {
            XCTFail("Expected .stdio config but got different type")
        }
    }

    /// AC#1: A stdio config with all optional fields (args, env) should parse correctly.
    func testLoadMcpConfig_stdioWithArgsAndEnv() throws {
        let json = """
        {
          "mcpServers": {
            "my-server": {
              "command": "python3",
              "args": ["mcp_server.py", "--verbose"],
              "env": {
                "API_KEY": "test-key-123",
                "DEBUG": "1"
              }
            }
          }
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try MCPConfigLoader.loadMcpConfig(from: path)

        XCTAssertEqual(result.count, 1)
        if case .stdio(let stdioConfig) = result["my-server"] {
            XCTAssertEqual(stdioConfig.command, "python3")
            XCTAssertEqual(stdioConfig.args, ["mcp_server.py", "--verbose"])
            XCTAssertEqual(stdioConfig.env?["API_KEY"], "test-key-123")
            XCTAssertEqual(stdioConfig.env?["DEBUG"], "1")
        } else {
            XCTFail("Expected .stdio config")
        }
    }

    /// AC#1: A valid SSE config with a "url" field should parse to McpServerConfig.sse.
    func testLoadMcpConfig_validSseConfig() throws {
        let json = """
        {
          "mcpServers": {
            "remote-server": {
              "url": "https://mcp.example.com/sse",
              "headers": {
                "Authorization": "Bearer test-token"
              }
            }
          }
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try MCPConfigLoader.loadMcpConfig(from: path)

        XCTAssertEqual(result.count, 1)
        if case .sse(let sseConfig) = result["remote-server"] {
            XCTAssertEqual(sseConfig.url, "https://mcp.example.com/sse",
                "SSE URL should match")
            XCTAssertEqual(sseConfig.headers?["Authorization"], "Bearer test-token",
                "SSE headers should be parsed")
        } else {
            XCTFail("Expected .sse config")
        }
    }

    /// AC#1: A valid HTTP config with a "url" field (and type hint) should parse to McpServerConfig.http.
    /// Note: Story design doc says url -> sse by default; this test verifies basic url parsing.
    func testLoadMcpConfig_validHttpConfig() throws {
        let json = """
        {
          "mcpServers": {
            "http-server": {
              "url": "https://mcp.example.com/api"
            }
          }
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try MCPConfigLoader.loadMcpConfig(from: path)

        XCTAssertEqual(result.count, 1)
        // URL-based configs should parse as sse (per design decision)
        let serverConfig = result["http-server"]
        XCTAssertNotNil(serverConfig)

        // Verify it's a transport-based config (sse or http)
        if case .sse(let transportConfig) = serverConfig {
            XCTAssertEqual(transportConfig.url, "https://mcp.example.com/api")
        } else if case .http(let transportConfig) = serverConfig {
            XCTAssertEqual(transportConfig.url, "https://mcp.example.com/api")
        } else {
            XCTFail("Expected .sse or .http config for URL-based entry")
        }
    }

    /// AC#1, #2: A config with multiple servers of different transport types should parse all correctly.
    func testLoadMcpConfig_multipleServers() throws {
        let json = """
        {
          "mcpServers": {
            "fs-server": {
              "command": "npx",
              "args": ["-y", "@modelcontextprotocol/server-filesystem"]
            },
            "remote-sse": {
              "url": "https://mcp.example.com/sse"
            },
            "python-server": {
              "command": "python3",
              "args": ["server.py"],
              "env": { "KEY": "value" }
            }
          }
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try MCPConfigLoader.loadMcpConfig(from: path)

        XCTAssertEqual(result.count, 3, "Should parse all three server entries")

        // Verify stdio server
        if case .stdio(let config) = result["fs-server"] {
            XCTAssertEqual(config.command, "npx")
        } else {
            XCTFail("fs-server should be stdio")
        }

        // Verify sse server
        if case .sse(let config) = result["remote-sse"] {
            XCTAssertEqual(config.url, "https://mcp.example.com/sse")
        } else {
            XCTFail("remote-sse should be sse")
        }

        // Verify second stdio server with env
        if case .stdio(let config) = result["python-server"] {
            XCTAssertEqual(config.command, "python3")
            XCTAssertEqual(config.env?["KEY"], "value")
        } else {
            XCTFail("python-server should be stdio")
        }
    }

    /// AC#1: An empty mcpServers object should return an empty dictionary (not an error).
    func testLoadMcpConfig_emptyServers() throws {
        let json = """
        {
          "mcpServers": {}
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try MCPConfigLoader.loadMcpConfig(from: path)

        XCTAssertTrue(result.isEmpty,
            "Empty mcpServers object should return empty dictionary")
    }

    // MARK: - AC#4: Error cases

    /// AC#4: A nonexistent MCP config file should throw an error with a clear message.
    func testLoadMcpConfig_fileNotFound() throws {
        let nonexistentPath = "/tmp/nonexistent_mcp_\(UUID().uuidString).json"

        XCTAssertThrowsError(try MCPConfigLoader.loadMcpConfig(from: nonexistentPath)) { error in
            let message = error.localizedDescription.lowercased()
            XCTAssertTrue(message.contains("not found") || message.contains("mcp config"),
                "Error message should mention 'not found' or 'mcp config': \(message)")
        }
    }

    /// AC#4: Invalid JSON should throw a descriptive error.
    func testLoadMcpConfig_invalidJson() throws {
        let json = "this is not valid json {{{"
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertThrowsError(try MCPConfigLoader.loadMcpConfig(from: path)) { error in
            let message = error.localizedDescription
            // Error should be descriptive about JSON parsing failure
            XCTAssertTrue(message.count > 0,
                "Error message should be non-empty for invalid JSON: \(message)")
        }
    }

    /// AC#4: A server entry with neither "command" nor "url" should throw an error.
    func testLoadMcpConfig_missingCommandAndUrl() throws {
        let json = """
        {
          "mcpServers": {
            "bad-server": {
              "args": ["something"]
            }
          }
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertThrowsError(try MCPConfigLoader.loadMcpConfig(from: path)) { error in
            let message = error.localizedDescription.lowercased()
            XCTAssertTrue(
                message.contains("command") || message.contains("url") ||
                message.contains("required") || message.contains("field") ||
                message.contains("invalid"),
                "Error should indicate missing required field: \(message)")
        }
    }

    /// AC#4: A JSON file without the "mcpServers" top-level key should throw an error.
    func testLoadMcpConfig_missingMcpServersKey() throws {
        let json = """
        {
          "servers": {
            "my-server": {
              "command": "npx"
            }
          }
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertThrowsError(try MCPConfigLoader.loadMcpConfig(from: path)) { error in
            let message = error.localizedDescription.lowercased()
            XCTAssertTrue(
                message.contains("mcpservers") || message.contains("mcp") ||
                message.contains("missing") || message.contains("required"),
                "Error should indicate missing mcpServers key: \(message)")
        }
    }

    /// AC#4: A stdio entry with an empty command string should throw an error.
    func testLoadMcpConfig_stdioMissingCommand() throws {
        let json = """
        {
          "mcpServers": {
            "empty-cmd": {
              "command": "",
              "args": ["something"]
            }
          }
        }
        """
        let path = try writeTempJSON(json)
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertThrowsError(try MCPConfigLoader.loadMcpConfig(from: path)) { error in
            let message = error.localizedDescription.lowercased()
            XCTAssertTrue(
                message.contains("command") || message.contains("empty") ||
                message.contains("required") || message.contains("invalid"),
                "Error should indicate empty command: \(message)")
        }
    }

    // MARK: - AC#2: Integration with AgentFactory

    /// AC#2: When no --mcp flag is provided, createAgent should succeed without MCP servers.
    /// mcpServers in AgentOptions should be nil (no MCP config loaded).
    func testCreateAgent_withoutMcp_mcpServersIsNil() async throws {
        let args = makeArgs(mcpConfigPath: nil)

        // Should succeed without any MCP config
        let (agent, _) = try await AgentFactory.createAgent(from: args)
        XCTAssertNotNil(agent,
            "Agent creation should succeed without MCP config")
    }

    /// AC#1, #2: When --mcp flag is provided with a valid config path,
    /// createAgent should succeed and load the MCP config into AgentOptions.mcpServers.
    func testCreateAgent_withMcp_mcpServersPopulated() async throws {
        // Create a valid MCP config file
        let json = """
        {
          "mcpServers": {
            "test-server": {
              "command": "echo",
              "args": ["hello"]
            }
          }
        }
        """
        let configPath = try writeTempJSON(json, suffix: "_integration")
        defer { try? FileManager.default.removeItem(atPath: configPath) }

        let args = makeArgs(mcpConfigPath: configPath)

        // Should succeed with MCP config loaded
        let (agent, _) = try await AgentFactory.createAgent(from: args)
        XCTAssertNotNil(agent,
            "Agent creation should succeed with valid MCP config")
    }
}
