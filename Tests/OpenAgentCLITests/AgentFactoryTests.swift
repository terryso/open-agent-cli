import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 1.2 Agent Factory & Core Configuration
//
// These tests define the EXPECTED behavior of AgentFactory.createAgent(from:)
// and related conversion helpers. They will FAIL until AgentFactory.swift is
// implemented (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: Full params (api-key + base-url + model) -> Agent with specified config
//   AC#2: Missing --model -> uses default "glm-5.1"
//   AC#3: OPENAGENT_API_KEY env var -> used when --api-key absent
//   AC#4: No API key at all -> clear error message, exit 1
//   AC#5: --max-turns and --max-budget correctly passed through

final class AgentFactoryTests: XCTestCase {

    // MARK: - Helper: Build ParsedArgs with common defaults

    private func makeArgs(
        apiKey: String? = "test-api-key",
        baseURL: String? = "https://api.example.com/v1",
        model: String = "glm-5.1",
        provider: String? = nil,
        mode: String = "default",
        maxTurns: Int = 10,
        maxBudgetUsd: Double? = nil,
        systemPrompt: String? = nil,
        thinking: Int? = nil,
        logLevel: String? = nil,
        toolAllow: [String]? = nil,
        toolDeny: [String]? = nil,
        hooksConfigPath: String? = nil
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
            tools: "core",
            mcpConfigPath: nil,
            hooksConfigPath: hooksConfigPath,
            skillDir: nil,
            skillName: nil,
            sessionId: nil,
            noRestore: false,
            maxTurns: maxTurns,
            maxBudgetUsd: maxBudgetUsd,
            systemPrompt: systemPrompt,
            thinking: thinking,
            quiet: false,
            output: "text",
            logLevel: logLevel,
            toolAllow: toolAllow,
            toolDeny: toolDeny,
            shouldExit: false,
            exitCode: 0,
            errorMessage: nil,
            helpMessage: nil
        )
    }

    // MARK: - AC#1: Full params (api-key + base-url + model) -> Agent created

    func testCreateAgent_fullParams_returnsAgent() async throws {
        let args = makeArgs(
            apiKey: "sk-test-key",
            baseURL: "https://api.example.com/v1",
            model: "custom-model"
        )

        let agent = try await AgentFactory.createAgent(from: args).0

        XCTAssertNotNil(agent, "createAgent with full params should return a non-nil Agent")
    }

    func testCreateAgent_fullParams_usesSpecifiedModel() async throws {
        let args = makeArgs(
            apiKey: "sk-test-key",
            baseURL: "https://api.example.com/v1",
            model: "custom-model"
        )

        let agent = try await AgentFactory.createAgent(from: args).0

        XCTAssertEqual(agent.model, "custom-model",
            "Agent should use the model specified in ParsedArgs")
    }

    func testCreateAgent_fullParams_usesSpecifiedBaseURL() async throws {
        let args = makeArgs(
            apiKey: "sk-test-key",
            baseURL: "https://custom-api.example.com/v1",
            model: "glm-5.1"
        )

        // Verify the agent is created without errors when baseURL is provided.
        // The Agent doesn't expose baseURL as a public property, so we verify
        // that creation succeeds (it would throw if baseURL were rejected).
        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent, "Agent creation with custom baseURL should succeed")
    }

    // MARK: - AC#2: Missing --model -> default "glm-5.1"

    func testCreateAgent_defaultModel_usesGLM() async throws {
        // ParsedArgs.model default is "glm-5.1" -- no explicit --model passed
        let args = makeArgs(
            apiKey: "sk-test-key",
            baseURL: "https://api.example.com/v1",
            model: "glm-5.1"  // This is the ParsedArgs default
        )

        let agent = try await AgentFactory.createAgent(from: args).0

        XCTAssertEqual(agent.model, "glm-5.1",
            "Agent should use 'glm-5.1' as default model when --model not specified")
    }

    func testCreateAgent_explicitlyPassedGLM_usesGLM() async throws {
        // Explicitly pass glm-5.1 (same as default, but explicitly chosen)
        let args = makeArgs(
            apiKey: "sk-test-key",
            baseURL: "https://api.example.com/v1",
            model: "glm-5.1"
        )

        let agent = try await AgentFactory.createAgent(from: args).0

        XCTAssertEqual(agent.model, "glm-5.1",
            "Agent model should be glm-5.1 when explicitly passed")
    }

    // MARK: - AC#3: API Key from environment variable

    func testCreateAgent_apiKeyFromArgs_succeeds() async throws {
        // When apiKey is provided via ParsedArgs (from --api-key or env var
        // already resolved by ArgumentParser), createAgent should succeed.
        let args = makeArgs(
            apiKey: "resolved-api-key",
            baseURL: nil,
            model: "glm-5.1"
        )

        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent, "Agent creation with API key should succeed")
    }

    func testCreateAgent_apiKeyFromEnvVar_succeeds() async throws {
        // Simulate what ArgumentParser does: resolve env var into ParsedArgs.apiKey
        setenv("OPENAGENT_API_KEY", "env-api-key-123", 1)
        defer { unsetenv("OPENAGENT_API_KEY") }

        // ArgumentParser resolves env var into ParsedArgs.apiKey
        let parsedArgs = ArgumentParser.parse(["openagent"])
        XCTAssertEqual(parsedArgs.apiKey, "env-api-key-123",
            "ArgumentParser should resolve OPENAGENT_API_KEY env var")

        // Verify createAgent succeeds with the resolved key
        let agent = try await AgentFactory.createAgent(from: parsedArgs).0
        XCTAssertNotNil(agent, "Agent creation with env var resolved API key should succeed")
    }

    // MARK: - AC#4: Missing API Key -> error with clear message

    func testCreateAgent_missingApiKey_throwsError() async throws {
        let args = makeArgs(
            apiKey: nil,  // No API key
            baseURL: "https://api.example.com/v1",
            model: "glm-5.1"
        )

        do {
            _ = try await AgentFactory.createAgent(from: args)
            XCTFail("Should throw when API key is missing")
        } catch {
            // Verify the error is the expected type
            XCTAssertTrue(error is AgentFactoryError,
                "Should throw AgentFactoryError when API key is missing")

            let message = error.localizedDescription
            XCTAssertTrue(message.contains("api") || message.contains("API") || message.contains("key") || message.contains("Key"),
                "Error message should mention API key: \(message)")
        }
    }

    func testCreateAgent_missingApiKey_errorIsActionable() async throws {
        let args = makeArgs(apiKey: nil)

        do {
            _ = try await AgentFactory.createAgent(from: args)
            XCTFail("Should throw when API key is missing")
        } catch {
            let message = error.localizedDescription.lowercased()
            // Error should be actionable: tell user what to do
            let hasApiKeyGuidance = message.contains("--api-key") || message.contains("openagent_api_key")
            XCTAssertTrue(hasApiKeyGuidance,
                "Error should guide user to set --api-key or OPENAGENT_API_KEY: \(message)")
        }
    }

    func testCreateAgent_emptyApiKey_throwsError() async throws {
        let args = makeArgs(
            apiKey: "",  // Empty string should be treated as missing
            baseURL: "https://api.example.com/v1",
            model: "glm-5.1"
        )

        do {
            _ = try await AgentFactory.createAgent(from: args)
            XCTFail("Should throw when API key is empty string")
        } catch {
            XCTAssertTrue(error is AgentFactoryError,
                "Should throw AgentFactoryError when API key is empty string")
        }
    }

    func testCreateAgent_whitespaceApiKey_throwsError() async throws {
        let args = makeArgs(
            apiKey: "   ",  // Whitespace-only should be treated as missing
            baseURL: "https://api.example.com/v1",
            model: "glm-5.1"
        )

        do {
            _ = try await AgentFactory.createAgent(from: args)
            XCTFail("Should throw when API key is whitespace-only")
        } catch {
            XCTAssertTrue(error is AgentFactoryError,
                "Should throw AgentFactoryError when API key is whitespace-only")
        }
    }

    // MARK: - AC#5: --max-turns and --max-budget passed through

    func testCreateAgent_maxTurns_passedToAgent() async throws {
        let args = makeArgs(
            apiKey: "sk-test",
            maxTurns: 5
        )

        let agent = try await AgentFactory.createAgent(from: args).0

        XCTAssertEqual(agent.maxTurns, 5,
            "Agent should use maxTurns=5 from ParsedArgs")
    }

    func testCreateAgent_maxBudget_passedThrough() async throws {
        let args = makeArgs(
            apiKey: "sk-test",
            maxBudgetUsd: 1.0
        )

        // maxBudgetUsd is not exposed on Agent as a public property,
        // but the creation should succeed without errors.
        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent, "Agent creation with maxBudgetUsd should succeed")
    }

    func testCreateAgent_maxTurnsDefault_isTen() async throws {
        let args = makeArgs(
            apiKey: "sk-test",
            maxTurns: 10  // ParsedArgs default
        )

        let agent = try await AgentFactory.createAgent(from: args).0

        XCTAssertEqual(agent.maxTurns, 10,
            "Default maxTurns should be 10")
    }

    // MARK: - Provider conversion tests

    func testMapLogLevel_debug_returnsDebug() {
        let result = AgentFactory.mapLogLevel("debug")
        XCTAssertEqual(result, .debug, "logLevel 'debug' should map to LogLevel.debug")
    }

    func testMapLogLevel_info_returnsInfo() {
        let result = AgentFactory.mapLogLevel("info")
        XCTAssertEqual(result, .info, "logLevel 'info' should map to LogLevel.info")
    }

    func testMapLogLevel_warn_returnsWarn() {
        let result = AgentFactory.mapLogLevel("warn")
        XCTAssertEqual(result, .warn, "logLevel 'warn' should map to LogLevel.warn")
    }

    func testMapLogLevel_error_returnsError() {
        let result = AgentFactory.mapLogLevel("error")
        XCTAssertEqual(result, .error, "logLevel 'error' should map to LogLevel.error")
    }

    func testMapLogLevel_nil_returnsNone() {
        let result = AgentFactory.mapLogLevel(nil)
        XCTAssertEqual(result, .none, "nil logLevel should map to LogLevel.none")
    }

    // MARK: - Provider conversion tests

    func testCreateAgent_providerAnthropic_succeeds() async throws {
        let args = makeArgs(
            apiKey: "sk-test",
            provider: "anthropic"
        )

        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent, "Agent with provider 'anthropic' should be created")
    }

    func testCreateAgent_providerOpenAI_succeeds() async throws {
        let args = makeArgs(
            apiKey: "sk-test",
            baseURL: "https://api.openai.com/v1",
            provider: "openai"
        )

        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent, "Agent with provider 'openai' should be created")
    }

    func testCreateAgent_invalidProvider_throwsError() async throws {
        let args = makeArgs(
            apiKey: "sk-test",
            provider: "invalid_provider"
        )

        do {
            _ = try await AgentFactory.createAgent(from: args)
            XCTFail("Should throw for invalid provider")
        } catch {
            XCTAssertTrue(error is AgentFactoryError,
                "Should throw AgentFactoryError for invalid provider")
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("invalid_provider"),
                "Error message should mention the invalid provider name: \(message)")
        }
    }

    func testCreateAgent_noProvider_defaultsToAnthropic() async throws {
        let args = makeArgs(
            apiKey: "sk-test",
            provider: nil  // No provider specified
        )

        // Should succeed with default provider (anthropic)
        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent, "Agent with no provider should default to anthropic")
    }

    // MARK: - Permission mode conversion tests

    func testCreateAgent_modeDefault_succeeds() async throws {
        let args = makeArgs(apiKey: "sk-test", mode: "default")
        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent)
    }

    func testCreateAgent_modeBypassPermissions_succeeds() async throws {
        let args = makeArgs(apiKey: "sk-test", mode: "bypassPermissions")
        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent)
    }

    func testCreateAgent_modePlan_succeeds() async throws {
        let args = makeArgs(apiKey: "sk-test", mode: "plan")
        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent)
    }

    func testCreateAgent_modeAuto_succeeds() async throws {
        let args = makeArgs(apiKey: "sk-test", mode: "auto")
        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent)
    }

    func testCreateAgent_invalidMode_throwsError() async throws {
        let args = makeArgs(apiKey: "sk-test", mode: "invalidMode")

        do {
            _ = try await AgentFactory.createAgent(from: args)
            XCTFail("Should throw for invalid mode")
        } catch {
            XCTAssertTrue(error is AgentFactoryError,
                "Should throw AgentFactoryError for invalid mode")
        }
    }

    // MARK: - Thinking config conversion tests

    func testCreateAgent_thinkingEnabled_createsAgent() async throws {
        let args = makeArgs(
            apiKey: "sk-test",
            thinking: 8192
        )

        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent, "Agent with thinking config should be created")
    }

    func testCreateAgent_thinkingNil_noThinking() async throws {
        let args = makeArgs(
            apiKey: "sk-test",
            thinking: nil
        )

        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent, "Agent without thinking config should be created")
    }

    // MARK: - Tool allow/deny pass-through tests

    func testCreateAgent_toolAllowPassed_createsAgent() async throws {
        let args = makeArgs(
            apiKey: "sk-test",
            toolAllow: ["Bash", "Read", "Write"]
        )

        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent, "Agent with allowedTools should be created")
    }

    func testCreateAgent_toolDenyPassed_createsAgent() async throws {
        let args = makeArgs(
            apiKey: "sk-test",
            toolDeny: ["Edit", "Delete"]
        )

        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent, "Agent with disallowedTools should be created")
    }

    func testCreateAgent_toolAllowAndDeny_createsAgent() async throws {
        let args = makeArgs(
            apiKey: "sk-test",
            toolAllow: ["Bash", "Read"],
            toolDeny: ["Write"]
        )

        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent, "Agent with both allowedTools and disallowedTools should be created")
    }

    // MARK: - System prompt pass-through tests

    func testCreateAgent_systemPrompt_createsAgent() async throws {
        let args = makeArgs(
            apiKey: "sk-test",
            systemPrompt: "You are a helpful coding assistant."
        )

        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertEqual(agent.systemPrompt, "You are a helpful coding assistant.",
            "Agent should use the system prompt from ParsedArgs")
    }

    func testCreateAgent_nilSystemPrompt_createsAgent() async throws {
        let args = makeArgs(
            apiKey: "sk-test",
            systemPrompt: nil
        )

        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNil(agent.systemPrompt,
            "Agent systemPrompt should be nil when not provided")
    }

    // MARK: - cwd (current working directory) tests

    func testCreateAgent_setsCwd() async throws {
        let args = makeArgs(apiKey: "sk-test")

        let agent = try await AgentFactory.createAgent(from: args).0
        // Agent doesn't expose cwd as a public property, but creation should succeed
        // with cwd set to FileManager.default.currentDirectoryPath
        XCTAssertNotNil(agent)
    }

    // MARK: - Integration: Full pipeline from CLI args to Agent

    func testFullPipeline_apiKeyAndModel_argsToAgent() async throws {
        // Simulate the full pipeline: raw CLI args -> ArgumentParser -> AgentFactory -> Agent
        let parsedArgs = ArgumentParser.parse([
            "openagent",
            "--api-key", "pipeline-test-key",
            "--model", "glm-5.1",
            "--max-turns", "3"
        ])

        XCTAssertEqual(parsedArgs.apiKey, "pipeline-test-key")
        XCTAssertEqual(parsedArgs.model, "glm-5.1")
        XCTAssertEqual(parsedArgs.maxTurns, 3)
        XCTAssertFalse(parsedArgs.shouldExit)

        let agent = try await AgentFactory.createAgent(from: parsedArgs).0
        XCTAssertEqual(agent.model, "glm-5.1")
        XCTAssertEqual(agent.maxTurns, 3)
    }

    func testFullPipeline_missingApiKey_argsThrowAtFactory() async throws {
        // Ensure env var is not set
        unsetenv("OPENAGENT_API_KEY")

        let parsedArgs = ArgumentParser.parse(["openagent", "--model", "glm-5.1"])

        XCTAssertNil(parsedArgs.apiKey, "No API key from args or env")

        do {
            _ = try await AgentFactory.createAgent(from: parsedArgs)
            XCTFail("Should throw when API key is missing in full pipeline")
        } catch {
            XCTAssertTrue(error is AgentFactoryError,
                "Factory should throw when API key is missing in full pipeline")
        }
    }

    func testFullPipeline_envVarKey_resolvedByParser() async throws {
        setenv("OPENAGENT_API_KEY", "env-resolved-key", 1)
        defer { unsetenv("OPENAGENT_API_KEY") }

        let parsedArgs = ArgumentParser.parse(["openagent"])

        XCTAssertEqual(parsedArgs.apiKey, "env-resolved-key",
            "Parser should resolve OPENAGENT_API_KEY into ParsedArgs.apiKey")

        // Factory should succeed with the resolved key
        let agent = try await AgentFactory.createAgent(from: parsedArgs).0
        XCTAssertNotNil(agent, "Agent should be created with env var resolved API key")
    }

    // MARK: - Combined configuration test

    func testCreateAgent_allOptionsCombined_createsAgent() async throws {
        let args = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: "test prompt",
            model: "glm-5.1",
            apiKey: "combined-test-key",
            baseURL: "https://custom.llm.api/v1",
            provider: "openai",
            mode: "auto",
            tools: "advanced",
            mcpConfigPath: nil,
            hooksConfigPath: nil,
            skillDir: nil,
            skillName: nil,
            sessionId: nil,
            noRestore: false,
            maxTurns: 5,
            maxBudgetUsd: 2.5,
            systemPrompt: "Be concise",
            thinking: 4096,
            quiet: true,
            output: "json",
            logLevel: "debug",
            toolAllow: ["Bash", "Read"],
            toolDeny: ["Write"],
            explicitlySet: ["model", "provider", "apiKey", "baseURL", "mode", "tools",
                           "systemPrompt", "thinking", "logLevel", "toolAllow", "toolDeny", "output", "quiet"],
            shouldExit: false,
            exitCode: 0,
            errorMessage: nil,
            helpMessage: nil
        )

        let agent = try await AgentFactory.createAgent(from: args).0

        XCTAssertEqual(agent.model, "glm-5.1")
        XCTAssertEqual(agent.maxTurns, 5)
        XCTAssertEqual(agent.systemPrompt, "Be concise")
        XCTAssertNotNil(agent, "Agent with all combined options should be created")
    }

    // MARK: - ATDD Red Phase: Story 6.1 Hook System Integration
    //
    // Acceptance Criteria Coverage:
    //   AC#1: Hooks config JSON -> hooks registered via createHookRegistry()
    //   AC#2: preToolUse hook -> hook script executes before tool runs
    //   AC#3: Hook timeout/error -> warning logged, agent operation continues

    // MARK: - AC#1: Hook config integration with AgentFactory

    /// AC#1: When no --hooks flag is provided, createAgent should succeed
    /// and hookRegistry should not be configured (no hooks loaded).
    func testCreateAgent_noHooks_hookRegistryNotConfigured() async throws {
        let args = makeArgs(hooksConfigPath: nil)

        let (agent, _, _) = try await AgentFactory.createAgent(from: args)
        XCTAssertNotNil(agent,
            "Agent creation should succeed without hooks config")
    }

    /// AC#1: When --hooks flag is provided with a valid config path,
    /// createAgent should succeed and load the hooks config into AgentOptions.
    func testCreateAgent_withHooks_agentCreated() async throws {
        // Create a valid hooks config file
        let json = """
        {
          "hooks": {
            "preToolUse": [
              { "command": "echo 'before tool'" }
            ]
          }
        }
        """
        let dir = NSTemporaryDirectory()
        let configPath = dir + "hooks_test_agent_\(UUID().uuidString).json"
        try json.write(toFile: configPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: configPath) }

        let args = makeArgs(hooksConfigPath: configPath)

        let (agent, _, _) = try await AgentFactory.createAgent(from: args)
        XCTAssertNotNil(agent,
            "Agent creation should succeed with valid hooks config")
    }

    /// AC#1: When --hooks flag is provided with an invalid path,
    /// createAgent should throw a clear error.
    func testCreateAgent_withInvalidHooksPath_throwsError() async throws {
        let nonexistentPath = "/tmp/nonexistent_hooks_\(UUID().uuidString).json"
        let args = makeArgs(hooksConfigPath: nonexistentPath)

        // Should throw because hooks file doesn't exist
        do {
            _ = try await AgentFactory.createAgent(from: args)
            XCTFail("Should throw when hooks file not found")
        } catch {
            let message = error.localizedDescription.lowercased()
            XCTAssertTrue(
                message.contains("not found") || message.contains("hooks") || message.contains("file"),
                "Error should mention file not found: \(message)")
        }
    }

    /// AC#1: When --hooks flag is provided with invalid JSON,
    /// createAgent should throw a descriptive error.
    func testCreateAgent_withInvalidHooksJSON_throwsError() async throws {
        let json = "not valid json"
        let dir = NSTemporaryDirectory()
        let configPath = dir + "hooks_invalid_\(UUID().uuidString).json"
        try json.write(toFile: configPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: configPath) }

        let args = makeArgs(hooksConfigPath: configPath)

        do {
            _ = try await AgentFactory.createAgent(from: args)
            XCTFail("Should throw for invalid hooks JSON")
        } catch {
            let message = error.localizedDescription
            XCTAssertTrue(message.count > 0,
                "Error for invalid hooks JSON should be descriptive: \(message)")
        }
    }

    // MARK: - ATDD: Story 7.4 Multi-Provider Support
    //
    // Acceptance Criteria Coverage:
    //   AC#1: --provider openai --base-url <url> uses OpenAI-compatible client
    //   AC#2: --provider anthropic (or default) uses Anthropic client
    //   AC#3: --provider openai without --base-url uses SDK default URL
    //   AC#4: --provider openai without --model uses provider-appropriate default
    //   AC#5: Config file provider/baseURL loaded (in ConfigLoaderTests)
    //   AC#6: Invalid provider shows error listing valid providers
    //   AC#7: OutputRenderer is provider-agnostic (no provider-specific paths)

    // MARK: AC#2 — mapProvider direct unit tests

    /// AC#2: mapProvider("anthropic") returns .anthropic
    func testMapProvider_anthropic_returnsAnthropic() throws {
        let result = try AgentFactory.mapProvider("anthropic")
        XCTAssertEqual(result, .anthropic,
            "mapProvider('anthropic') should return LLMProvider.anthropic")
    }

    /// AC#2: mapProvider(nil) returns .anthropic (CLI default)
    func testMapProvider_nil_returnsAnthropicDefault() throws {
        let result = try AgentFactory.mapProvider(nil)
        XCTAssertEqual(result, .anthropic,
            "mapProvider(nil) should return LLMProvider.anthropic as CLI default")
    }

    // MARK: AC#1 — mapProvider openai

    /// AC#1: mapProvider("openai") returns .openai
    func testMapProvider_openai_returnsOpenai() throws {
        let result = try AgentFactory.mapProvider("openai")
        XCTAssertEqual(result, .openai,
            "mapProvider('openai') should return LLMProvider.openai")
    }

    // MARK: AC#6 — Invalid provider error

    /// AC#6: mapProvider("google") throws invalidProvider error
    func testMapProvider_invalid_throwsInvalidProvider() {
        XCTAssertThrowsError(try AgentFactory.mapProvider("google"),
            "mapProvider('google') should throw") { error in
            XCTAssertTrue(error is AgentFactoryError,
                "Should throw AgentFactoryError for invalid provider")
            guard let factoryError = error as? AgentFactoryError else { return }
            if case .invalidProvider(let value) = factoryError {
                XCTAssertEqual(value, "google",
                    "Error should contain the invalid provider name")
            } else {
                XCTFail("Should be .invalidProvider case")
            }
        }
    }

    /// AC#6: Error message lists valid providers
    func testMapProvider_errorMessage_listsValidProviders() {
        XCTAssertThrowsError(try AgentFactory.mapProvider("google")) { error in
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("anthropic"),
                "Error message should list 'anthropic' as valid provider: \(message)")
            XCTAssertTrue(message.contains("openai"),
                "Error message should list 'openai' as valid provider: \(message)")
            XCTAssertTrue(message.contains("google"),
                "Error message should mention the invalid provider name: \(message)")
        }
    }

    // MARK: AC#4 — resolveModel direct unit tests

    /// AC#4: resolveModel returns CLI default "glm-5.1" for anthropic when model not explicitly set.
    func testResolveModel_anthropic_notExplicit_returnsCliDefault() {
        let args = makeArgs(model: "glm-5.1")
        // explicitlySet does NOT contain "model" (user did not pass --model)
        let result = AgentFactory.resolveModel(from: args, provider: .anthropic)
        XCTAssertEqual(result, "glm-5.1",
            "resolveModel should return CLI default 'glm-5.1' for anthropic when not explicitly set")
    }

    /// resolveModel returns args.model for any provider when model not explicitly set.
    /// ConfigLoader may have set args.model from config.json — resolveModel respects it.
    func testResolveModel_openai_notExplicit_returnsArgsModel() {
        let args = makeArgs(model: "glm-5.1")  // ParsedArgs default / config value
        // explicitlySet does NOT contain "model"
        let result = AgentFactory.resolveModel(from: args, provider: .openai)
        XCTAssertEqual(result, "glm-5.1",
            "resolveModel should return args.model for openai when not explicitly set")
    }

    /// AC#4: resolveModel returns user's explicit model even when it differs from default.
    func testResolveModel_explicitModel_returnsUserModel() {
        var args = makeArgs(model: "gpt-4o")
        args.explicitlySet.insert("model")
        let result = AgentFactory.resolveModel(from: args, provider: .openai)
        XCTAssertEqual(result, "gpt-4o",
            "resolveModel should return user's explicit model 'gpt-4o'")
    }

    /// AC#4: resolveModel returns user's explicit model even when it equals CLI default.
    func testResolveModel_explicitDefault_returnsUserModel() {
        var args = makeArgs(model: "glm-5.1")
        args.explicitlySet.insert("model")
        let result = AgentFactory.resolveModel(from: args, provider: .openai)
        XCTAssertEqual(result, "glm-5.1",
            "resolveModel should return user's explicit 'glm-5.1' even for openai provider")
    }

    // MARK: AC#3 — OpenAI provider without base URL

    /// AC#3: --provider openai without --base-url should still create an Agent.
    /// The SDK uses OpenAI's default URL when baseURL is nil.
    func testCreateAgent_openaiProvider_withoutBaseURL_succeeds() async throws {
        let args = makeArgs(
            apiKey: "sk-test",
            baseURL: nil,  // No base URL provided
            provider: "openai"
        )

        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent,
            "Agent creation with --provider openai and no --base-url should succeed (SDK uses default URL)")
    }

    // MARK: AC#4 — OpenAI provider without explicit model

    /// --provider openai without --model should use args.model (from config or default).
    /// ConfigLoader may have set args.model from config.json — resolveModel respects it.
    func testCreateAgent_openaiProvider_withoutExplicitModel_succeeds() async throws {
        let args = makeArgs(
            apiKey: "sk-test",
            baseURL: "https://api.openai.com/v1",
            model: "glm-5.1",  // ParsedArgs default (no --model passed)
            provider: "openai"
        )
        // Simulate: user did NOT pass --model (explicitlySet does NOT contain "model")
        // This is the default state from makeArgs, which doesn't add to explicitlySet.

        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent,
            "Agent creation with --provider openai and no explicit --model should succeed")
        // resolveModel returns args.model regardless of provider when not explicitly set
        XCTAssertEqual(agent.model, "glm-5.1",
            "Agent with --provider openai and no explicit --model should use args.model")
    }

    // MARK: AC#1 — Full OpenAI configuration

    /// AC#1, #7: Full OpenAI configuration with provider, baseURL, and model.
    /// Verifies end-to-end creation and that OutputRenderer needs no changes
    /// (provider-agnostic design -- the Agent is created the same way regardless
    /// of provider, and output rendering is handled by SDKMessage abstraction).
    func testCreateAgent_fullOpenaiConfig_succeeds() async throws {
        var args = makeArgs(
            apiKey: "sk-openai-test-key",
            baseURL: "https://api.openai.com/v1",
            model: "gpt-4",
            provider: "openai"
        )
        args.explicitlySet.insert("model")  // Simulate user passing --model gpt-4

        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent,
            "Agent with full OpenAI config should be created")
        XCTAssertEqual(agent.model, "gpt-4",
            "Agent should use the explicitly specified model")
    }

    /// AC#1: OpenAI provider with explicit baseURL succeeds.
    /// This is distinct from the full config test because it focuses on
    /// the provider + baseURL combination specifically.
    func testCreateAgent_openaiProvider_withBaseURL_succeeds() async throws {
        let args = makeArgs(
            apiKey: "sk-test",
            baseURL: "https://my-proxy.example.com/v1",
            provider: "openai"
        )

        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent,
            "Agent with --provider openai --base-url should be created")
    }

}
