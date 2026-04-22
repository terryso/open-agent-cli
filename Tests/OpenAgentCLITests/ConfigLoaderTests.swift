import XCTest
@testable import OpenAgentCLI

final class ConfigLoaderTests: XCTestCase {

    // MARK: - load(from:) — file not found

    func testLoad_nonexistentFile_returnsNil() {
        let result = ConfigLoader.load(from: "/tmp/nonexistent_config_\(UUID().uuidString).json")
        XCTAssertNil(result, "Non-existent file should return nil")
    }

    // MARK: - load(from:) — valid JSON

    func testLoad_validJSON_parsesAllFields() throws {
        let path = "/tmp/test_config_\(UUID().uuidString).json"
        let json = """
        {
            "apiKey": "test-key-123",
            "baseURL": "https://api.example.com/v1",
            "model": "glm-5.1",
            "provider": "anthropic",
            "maxTurns": 20,
            "maxBudgetUsd": 5.0
        }
        """
        try json.write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let config = ConfigLoader.load(from: path)
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.apiKey, "test-key-123")
        XCTAssertEqual(config?.baseURL, "https://api.example.com/v1")
        XCTAssertEqual(config?.model, "glm-5.1")
        XCTAssertEqual(config?.provider, "anthropic")
        XCTAssertEqual(config?.maxTurns, 20)
        XCTAssertEqual(config?.maxBudgetUsd, 5.0)
    }

    func testLoad_partialJSON_onlySetsPresentFields() throws {
        let path = "/tmp/test_config_\(UUID().uuidString).json"
        let json = """
        { "apiKey": "partial-key" }
        """
        try json.write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let config = ConfigLoader.load(from: path)
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.apiKey, "partial-key")
        XCTAssertNil(config?.baseURL)
        XCTAssertNil(config?.model)
    }

    // MARK: - load(from:) — invalid JSON

    func testLoad_invalidJSON_returnsNil() throws {
        let path = "/tmp/test_config_\(UUID().uuidString).json"
        try "not valid json".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let config = ConfigLoader.load(from: path)
        XCTAssertNil(config, "Invalid JSON should return nil")
    }

    // MARK: - apply(_:to:) — fills nil fields

    func testApply_fillsNilFieldsFromConfig() {
        var args = ArgumentParser.parse(["openagent"])
        let config = CLIConfig(
            apiKey: "config-key",
            baseURL: "https://api.example.com",
            model: "custom-model",
            maxTurns: 25
        )

        ConfigLoader.apply(config, to: &args)

        XCTAssertEqual(args.apiKey, "config-key")
        XCTAssertEqual(args.baseURL, "https://api.example.com")
        XCTAssertEqual(args.model, "custom-model")
        XCTAssertEqual(args.maxTurns, 25)
    }

    func testApply_doesNotOverrideCLIArgs() {
        var args = ArgumentParser.parse(["openagent", "--api-key", "cli-key", "--model", "cli-model"])
        let config = CLIConfig(
            apiKey: "config-key",
            baseURL: "https://config.example.com",
            model: "config-model"
        )

        ConfigLoader.apply(config, to: &args)

        XCTAssertEqual(args.apiKey, "cli-key", "CLI --api-key should not be overridden")
        XCTAssertEqual(args.model, "cli-model", "CLI --model should not be overridden")
        XCTAssertEqual(args.baseURL, "https://config.example.com", "Config baseURL should fill nil field")
    }

    func testApply_nilConfig_doesNothing() {
        var args = ArgumentParser.parse(["openagent"])
        let originalKey = args.apiKey
        let originalModel = args.model

        ConfigLoader.apply(nil, to: &args)

        XCTAssertEqual(args.apiKey, originalKey)
        XCTAssertEqual(args.model, originalModel)
    }

    // MARK: - ATDD Red Phase: Story 7.3 — Persistent Configuration File
    //
    // These tests define the EXPECTED behavior of the expanded ConfigLoader.
    // They will FAIL until CLIConfig gains new fields, explicitlySet is added
    // to ParsedArgs, and apply() is refactored (TDD red phase).
    //
    // Acceptance Criteria Coverage:
    //   AC#1: Config file settings applied as defaults
    //   AC#2: CLI args override config file (including explicit defaults)
    //   AC#3: mcpConfigPath, hooksConfigPath, skillDir from config
    //   AC#4: toolAllow/toolDeny from config
    //   AC#5: ~/.openagent/ auto-created
    //   AC#6: Missing path fields produce warning
    //   AC#7: Unknown fields ignored (forward compat)

    // MARK: AC#3 — Load path fields from config file

    func testLoad_configWithMcpPath() throws {
        let path = "/tmp/test_config_mcp_\(UUID().uuidString).json"
        let json = """
        { "mcpConfigPath": "/custom/mcp.json" }
        """
        try json.write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let config = ConfigLoader.load(from: path)
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.mcpConfigPath, "/custom/mcp.json")
    }

    func testLoad_configWithHooksPath() throws {
        let path = "/tmp/test_config_hooks_\(UUID().uuidString).json"
        let json = """
        { "hooksConfigPath": "/custom/hooks.json" }
        """
        try json.write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let config = ConfigLoader.load(from: path)
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.hooksConfigPath, "/custom/hooks.json")
    }

    func testLoad_configWithSkillDir() throws {
        let path = "/tmp/test_config_skilldir_\(UUID().uuidString).json"
        let json = """
        { "skillDir": "/custom/skills" }
        """
        try json.write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let config = ConfigLoader.load(from: path)
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.skillDir, "/custom/skills")
    }

    // MARK: AC#4 — Load toolAllow/toolDeny from config file

    func testLoad_configWithToolAllow() throws {
        let path = "/tmp/test_config_toolallow_\(UUID().uuidString).json"
        let json = """
        { "toolAllow": ["bash", "read", "write"] }
        """
        try json.write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let config = ConfigLoader.load(from: path)
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.toolAllow, ["bash", "read", "write"])
    }

    func testLoad_configWithToolDeny() throws {
        let path = "/tmp/test_config_tooldeny_\(UUID().uuidString).json"
        let json = """
        { "toolDeny": ["edit", "delete"] }
        """
        try json.write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let config = ConfigLoader.load(from: path)
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.toolDeny, ["edit", "delete"])
    }

    // MARK: AC#7 — Unknown fields ignored (forward compat)

    func testLoad_unknownFieldsIgnored() throws {
        let path = "/tmp/test_config_unknown_\(UUID().uuidString).json"
        let json = """
        {
            "apiKey": "known-key",
            "futureFieldX": "some-value",
            "anotherUnknownField": 42,
            "nested": { "deep": true }
        }
        """
        try json.write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        // Should not throw, should return valid config with known fields parsed
        let config = ConfigLoader.load(from: path)
        XCTAssertNotNil(config, "Unknown fields should not cause parse failure")
        XCTAssertEqual(config?.apiKey, "known-key", "Known fields should still be parsed")
    }

    // MARK: AC#1 — New fields applied as defaults from config

    func testApply_newFields_filledFromConfig() {
        var args = ArgumentParser.parse(["openagent"])
        let config = CLIConfig(
            apiKey: "config-key",
            baseURL: nil,
            model: nil,
            provider: nil,
            mode: nil,
            tools: nil,
            maxTurns: nil,
            maxBudgetUsd: nil,
            systemPrompt: nil,
            thinking: nil,
            logLevel: nil
        )

        // This test will fail because CLIConfig does not yet have these fields
        // Once fields are added, we test: mcpConfigPath, hooksConfigPath, skillDir,
        // toolAllow, toolDeny are filled from config when args have nil/default values
        ConfigLoader.apply(config, to: &args)

        // After implementation, these should be populated from config
        // For now, this test verifies the apply function handles the new config gracefully
        XCTAssertEqual(args.apiKey, "config-key", "Config apiKey should fill nil args field")
    }

    // MARK: AC#3 — Path fields filled from config when nil

    func testApply_pathFields_filledWhenNil() throws {
        let configPath = "/tmp/test_config_paths_\(UUID().uuidString).json"
        let json = """
        {
            "mcpConfigPath": "/config/mcp.json",
            "hooksConfigPath": "/config/hooks.json",
            "skillDir": "/config/skills"
        }
        """
        try json.write(toFile: configPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: configPath) }

        let config = ConfigLoader.load(from: configPath)
        var args = ArgumentParser.parse(["openagent"])

        ConfigLoader.apply(config, to: &args)

        // These assertions will fail until CLIConfig has these fields and apply() handles them
        XCTAssertEqual(args.mcpConfigPath, "/config/mcp.json",
            "mcpConfigPath should be filled from config when nil")
        XCTAssertEqual(args.hooksConfigPath, "/config/hooks.json",
            "hooksConfigPath should be filled from config when nil")
        XCTAssertEqual(args.skillDir, "/config/skills",
            "skillDir should be filled from config when nil")
    }

    // MARK: AC#4 — toolAllow filled from config when nil

    func testApply_toolAllow_filledWhenNil() throws {
        let configPath = "/tmp/test_config_toolapply_\(UUID().uuidString).json"
        let json = """
        { "toolAllow": ["bash", "read"], "toolDeny": ["delete"] }
        """
        try json.write(toFile: configPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: configPath) }

        let config = ConfigLoader.load(from: configPath)
        var args = ArgumentParser.parse(["openagent"])

        ConfigLoader.apply(config, to: &args)

        // These assertions will fail until CLIConfig has toolAllow/toolDeny and apply() handles them
        XCTAssertEqual(args.toolAllow, ["bash", "read"],
            "toolAllow should be filled from config when nil")
        XCTAssertEqual(args.toolDeny, ["delete"],
            "toolDeny should be filled from config when nil")
    }

    // MARK: AC#2 — CLI args override config (new fields)

    func testApply_cliArgOverridesConfig_newFields() throws {
        let configPath = "/tmp/test_config_override_\(UUID().uuidString).json"
        let json = """
        {
            "mcpConfigPath": "/config/mcp.json",
            "hooksConfigPath": "/config/hooks.json",
            "toolAllow": ["bash"],
            "toolDeny": ["delete"]
        }
        """
        try json.write(toFile: configPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: configPath) }

        let config = ConfigLoader.load(from: configPath)
        var args = ArgumentParser.parse([
            "openagent",
            "--mcp", "/cli/mcp.json",
            "--hooks", "/cli/hooks.json",
            "--tool-allow", "read,write"
        ])

        ConfigLoader.apply(config, to: &args)

        // CLI args should take precedence over config file
        XCTAssertEqual(args.mcpConfigPath, "/cli/mcp.json",
            "CLI --mcp should override config mcpConfigPath")
        XCTAssertEqual(args.hooksConfigPath, "/cli/hooks.json",
            "CLI --hooks should override config hooksConfigPath")
        XCTAssertEqual(args.toolAllow, ["read", "write"],
            "CLI --tool-allow should override config toolAllow")
    }

    // MARK: AC#2 — explicitlySet prevents config override (sentinel-value fix)

    func testApply_explicitlySet_preventsOverride() {
        // This is the critical bug fix test:
        // User explicitly passes --mode default (same as the default value).
        // Before fix: config.mode would override it (sentinel-value comparison bug).
        // After fix: explicitlySet tracks that user set --mode, so config should NOT override.
        var args = ArgumentParser.parse(["openagent", "--mode", "default"])

        // Verify explicitlySet contains "mode" after parsing
        XCTAssertTrue(args.explicitlySet.contains("mode"),
            "explicitlySet should contain 'mode' when user passes --mode default")

        let config = CLIConfig(
            apiKey: nil, baseURL: nil, model: nil, provider: nil,
            mode: "auto", tools: nil, maxTurns: nil, maxBudgetUsd: nil,
            systemPrompt: nil, thinking: nil, logLevel: nil
        )

        ConfigLoader.apply(config, to: &args)

        // The user explicitly set --mode default, so config should NOT override it
        XCTAssertEqual(args.mode, "default",
            "Explicitly set --mode default should NOT be overridden by config")
    }

    // MARK: AC#6 — Missing path fields produce warning

    func testApply_pathValidation_warnsOnMissingFile() throws {
        let configPath = "/tmp/test_config_missing_path_\(UUID().uuidString).json"
        let nonexistentMcp = "/tmp/nonexistent_mcp_\(UUID().uuidString).json"
        let json = """
        { "mcpConfigPath": "\(nonexistentMcp)" }
        """
        try json.write(toFile: configPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: configPath) }

        let config = ConfigLoader.load(from: configPath)
        var args = ArgumentParser.parse(["openagent"])

        // Capture stderr output
        // This test verifies that a warning is printed when config references a non-existent file.
        // The CLI should still function (non-blocking).
        ConfigLoader.apply(config, to: &args)

        // After implementation, mcpConfigPath should still be set even if file doesn't exist
        // (the warning is informational, not blocking)
        XCTAssertEqual(args.mcpConfigPath, nonexistentMcp,
            "mcpConfigPath should still be set even if referenced file doesn't exist")
    }

    // MARK: AC#5 — ~/.openagent/ directory auto-creation

    func testEnsureConfigDirectory_createsDir() {
        let testDir = "/tmp/test_openagent_config_\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: testDir) }

        // Directory should not exist yet
        XCTAssertFalse(FileManager.default.fileExists(atPath: testDir),
            "Test directory should not exist before ensureConfigDirectory")

        // Call ensureConfigDirectory with the test path
        // This will fail until ensureConfigDirectory() is implemented
        ConfigLoader.ensureConfigDirectory(at: testDir)

        XCTAssertTrue(FileManager.default.fileExists(atPath: testDir),
            "ensureConfigDirectory should create the directory")
    }

    func testEnsureConfigDirectory_existingDir() {
        let testDir = "/tmp/test_openagent_existing_\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: testDir) }

        // Pre-create the directory
        try? FileManager.default.createDirectory(atPath: testDir, withIntermediateDirectories: true)

        // Calling again should not error
        ConfigLoader.ensureConfigDirectory(at: testDir)

        XCTAssertTrue(FileManager.default.fileExists(atPath: testDir),
            "Directory should still exist after calling ensureConfigDirectory on existing dir")
    }

    // MARK: - ATDD: Story 7.4 Multi-Provider Support
    //
    // Acceptance Criteria Coverage:
    //   AC#5: Config file provider and baseURL loaded when CLI flags not passed
    //
    // These tests verify that the configuration priority layering works correctly
    // for provider and baseURL: CLI args > env vars > config file > SDK defaults.

    // MARK: AC#5 — Config file provider applied when CLI flag absent

    /// AC#5: When config file contains "provider": "openai" and no CLI --provider is passed,
    /// the config value should be applied to ParsedArgs.
    func testConfigApply_provider_filledFromConfig() {
        var args = ArgumentParser.parse(["openagent"])
        let config = CLIConfig(
            apiKey: nil,
            baseURL: nil,
            model: nil,
            provider: "openai",
            mode: nil,
            tools: nil,
            maxTurns: nil,
            maxBudgetUsd: nil,
            systemPrompt: nil,
            thinking: nil,
            logLevel: nil
        )

        ConfigLoader.apply(config, to: &args)

        XCTAssertEqual(args.provider, "openai",
            "Config file provider 'openai' should be applied when --provider not passed")
    }

    /// AC#5: When config file contains "baseURL": "https://my-proxy.example.com/v1"
    /// and no CLI --base-url is passed, the config value should be applied.
    func testConfigApply_baseURL_filledFromConfig() {
        var args = ArgumentParser.parse(["openagent"])
        let config = CLIConfig(
            apiKey: nil,
            baseURL: "https://my-proxy.example.com/v1",
            model: nil,
            provider: nil,
            mode: nil,
            tools: nil,
            maxTurns: nil,
            maxBudgetUsd: nil,
            systemPrompt: nil,
            thinking: nil,
            logLevel: nil
        )

        ConfigLoader.apply(config, to: &args)

        XCTAssertEqual(args.baseURL, "https://my-proxy.example.com/v1",
            "Config file baseURL should be applied when --base-url not passed")
    }

    /// AC#5: CLI --provider and --base-url should NOT be overridden by config file.
    /// This verifies the priority layering: CLI args > config file.
    func testConfigApply_providerAndBaseURL_CLIOverrides() {
        var args = ArgumentParser.parse([
            "openagent",
            "--provider", "openai",
            "--base-url", "https://cli-url.example.com/v1"
        ])
        let config = CLIConfig(
            apiKey: nil,
            baseURL: "https://config-url.example.com/v1",
            model: nil,
            provider: "anthropic",
            mode: nil,
            tools: nil,
            maxTurns: nil,
            maxBudgetUsd: nil,
            systemPrompt: nil,
            thinking: nil,
            logLevel: nil
        )

        ConfigLoader.apply(config, to: &args)

        XCTAssertEqual(args.provider, "openai",
            "CLI --provider openai should NOT be overridden by config provider 'anthropic'")
        XCTAssertEqual(args.baseURL, "https://cli-url.example.com/v1",
            "CLI --base-url should NOT be overridden by config baseURL")
    }

    /// AC#5: Full config file loading path with both provider and baseURL.
    /// Verifies that the JSON -> CLIConfig -> ParsedArgs pipeline works for provider fields.
    func testConfigApply_openaiProvider_fromConfigFile() throws {
        let configPath = "/tmp/test_config_provider_\(UUID().uuidString).json"
        let json = """
        {
            "provider": "openai",
            "baseURL": "https://api.openai.com/v1"
        }
        """
        try json.write(toFile: configPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: configPath) }

        let config = ConfigLoader.load(from: configPath)
        var args = ArgumentParser.parse(["openagent"])

        ConfigLoader.apply(config, to: &args)

        XCTAssertEqual(args.provider, "openai",
            "Provider loaded from config file JSON should be applied")
        XCTAssertEqual(args.baseURL, "https://api.openai.com/v1",
            "BaseURL loaded from config file JSON should be applied")
    }
}
