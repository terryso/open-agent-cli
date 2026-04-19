import XCTest
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 1.1 CLI Entry Point & Argument Parser
//
// These tests define the EXPECTED behavior of ArgumentParser.parse().
// They will FAIL until ArgumentParser.swift is implemented (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: --help shows help message, exits 0
//   AC#2: No args -> REPL mode with defaults
//   AC#3: Quoted string -> single-shot mode
//   AC#4: Invalid flags -> error message, exit 1

final class ArgumentParserTests: XCTestCase {

    // MARK: - AC#1: --help flag

    func testHelpFlag_setsHelpRequested() throws {
        let result = ArgumentParser.parse(["openagent", "--help"])

        XCTAssertTrue(result.helpRequested, "--help should set helpRequested to true")
        XCTAssertTrue(result.shouldExit, "--help should signal shouldExit")
        XCTAssertEqual(result.exitCode, 0, "--help should exit with code 0")
    }

    func testHelpShortFlag_setsHelpRequested() throws {
        let result = ArgumentParser.parse(["openagent", "-h"])

        XCTAssertTrue(result.helpRequested, "-h should set helpRequested to true")
        XCTAssertTrue(result.shouldExit, "-h should signal shouldExit")
        XCTAssertEqual(result.exitCode, 0, "-h should exit with code 0")
    }

    func testHelpFlag_outputContainsUsageLine() throws {
        let result = ArgumentParser.parse(["openagent", "--help"])

        // The help output (stored in errorMessage or a dedicated field)
        // should contain the usage line and list available flags.
        // We verify the helpMessage property contains key information.
        let helpOutput = result.helpMessage
        XCTAssertNotNil(helpOutput, "Help message should not be nil when --help is requested")
        XCTAssertTrue(helpOutput!.contains("openagent"), "Help should contain program name")
        XCTAssertTrue(helpOutput!.contains("[options]"), "Help should show options syntax")
        XCTAssertTrue(helpOutput!.contains("--model"), "Help should list --model flag")
        XCTAssertTrue(helpOutput!.contains("--mode"), "Help should list --mode flag")
        XCTAssertTrue(helpOutput!.contains("--help"), "Help should list --help flag")
    }

    // MARK: - AC#2: No arguments -> REPL mode with defaults

    func testNoArgs_defaultsToREPLMode() throws {
        let result = ArgumentParser.parse(["openagent"])

        XCTAssertNil(result.prompt, "No prompt when no positional arg provided (REPL mode)")
        XCTAssertFalse(result.shouldExit, "No exit signal for REPL mode")
        XCTAssertFalse(result.helpRequested, "No help requested in REPL mode")
    }

    func testNoArgs_defaultValues() throws {
        let result = ArgumentParser.parse(["openagent"])

        XCTAssertEqual(result.model, "glm-5.1", "Default model should be glm-5.1")
        XCTAssertEqual(result.mode, "default", "Default mode should be 'default'")
        XCTAssertEqual(result.tools, "core", "Default tools tier should be 'core'")
        XCTAssertEqual(result.maxTurns, 10, "Default maxTurns should be 10")
        XCTAssertEqual(result.output, "text", "Default output format should be 'text'")
        XCTAssertFalse(result.quiet, "Default quiet should be false")
        XCTAssertFalse(result.noRestore, "Default noRestore should be false")
    }

    // MARK: - AC#3: Positional string -> single-shot mode

    func testPositionalArg_setsSingleShotMode() throws {
        let result = ArgumentParser.parse(["openagent", "what is 2+2?"])

        XCTAssertEqual(result.prompt, "what is 2+2?", "Positional arg should be stored as prompt")
        XCTAssertFalse(result.shouldExit, "Single-shot should not signal exit (agent handles exit)")
    }

    func testPositionalArgWithFlags_singleShotMode() throws {
        let result = ArgumentParser.parse(["openagent", "--model", "claude-opus-4", "explain quantum computing"])

        XCTAssertEqual(result.prompt, "explain quantum computing", "Prompt should be set from positional arg")
        XCTAssertEqual(result.model, "claude-opus-4", "Model flag should still be parsed")
    }

    // MARK: - AC#4: Invalid flags -> error, exit 1

    func testInvalidFlag_setsError() throws {
        let result = ArgumentParser.parse(["openagent", "--invalid-flag"])

        XCTAssertTrue(result.shouldExit, "Invalid flag should signal shouldExit")
        XCTAssertEqual(result.exitCode, 1, "Invalid flag should exit with code 1")
        XCTAssertNotNil(result.errorMessage, "Invalid flag should set errorMessage")
        XCTAssertTrue(
            result.errorMessage!.contains("--invalid-flag"),
            "Error message should mention the invalid flag"
        )
    }

    func testInvalidFlag_errorIsActionable() throws {
        let result = ArgumentParser.parse(["openagent", "--bogus"])

        // Error messages should be actionable: tell user what's wrong AND how to fix it
        let msg = result.errorMessage!
        XCTAssertTrue(
            msg.contains("--bogus"),
            "Error should name the unknown flag"
        )
        XCTAssertTrue(
            msg.contains("--help"),
            "Error should suggest using --help for available options"
        )
    }

    // MARK: - Version flag

    func testVersionFlag_setsVersionRequested() throws {
        let result = ArgumentParser.parse(["openagent", "--version"])

        XCTAssertTrue(result.versionRequested, "--version should set versionRequested to true")
        XCTAssertTrue(result.shouldExit, "--version should signal shouldExit")
        XCTAssertEqual(result.exitCode, 0, "--version should exit with code 0")
    }

    func testVersionShortFlag_setsVersionRequested() throws {
        let result = ArgumentParser.parse(["openagent", "-v"])

        XCTAssertTrue(result.versionRequested, "-v should set versionRequested to true")
        XCTAssertTrue(result.shouldExit, "-v should signal shouldExit")
        XCTAssertEqual(result.exitCode, 0, "-v should exit with code 0")
    }

    // MARK: - Flag parsing: --model

    func testModelFlag_parsesValue() throws {
        let result = ArgumentParser.parse(["openagent", "--model", "claude-opus-4"])

        XCTAssertEqual(result.model, "claude-opus-4")
    }

    func testModelFlag_missingValue_setsError() throws {
        let result = ArgumentParser.parse(["openagent", "--model"])

        XCTAssertTrue(result.shouldExit, "Missing value for --model should signal exit")
        XCTAssertEqual(result.exitCode, 1, "Missing value should exit code 1")
        XCTAssertNotNil(result.errorMessage, "Missing value should set error message")
    }

    // MARK: - Flag parsing: --mode

    func testModeFlag_validValues() throws {
        let validModes = ["default", "acceptEdits", "bypassPermissions", "plan", "dontAsk", "auto"]

        for mode in validModes {
            let result = ArgumentParser.parse(["openagent", "--mode", mode])
            XCTAssertEqual(result.mode, mode, "Mode '\(mode)' should be accepted")
            XCTAssertFalse(result.shouldExit, "Valid mode '\(mode)' should not signal exit")
        }
    }

    func testModeFlag_invalidValue_setsError() throws {
        let result = ArgumentParser.parse(["openagent", "--mode", "invalidMode"])

        XCTAssertTrue(result.shouldExit, "Invalid mode should signal exit")
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertNotNil(result.errorMessage)
        XCTAssertTrue(
            result.errorMessage!.contains("invalidMode"),
            "Error should mention the invalid mode value"
        )
    }

    // MARK: - Flag parsing: --tools

    func testToolsFlag_validValues() throws {
        let validTiers = ["core", "advanced", "specialist", "all"]

        for tier in validTiers {
            let result = ArgumentParser.parse(["openagent", "--tools", tier])
            XCTAssertEqual(result.tools, tier, "Tools tier '\(tier)' should be accepted")
            XCTAssertFalse(result.shouldExit, "Valid tools '\(tier)' should not signal exit")
        }
    }

    func testToolsFlag_invalidValue_setsError() throws {
        let result = ArgumentParser.parse(["openagent", "--tools", "premium"])

        XCTAssertTrue(result.shouldExit, "Invalid tools tier should signal exit")
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertNotNil(result.errorMessage)
    }

    // MARK: - Flag parsing: --provider

    func testProviderFlag_validValues() throws {
        let validProviders = ["anthropic", "openai"]

        for provider in validProviders {
            let result = ArgumentParser.parse(["openagent", "--provider", provider])
            XCTAssertEqual(result.provider, provider, "Provider '\(provider)' should be accepted")
        }
    }

    func testProviderFlag_invalidValue_setsError() throws {
        let result = ArgumentParser.parse(["openagent", "--provider", "google"])

        XCTAssertTrue(result.shouldExit, "Invalid provider should signal exit")
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertNotNil(result.errorMessage)
    }

    // MARK: - Flag parsing: --output

    func testOutputFlag_validValues() throws {
        let validFormats = ["text", "json"]

        for format in validFormats {
            let result = ArgumentParser.parse(["openagent", "--output", format])
            XCTAssertEqual(result.output, format, "Output format '\(format)' should be accepted")
        }
    }

    func testOutputFlag_invalidValue_setsError() throws {
        let result = ArgumentParser.parse(["openagent", "--output", "xml"])

        XCTAssertTrue(result.shouldExit, "Invalid output format should signal exit")
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertNotNil(result.errorMessage)
    }

    // MARK: - Flag parsing: --log-level

    func testLogLevelFlag_validValues() throws {
        let validLevels = ["debug", "info", "warn", "error"]

        for level in validLevels {
            let result = ArgumentParser.parse(["openagent", "--log-level", level])
            XCTAssertEqual(result.logLevel, level, "Log level '\(level)' should be accepted")
        }
    }

    func testLogLevelFlag_invalidValue_setsError() throws {
        let result = ArgumentParser.parse(["openagent", "--log-level", "verbose"])

        XCTAssertTrue(result.shouldExit, "Invalid log level should signal exit")
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertNotNil(result.errorMessage)
    }

    // MARK: - Flag parsing: --max-turns

    func testMaxTurnsFlag_parsesInt() throws {
        let result = ArgumentParser.parse(["openagent", "--max-turns", "25"])

        XCTAssertEqual(result.maxTurns, 25, "--max-turns should parse as integer")
    }

    func testMaxTurnsFlag_nonPositive_setsError() throws {
        let result = ArgumentParser.parse(["openagent", "--max-turns", "0"])

        XCTAssertTrue(result.shouldExit, "Zero max-turns should be invalid")
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertNotNil(result.errorMessage)
    }

    func testMaxTurnsFlag_nonNumeric_setsError() throws {
        let result = ArgumentParser.parse(["openagent", "--max-turns", "abc"])

        XCTAssertTrue(result.shouldExit, "Non-numeric max-turns should be invalid")
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertNotNil(result.errorMessage)
    }

    // MARK: - Flag parsing: --max-budget

    func testMaxBudgetFlag_parsesDouble() throws {
        let result = ArgumentParser.parse(["openagent", "--max-budget", "5.50"])

        XCTAssertNotNil(result.maxBudgetUsd, "--max-budget should set maxBudgetUsd")
        XCTAssertEqual(result.maxBudgetUsd!, 5.50, accuracy: 0.01, "--max-budget should parse as double")
    }

    func testMaxBudgetFlag_nonPositive_setsError() throws {
        let result = ArgumentParser.parse(["openagent", "--max-budget", "-1.0"])

        XCTAssertTrue(result.shouldExit, "Negative budget should be invalid")
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertNotNil(result.errorMessage)
    }

    // MARK: - Flag parsing: --thinking

    func testThinkingFlag_parsesInt() throws {
        let result = ArgumentParser.parse(["openagent", "--thinking", "10000"])

        XCTAssertEqual(result.thinking, 10000, "--thinking should parse as token budget integer")
    }

    func testThinkingFlag_nonPositive_setsError() throws {
        let result = ArgumentParser.parse(["openagent", "--thinking", "0"])

        XCTAssertTrue(result.shouldExit, "Zero thinking budget should be invalid")
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertNotNil(result.errorMessage)
    }

    // MARK: - Flag parsing: boolean flags

    func testQuietFlag_setsQuiet() throws {
        let result = ArgumentParser.parse(["openagent", "--quiet"])

        XCTAssertTrue(result.quiet, "--quiet should set quiet to true")
    }

    func testNoRestoreFlag_setsNoRestore() throws {
        let result = ArgumentParser.parse(["openagent", "--no-restore"])

        XCTAssertTrue(result.noRestore, "--no-restore should set noRestore to true")
    }

    // MARK: - Flag parsing: string path flags

    func testMcpConfigPathFlag() throws {
        let result = ArgumentParser.parse(["openagent", "--mcp", "/path/to/mcp.json"])

        XCTAssertEqual(result.mcpConfigPath, "/path/to/mcp.json")
    }

    func testHooksConfigPathFlag() throws {
        let result = ArgumentParser.parse(["openagent", "--hooks", "/path/to/hooks.json"])

        XCTAssertEqual(result.hooksConfigPath, "/path/to/hooks.json")
    }

    func testSkillDirFlag() throws {
        let result = ArgumentParser.parse(["openagent", "--skill-dir", "/path/to/skills"])

        XCTAssertEqual(result.skillDir, "/path/to/skills")
    }

    func testSkillFlag() throws {
        let result = ArgumentParser.parse(["openagent", "--skill", "my-skill"])

        XCTAssertEqual(result.skillName, "my-skill")
    }

    func testSessionFlag() throws {
        let result = ArgumentParser.parse(["openagent", "--session", "abc-123"])

        XCTAssertEqual(result.sessionId, "abc-123")
    }

    func testSystemPromptFlag() throws {
        let result = ArgumentParser.parse(["openagent", "--system-prompt", "You are a helpful assistant"])

        XCTAssertEqual(result.systemPrompt, "You are a helpful assistant")
    }

    // MARK: - Flag parsing: --api-key

    func testApiKeyFlag_setsApiKey() throws {
        let result = ArgumentParser.parse(["openagent", "--api-key", "sk-test-key-123"])

        XCTAssertEqual(result.apiKey, "sk-test-key-123")
    }

    func testApiKeyFlag_overridesEnvVar() throws {
        // Set env var first
        setenv("OPENAGENT_API_KEY", "env-key", 1)
        defer { unsetenv("OPENAGENT_API_KEY") }

        // --api-key flag should take precedence over env var
        let result = ArgumentParser.parse(["openagent", "--api-key", "flag-key"])

        XCTAssertEqual(result.apiKey, "flag-key", "--api-key flag should override env var")
    }

    func testApiKeyResolution_fromEnvVar() throws {
        // Set env var, no flag
        setenv("OPENAGENT_API_KEY", "env-key-456", 1)
        defer { unsetenv("OPENAGENT_API_KEY") }

        let result = ArgumentParser.parse(["openagent"])

        XCTAssertEqual(result.apiKey, "env-key-456", "API key should be resolved from OPENAGENT_API_KEY env var when no flag provided")
    }

    func testApiKeyResolution_noSource_returnsNil() throws {
        // Ensure env var is not set
        unsetenv("OPENAGENT_API_KEY")

        let result = ArgumentParser.parse(["openagent"])

        XCTAssertNil(result.apiKey, "API key should be nil when neither flag nor env var is set")
    }

    // MARK: - Flag parsing: --base-url

    func testBaseURLFlag() throws {
        let result = ArgumentParser.parse(["openagent", "--base-url", "https://api.example.com/v1"])

        XCTAssertEqual(result.baseURL, "https://api.example.com/v1")
    }

    // MARK: - Flag parsing: --tool-allow / --tool-deny (comma-separated)

    func testToolAllowFlag_parsesCommaSeparated() throws {
        let result = ArgumentParser.parse(["openagent", "--tool-allow", "bash,read,write"])

        XCTAssertEqual(result.toolAllow, ["bash", "read", "write"], "--tool-allow should parse comma-separated values")
    }

    func testToolDenyFlag_parsesCommaSeparated() throws {
        let result = ArgumentParser.parse(["openagent", "--tool-deny", "edit,delete"])

        XCTAssertEqual(result.toolDeny, ["edit", "delete"], "--tool-deny should parse comma-separated values")
    }

    func testToolAllowFlag_singleValue() throws {
        let result = ArgumentParser.parse(["openagent", "--tool-allow", "bash"])

        XCTAssertEqual(result.toolAllow, ["bash"], "Single --tool-allow value should produce single-element array")
    }

    // MARK: - Multiple flags combined

    func testMultipleFlags_allParsed() throws {
        let result = ArgumentParser.parse([
            "openagent",
            "--model", "claude-opus-4",
            "--mode", "auto",
            "--tools", "all",
            "--max-turns", "20",
            "--quiet",
            "--output", "json",
            "do something"
        ])

        XCTAssertEqual(result.model, "claude-opus-4")
        XCTAssertEqual(result.mode, "auto")
        XCTAssertEqual(result.tools, "all")
        XCTAssertEqual(result.maxTurns, 20)
        XCTAssertTrue(result.quiet)
        XCTAssertEqual(result.output, "json")
        XCTAssertEqual(result.prompt, "do something")
        XCTAssertFalse(result.shouldExit)
    }

    // MARK: - Edge cases

    func testEmptyArgsArray_defaultsToREPL() throws {
        let result = ArgumentParser.parse([])

        // Edge case: empty array (no program name either)
        XCTAssertNil(result.prompt, "Empty args should default to REPL mode (no prompt)")
    }

    func testMultiplePositionalArgs_usesFirstAsPrompt() throws {
        let result = ArgumentParser.parse(["openagent", "first arg", "second arg"])

        // Only the first positional arg should be the prompt
        XCTAssertEqual(result.prompt, "first arg", "First positional arg should be the prompt")
    }

    func testFlagValueMissingAtEnd_setsError() throws {
        let result = ArgumentParser.parse(["openagent", "--session"])

        XCTAssertTrue(result.shouldExit, "Missing value for --session at end of args should error")
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertNotNil(result.errorMessage)
    }
}
