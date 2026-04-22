import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 7.7 Skills Listing & Custom Tool Registration
//
// These tests define the EXPECTED behavior of custom tool registration via config file.
// They will FAIL until the feature is implemented (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#2: Custom tools registered via config file and available to Agent
//   AC#4: Invalid JSON Schema -> warning, skip tool, CLI continues
//   AC#5: Invalid execute script path -> warning, skip tool, CLI continues
//
// Note: AC#1 and AC#3 (/skills command) are already implemented in Story 2.3
// and covered by existing tests in SkillLoadingTests and REPLLoopTests.
//
// Key files to modify for implementation:
//   - ConfigLoader.swift: Add CustomToolConfig struct and customTools field to CLIConfig
//   - ArgumentParser.swift: Add customTools to ParsedArgs
//   - AgentFactory.swift: Add createCustomTools(from:) and integrate in computeToolPool()

final class CustomToolRegistrationTests: XCTestCase {

    // MARK: - Helpers

    /// Write a temporary JSON config file and return its path.
    private func writeTempConfig(_ json: String, suffix: String = "") throws -> String {
        let dir = NSTemporaryDirectory()
        let path = dir + "custom_tool_config_\(UUID().uuidString)\(suffix).json"
        try json.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    /// Write a temporary executable script and return its path.
    private func writeTempScript(_ content: String, name: String = "tool") throws -> String {
        let dir = NSTemporaryDirectory()
        let path = dir + "custom_tool_\(name)_\(UUID().uuidString).sh"
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        // Make executable
        try FileManager.default.setAttributes(
            [FileAttributeKey.posixPermissions: 0o755],
            ofItemAtPath: path
        )
        return path
    }

    /// Build ParsedArgs with common defaults.
    private func makeArgs(
        apiKey: String? = "test-api-key",
        baseURL: String? = "https://api.example.com/v1",
        model: String = "glm-5.1",
        provider: String? = nil,
        mode: String = "default",
        tools: String = "core",
        toolAllow: [String]? = nil,
        toolDeny: [String]? = nil
    ) -> ParsedArgs {
        ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: model,
            apiKey: apiKey,
            baseURL: baseURL,
            provider: provider,
            mode: mode,
            tools: tools,
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
            toolAllow: toolAllow,
            toolDeny: toolDeny,
            shouldExit: false,
            exitCode: 0,
            errorMessage: nil,
            helpMessage: nil
        )
    }

    // ================================================================
    // MARK: - AC#2: Custom Tool Config Decoding (Unit, P0)
    // ================================================================

    /// AC#2: A valid customTools config JSON should parse into CLIConfig with
    /// the customTools array populated. Each CustomToolConfig should have
    /// name, description, inputSchema, and execute fields correctly decoded.
    func testCustomToolConfig_decoding_validJSON() throws {
        let scriptPath = try writeTempScript(
            "#!/bin/bash\ncat\n",
            name: "weather"
        )
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }

        let json = """
        {
            "customTools": [
                {
                    "name": "weather",
                    "description": "Get weather for a city",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "city": {
                                "type": "string",
                                "description": "City name"
                            }
                        },
                        "required": ["city"]
                    },
                    "execute": "\(scriptPath)",
                    "isReadOnly": true
                }
            ]
        }
        """
        let configPath = try writeTempConfig(json)
        defer { try? FileManager.default.removeItem(atPath: configPath) }

        let config = ConfigLoader.load(from: configPath)
        XCTAssertNotNil(config, "Config with customTools should parse successfully")

        // AC#2: customTools array should be populated with 1 tool
        XCTAssertNotNil(config?.customTools, "customTools should not be nil when present in config")
        XCTAssertEqual(config?.customTools?.count, 1, "Should parse exactly 1 custom tool")

        let tool = config?.customTools?.first
        XCTAssertEqual(tool?.name, "weather", "Tool name should be 'weather'")
        XCTAssertEqual(tool?.description, "Get weather for a city")
        XCTAssertEqual(tool?.execute, scriptPath, "Tool execute path should match")
    }

    /// AC#2: CustomToolConfig should correctly decode all fields including
    /// the nested inputSchema as a [String: Any] dictionary.
    func testCustomToolConfig_decoding_allFields() throws {
        let scriptPath = try writeTempScript(
            "#!/bin/bash\ncat\n",
            name: "calculator"
        )
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }

        let json = """
        {
            "customTools": [
                {
                    "name": "calculator",
                    "description": "Performs arithmetic",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "operation": { "type": "string" },
                            "a": { "type": "number" },
                            "b": { "type": "number" }
                        },
                        "required": ["operation", "a", "b"]
                    },
                    "execute": "\(scriptPath)",
                    "isReadOnly": true
                }
            ]
        }
        """
        let configPath = try writeTempConfig(json)
        defer { try? FileManager.default.removeItem(atPath: configPath) }

        let config = ConfigLoader.load(from: configPath)
        let tool = config?.customTools?.first
        XCTAssertNotNil(tool)

        // Verify inputSchema was decoded as a dictionary
        XCTAssertNotNil(tool?.inputSchema, "inputSchema should not be nil")
        XCTAssertEqual(tool?.inputSchema["type"] as? String, "object",
            "inputSchema should contain 'type': 'object'")
        XCTAssertNotNil(tool?.inputSchema["properties"] as? [String: Any],
            "inputSchema should contain 'properties' dictionary")

        let required = tool?.inputSchema["required"] as? [String]
        XCTAssertEqual(required, ["operation", "a", "b"],
            "inputSchema 'required' should match")
    }

    /// AC#2: When isReadOnly is not specified, it should default to false.
    func testCustomToolConfig_decoding_optionalIsReadOnly_defaultsFalse() throws {
        let scriptPath = try writeTempScript(
            "#!/bin/bash\ncat\n",
            name: "echo"
        )
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }

        let json = """
        {
            "customTools": [
                {
                    "name": "echo",
                    "description": "Echoes input",
                    "inputSchema": { "type": "object", "properties": {} },
                    "execute": "\(scriptPath)"
                }
            ]
        }
        """
        let configPath = try writeTempConfig(json)
        defer { try? FileManager.default.removeItem(atPath: configPath) }

        let config = ConfigLoader.load(from: configPath)
        let tool = config?.customTools?.first
        XCTAssertNotNil(tool)

        // isReadOnly should default to false when not specified
        let isReadOnly = tool?.isReadOnly ?? false
        XCTAssertFalse(isReadOnly,
            "isReadOnly should default to false when omitted from config")
    }

    /// AC#2: Multiple custom tools should all be parsed correctly.
    func testCustomToolConfig_decoding_multipleTools() throws {
        let script1 = try writeTempScript("#!/bin/bash\necho 'tool1'\n", name: "tool1")
        let script2 = try writeTempScript("#!/bin/bash\necho 'tool2'\n", name: "tool2")
        defer {
            try? FileManager.default.removeItem(atPath: script1)
            try? FileManager.default.removeItem(atPath: script2)
        }

        let json = """
        {
            "customTools": [
                {
                    "name": "tool_one",
                    "description": "First custom tool",
                    "inputSchema": { "type": "object", "properties": {} },
                    "execute": "\(script1)"
                },
                {
                    "name": "tool_two",
                    "description": "Second custom tool",
                    "inputSchema": { "type": "object", "properties": {} },
                    "execute": "\(script2)",
                    "isReadOnly": true
                }
            ]
        }
        """
        let configPath = try writeTempConfig(json)
        defer { try? FileManager.default.removeItem(atPath: configPath) }

        let config = ConfigLoader.load(from: configPath)
        XCTAssertEqual(config?.customTools?.count, 2,
            "Should parse exactly 2 custom tools")

        let names = config?.customTools?.map { $0.name }.sorted()
        XCTAssertEqual(names, ["tool_one", "tool_two"],
            "Both tool names should be parsed correctly")
    }

    // ================================================================
    // MARK: - AC#2: ConfigLoader.apply() passes customTools to ParsedArgs (Unit, P0)
    // ================================================================

    /// AC#2: When config file contains customTools, ConfigLoader.apply() should
    /// populate ParsedArgs.customTools so the tools reach AgentFactory.
    func testConfigApply_customTools_filledFromConfig() throws {
        let scriptPath = try writeTempScript(
            "#!/bin/bash\ncat\n",
            name: "apply_test"
        )
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }

        let json = """
        {
            "customTools": [
                {
                    "name": "apply_tool",
                    "description": "Tool from config",
                    "inputSchema": { "type": "object", "properties": {} },
                    "execute": "\(scriptPath)"
                }
            ]
        }
        """
        let configPath = try writeTempConfig(json)
        defer { try? FileManager.default.removeItem(atPath: configPath) }

        let config = ConfigLoader.load(from: configPath)
        var args = ArgumentParser.parse(["openagent"])

        ConfigLoader.apply(config, to: &args)

        // AC#2: customTools should be passed from config to ParsedArgs
        XCTAssertNotNil(args.customTools,
            "ParsedArgs.customTools should be populated from config")
        XCTAssertEqual(args.customTools?.count, 1,
            "Should have exactly 1 custom tool from config")
        XCTAssertEqual(args.customTools?.first?.name, "apply_tool",
            "Custom tool name should match config")
    }

    /// AC#2: When config file has no customTools key, ParsedArgs.customTools
    /// should remain nil (no empty array, no error).
    func testConfigApply_noCustomTools_nilInParsedArgs() throws {
        let json = """
        { "apiKey": "test-key" }
        """
        let configPath = try writeTempConfig(json)
        defer { try? FileManager.default.removeItem(atPath: configPath) }

        let config = ConfigLoader.load(from: configPath)
        var args = ArgumentParser.parse(["openagent"])

        ConfigLoader.apply(config, to: &args)

        XCTAssertNil(args.customTools,
            "ParsedArgs.customTools should be nil when config has no customTools")
    }

    // ================================================================
    // MARK: - AC#2: AgentFactory.createCustomTools (Unit, P0)
    // ================================================================

    /// AC#2: createCustomTools should convert CustomToolConfig array into
    /// ToolProtocol array. Each tool should have the correct name, description,
    /// and inputSchema.
    func testCreateCustomTools_validConfig_returnsTools() throws {
        let scriptPath = try writeTempScript(
            "#!/bin/bash\ncat\n",
            name: "factory_test"
        )
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }

        let configs = [
            CustomToolConfig(
                name: "test_tool",
                description: "A test tool",
                inputSchema: ["type": "object", "properties": ["input": ["type": "string"]] as [String: Any]],
                execute: scriptPath,
                isReadOnly: true
            )
        ]

        let tools = AgentFactory.createCustomTools(from: configs)

        XCTAssertEqual(tools.count, 1,
            "Should create exactly 1 ToolProtocol from valid config")
        XCTAssertEqual(tools.first?.name, "test_tool",
            "Created tool should have correct name")
    }

    /// AC#2: Custom tools from config should be added to the tool pool
    /// via computeToolPool() so the Agent can use them.
    func testCreateCustomTools_toolsAddedToPool() throws {
        let scriptPath = try writeTempScript(
            "#!/bin/bash\necho '{\"result\": \"ok\"}'\n",
            name: "pool_test"
        )
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }

        var args = makeArgs()
        args.customTools = [
            CustomToolConfig(
                name: "pool_custom",
                description: "Custom tool for pool test",
                inputSchema: ["type": "object", "properties": ["query": ["type": "string"]] as [String: Any]],
                execute: scriptPath,
                isReadOnly: false
            )
        ]

        let pool = AgentFactory.computeToolPool(from: args)
        let names = pool.map { $0.name }

        XCTAssertTrue(names.contains("pool_custom"),
            "Tool pool should contain custom tool 'pool_custom'. Got: \(names)")
    }

    // ================================================================
    // MARK: - AC#4: Invalid JSON Schema -> warning, skip tool (Unit, P0)
    // ================================================================

    /// AC#4: When a custom tool has an empty inputSchema, the tool should be
    /// skipped (not registered) and a warning should be printed.
    func testCreateCustomTools_emptySchema_skipped() throws {
        let scriptPath = try writeTempScript(
            "#!/bin/bash\ncat\n",
            name: "empty_schema"
        )
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }

        let configs = [
            CustomToolConfig(
                name: "empty_schema_tool",
                description: "Tool with empty schema",
                inputSchema: [:],  // Empty schema
                execute: scriptPath,
                isReadOnly: false
            )
        ]

        let tools = AgentFactory.createCustomTools(from: configs)

        XCTAssertTrue(tools.isEmpty,
            "Tool with empty inputSchema should be skipped (AC#4). Got \(tools.count) tools")
    }

    /// AC#4: When a custom tool has an empty inputSchema, a warning message
    /// should be printed to stderr.
    func testCreateCustomTools_emptySchema_printsWarning() throws {
        let scriptPath = try writeTempScript(
            "#!/bin/bash\ncat\n",
            name: "warn_schema"
        )
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }

        let configs = [
            CustomToolConfig(
                name: "warn_schema_tool",
                description: "Tool with empty schema for warning test",
                inputSchema: [:],
                execute: scriptPath,
                isReadOnly: false
            )
        ]

        // Capture stderr using fd-level redirection (avoids fclose breaking C stderr stream)
        let stderrPath = NSTemporaryDirectory() + "stderr_\(UUID().uuidString).txt"
        let savedStderr = dup(STDERR_FILENO)
        let fd = open(stderrPath, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        dup2(fd, STDERR_FILENO)
        close(fd)

        _ = AgentFactory.createCustomTools(from: configs)

        // Restore stderr
        fflush(nil)
        dup2(savedStderr, STDERR_FILENO)
        close(savedStderr)

        let stderrContent = try String(contentsOfFile: stderrPath)
        defer { try? FileManager.default.removeItem(atPath: stderrPath) }

        XCTAssertTrue(stderrContent.contains("warn_schema_tool") || stderrContent.contains("Warning"),
            "Empty schema should produce a warning mentioning the tool name or 'Warning'. Got: \(stderrContent)")
    }

    /// AC#4: A custom tool config with missing required field 'name' should
    /// fail to decode or be skipped gracefully.
    func testCustomToolConfig_decoding_missingName_throws() throws {
        let scriptPath = try writeTempScript(
            "#!/bin/bash\ncat\n",
            name: "no_name"
        )
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }

        let json = """
        {
            "customTools": [
                {
                    "description": "Tool without a name",
                    "inputSchema": { "type": "object", "properties": {} },
                    "execute": "\(scriptPath)"
                }
            ]
        }
        """
        let configPath = try writeTempConfig(json)
        defer { try? FileManager.default.removeItem(atPath: configPath) }

        let config = ConfigLoader.load(from: configPath)

        // Either the config fails to parse (nil) or customTools is nil/empty
        if let config = config {
            XCTAssertTrue(
                config.customTools == nil || config.customTools?.isEmpty == true,
                "Tool config missing 'name' should not produce a valid tool entry (AC#4)"
            )
        }
        // If config is nil, that's also acceptable (decoding failure)
    }

    /// AC#4: A custom tool config with missing required field 'description' should
    /// fail to decode or be skipped gracefully.
    func testCustomToolConfig_decoding_missingDescription_throws() throws {
        let scriptPath = try writeTempScript(
            "#!/bin/bash\ncat\n",
            name: "no_desc"
        )
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }

        let json = """
        {
            "customTools": [
                {
                    "name": "no_desc_tool",
                    "inputSchema": { "type": "object", "properties": {} },
                    "execute": "\(scriptPath)"
                }
            ]
        }
        """
        let configPath = try writeTempConfig(json)
        defer { try? FileManager.default.removeItem(atPath: configPath) }

        let config = ConfigLoader.load(from: configPath)

        if let config = config {
            XCTAssertTrue(
                config.customTools == nil || config.customTools?.isEmpty == true,
                "Tool config missing 'description' should not produce a valid tool entry (AC#4)"
            )
        }
    }

    // ================================================================
    // MARK: - AC#5: Invalid execute script path -> warning, skip tool (Unit, P0)
    // ================================================================

    /// AC#5: When a custom tool's execute path does not exist, the tool should
    /// be skipped (not registered) and a warning should be printed.
    func testCreateCustomTools_missingExecutePath_skipped() throws {
        let nonexistentPath = "/tmp/nonexistent_tool_script_\(UUID().uuidString).sh"

        let configs = [
            CustomToolConfig(
                name: "missing_path_tool",
                description: "Tool with nonexistent execute path",
                inputSchema: ["type": "object", "properties": ["x": ["type": "string"]] as [String: Any]],
                execute: nonexistentPath,
                isReadOnly: false
            )
        ]

        let tools = AgentFactory.createCustomTools(from: configs)

        XCTAssertTrue(tools.isEmpty,
            "Tool with nonexistent execute path should be skipped (AC#5). Got \(tools.count) tools")
    }

    /// AC#5: When a custom tool's execute path does not exist, a warning
    /// message should be printed to stderr mentioning the tool name.
    func testCreateCustomTools_missingExecutePath_printsWarning() throws {
        let nonexistentPath = "/tmp/nonexistent_warn_\(UUID().uuidString).sh"

        let configs = [
            CustomToolConfig(
                name: "warn_path_tool",
                description: "Tool with missing path for warning test",
                inputSchema: ["type": "object", "properties": ["x": ["type": "string"]] as [String: Any]],
                execute: nonexistentPath,
                isReadOnly: false
            )
        ]

        // Capture stderr using fd-level redirection (avoids fclose breaking C stderr stream)
        let stderrPath = NSTemporaryDirectory() + "stderr_\(UUID().uuidString).txt"
        let savedStderr = dup(STDERR_FILENO)
        let fd = open(stderrPath, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        dup2(fd, STDERR_FILENO)
        close(fd)

        _ = AgentFactory.createCustomTools(from: configs)

        // Restore stderr
        fflush(nil)
        dup2(savedStderr, STDERR_FILENO)
        close(savedStderr)

        let stderrContent = try String(contentsOfFile: stderrPath)
        defer { try? FileManager.default.removeItem(atPath: stderrPath) }

        XCTAssertTrue(stderrContent.contains("warn_path_tool") || stderrContent.contains("Warning"),
            "Missing execute path should produce a warning. Got: \(stderrContent)")
    }

    /// AC#5 + AC#4: When a mix of valid and invalid custom tools is provided,
    /// only the valid tools should be registered. Invalid tools should be skipped
    /// with warnings, and the CLI should continue running.
    func testCreateCustomTools_mixedValidAndInvalid_onlyValidRegistered() throws {
        let validScript = try writeTempScript(
            "#!/bin/bash\ncat\n",
            name: "valid"
        )
        defer { try? FileManager.default.removeItem(atPath: validScript) }

        let configs = [
            // Valid tool
            CustomToolConfig(
                name: "valid_tool",
                description: "A valid custom tool",
                inputSchema: ["type": "object", "properties": ["q": ["type": "string"]] as [String: Any]],
                execute: validScript,
                isReadOnly: false
            ),
            // Invalid: missing execute path
            CustomToolConfig(
                name: "missing_script",
                description: "Tool with missing script",
                inputSchema: ["type": "object", "properties": ["q": ["type": "string"]] as [String: Any]],
                execute: "/tmp/nonexistent_\(UUID().uuidString).sh",
                isReadOnly: false
            ),
            // Invalid: empty schema
            CustomToolConfig(
                name: "empty_schema",
                description: "Tool with empty schema",
                inputSchema: [:],
                execute: validScript,
                isReadOnly: false
            )
        ]

        let tools = AgentFactory.createCustomTools(from: configs)

        XCTAssertEqual(tools.count, 1,
            "Only the valid tool should be registered (1 of 3). Got \(tools.count) tools")
        XCTAssertEqual(tools.first?.name, "valid_tool",
            "The valid tool should be 'valid_tool'")
    }

    // ================================================================
    // MARK: - AC#2: Custom Tool Execution (Integration, P1)
    // ================================================================

    /// AC#2: A registered custom tool should execute its script and return
    /// the output as the tool result. The script receives JSON input via stdin.
    func testCreateCustomTools_toolExecution_succeeds() async throws {
        // Create a script that echoes back the input with a prefix
        let scriptContent = """
        #!/bin/bash
        read input
        echo "Result: $input"
        """
        let scriptPath = try writeTempScript(scriptContent, name: "exec_test")
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }

        let configs = [
            CustomToolConfig(
                name: "exec_tool",
                description: "Tool that echoes input",
                inputSchema: ["type": "object", "properties": ["data": ["type": "string"]] as [String: Any]],
                execute: scriptPath,
                isReadOnly: false
            )
        ]

        let tools = AgentFactory.createCustomTools(from: configs)
        XCTAssertEqual(tools.count, 1, "Should create 1 tool for execution test")

        // Simulate tool execution
        let tool = tools.first!
        let toolUseId = "test-\(UUID().uuidString)"
        let context = ToolContext(cwd: "/tmp", toolUseId: toolUseId)
        let input: [String: Any] = ["data": "hello"]

        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError,
            "Tool execution should succeed (isError should be false)")
        XCTAssertTrue(result.content.contains("Result:"),
            "Tool output should contain the script's output. Got: \(result.content)")
    }

    /// AC#2: When a custom tool's script exits with non-zero code, the tool
    /// should return a ToolExecuteResult with isError = true.
    func testCreateCustomTools_toolExecution_failure_returnsError() async throws {
        // Create a script that exits with error code 1
        let scriptContent = """
        #!/bin/bash
        echo "Error: something went wrong" >&2
        exit 1
        """
        let scriptPath = try writeTempScript(scriptContent, name: "fail_test")
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }

        let configs = [
            CustomToolConfig(
                name: "failing_tool",
                description: "Tool that always fails",
                inputSchema: ["type": "object", "properties": [:] as [String: Any]],
                execute: scriptPath,
                isReadOnly: false
            )
        ]

        let tools = AgentFactory.createCustomTools(from: configs)
        guard let tool = tools.first else {
            XCTFail("Should create 1 tool for failure test")
            return
        }

        let toolUseId = "test-\(UUID().uuidString)"
        let context = ToolContext(cwd: "/tmp", toolUseId: toolUseId)
        let result = await tool.call(input: [:], context: context)

        XCTAssertTrue(result.isError,
            "Tool execution should report error when script exits non-zero (AC#2)")
    }

    /// AC#2: Agent creation should succeed when custom tools are provided
    /// via ParsedArgs. The agent should have the custom tools available.
    func testCreateAgent_withCustomTools_agentCreated() async throws {
        let scriptPath = try writeTempScript(
            "#!/bin/bash\ncat\n",
            name: "agent_test"
        )
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }

        var args = makeArgs()
        args.customTools = [
            CustomToolConfig(
                name: "agent_custom_tool",
                description: "Custom tool for agent creation test",
                inputSchema: ["type": "object", "properties": ["input": ["type": "string"]] as [String: Any]],
                execute: scriptPath,
                isReadOnly: true
            )
        ]

        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent,
            "Agent creation should succeed with custom tools (AC#2)")
    }

    // ================================================================
    // MARK: - AC#5: CLI continues despite invalid custom tools (Integration, P1)
    // ================================================================

    /// AC#5: When all custom tools have invalid definitions, the CLI should
    /// still start successfully -- just with zero custom tools registered.
    func testCreateAgent_allCustomToolsInvalid_agentStillCreated() async throws {
        var args = makeArgs()
        args.customTools = [
            CustomToolConfig(
                name: "invalid_path_tool",
                description: "Tool with missing script",
                inputSchema: ["type": "object", "properties": ["x": ["type": "string"]] as [String: Any]],
                execute: "/tmp/nonexistent_\(UUID().uuidString).sh",
                isReadOnly: false
            ),
            CustomToolConfig(
                name: "empty_schema_tool",
                description: "Tool with empty schema",
                inputSchema: [:],
                execute: "/tmp/also_nonexistent_\(UUID().uuidString).sh",
                isReadOnly: false
            )
        ]

        // Should NOT throw -- invalid custom tools are skipped with warnings
        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent,
            "Agent should be created even when all custom tools are invalid (AC#5)")
    }
}
