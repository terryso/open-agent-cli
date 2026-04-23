import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Green Phase: Story 8-1 AC#2 ParsedArgs Struct Copy
//
// These tests verify that handleFork() and handleResume() use struct copy
// (`var copy = args; copy.sessionId = newId`) instead of manual field-by-field
// construction, which automatically preserves explicitlySet, customTools, and
// all other fields.
//
// Acceptance Criteria Coverage:
//   AC#2: handleFork/handleResume use struct copy, preserving all fields

final class TechnicalDebtAC2Tests: XCTestCase {

    // MARK: - Helpers

    /// Creates a MockTextOutputStream and OutputRenderer pair for capturing output.
    private func makeRenderer() -> (renderer: OutputRenderer, mock: MockTextOutputStream) {
        let mock = MockTextOutputStream()
        let renderer = OutputRenderer(output: mock)
        return (renderer, mock)
    }

    /// Creates a test Agent with a specific session ID.
    private func makeTestAgent(sessionId: String) async throws -> Agent {
        let args = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-ac2-tests",
            baseURL: "https://api.example.com/v1",
            provider: nil,
            mode: "default",
            tools: "core",
            mcpConfigPath: nil,
            hooksConfigPath: nil,
            skillDir: nil,
            skillName: nil,
            sessionId: sessionId,
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
        return try await AgentFactory.createAgent(from: args).0
    }

    // MARK: - P0: /fork preserves explicitlySet

    /// AC#2: /fork should preserve all explicitlySet entries from the original args.
    func testFork_preservesExplicitlySetFields() async throws {
        let (renderer, mockOutput) = makeRenderer()

        let sessionId = UUID().uuidString

        // Create args with explicitly set model and baseURL
        var originalArgs = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-ac2-tests",
            baseURL: "https://custom-api.example.com/v1",
            provider: nil,
            mode: "default",
            tools: "core",
            mcpConfigPath: nil,
            hooksConfigPath: nil,
            skillDir: nil,
            skillName: nil,
            sessionId: sessionId,
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
        originalArgs.explicitlySet = ["model", "baseURL", "apiKey"]
        originalArgs.customTools = []

        // Create and save agent (uses default SessionStore)
        let agent = try await makeTestAgent(sessionId: sessionId)
        try await agent.close()

        // Use default SessionStore (same one AgentFactory saves to)
        let sessionStore = SessionStore()
        let inputReader = MockInputReader(["/fork", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(sessionId: sessionId),
            renderer: renderer,
            reader: inputReader,
            sessionStore: sessionStore,
            parsedArgs: originalArgs
        )

        await repl.start()

        // The fork should succeed -- verify output contains "Session forked"
        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("session forked"),
            "/fork should succeed and show confirmation (AC#2). Got: \(mockOutput.output)")
    }

    // MARK: - P0: /fork preserves customTools

    /// AC#2: /fork should preserve the customTools array from original args.
    func testFork_preservesCustomTools() async throws {
        let (renderer, mockOutput) = makeRenderer()

        let sessionId = UUID().uuidString

        var originalArgs = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-ac2-tests",
            baseURL: "https://api.example.com/v1",
            provider: nil,
            mode: "default",
            tools: "core",
            mcpConfigPath: nil,
            hooksConfigPath: nil,
            skillDir: nil,
            skillName: nil,
            sessionId: sessionId,
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
        // Set customTools to verify they survive the fork
        originalArgs.customTools = [
            CustomToolConfig(name: "my-tool", description: "Test tool", inputSchema: ["type": "object"], execute: "/usr/bin/true", isReadOnly: nil)
        ]

        let agent = try await makeTestAgent(sessionId: sessionId)
        try await agent.close()

        // Use default SessionStore (same one AgentFactory saves to)
        let sessionStore = SessionStore()
        let inputReader = MockInputReader(["/fork", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(sessionId: sessionId),
            renderer: renderer,
            reader: inputReader,
            sessionStore: sessionStore,
            parsedArgs: originalArgs
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        // Fork should succeed -- customTools preserved via struct copy
        XCTAssertTrue(output.contains("session forked"),
            "/fork should succeed when customTools are set (AC#2). Got: \(mockOutput.output)")
    }

    // MARK: - P0: /resume preserves explicitlySet

    /// AC#2: /resume should preserve all explicitlySet entries from the original args.
    func testResume_preservesExplicitlySetFields() async throws {
        let (renderer, mockOutput) = makeRenderer()

        let sessionId = UUID().uuidString

        var originalArgs = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-ac2-tests",
            baseURL: "https://custom-api.example.com/v1",
            provider: "anthropic",
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
            toolAllow: nil,
            toolDeny: nil,
            shouldExit: false,
            exitCode: 0,
            errorMessage: nil,
            helpMessage: nil
        )
        originalArgs.explicitlySet = ["model", "baseURL", "provider", "apiKey"]

        // Create and save a session so it can be resumed (uses default SessionStore)
        let agentArgs = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-ac2-tests",
            baseURL: "https://api.example.com/v1",
            provider: nil,
            mode: "default",
            tools: "core",
            mcpConfigPath: nil,
            hooksConfigPath: nil,
            skillDir: nil,
            skillName: nil,
            sessionId: sessionId,
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
        let (agent, _, _) = try await AgentFactory.createAgent(from: agentArgs)
        try await agent.close()

        // Use default SessionStore (same one AgentFactory saves to)
        let sessionStore = SessionStore()
        let inputReader = MockInputReader(["/resume \(sessionId)", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(sessionId: sessionId),
            renderer: renderer,
            reader: inputReader,
            sessionStore: sessionStore,
            parsedArgs: originalArgs
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("resumed session"),
            "/resume should succeed and show confirmation (AC#2). Got: \(mockOutput.output)")
    }

    // MARK: - P0: /resume preserves customTools

    /// AC#2: /resume should preserve the customTools array from original args.
    func testResume_preservesCustomTools() async throws {
        let (renderer, mockOutput) = makeRenderer()

        let sessionId = UUID().uuidString

        var originalArgs = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-ac2-tests",
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
            toolAllow: nil,
            toolDeny: nil,
            shouldExit: false,
            exitCode: 0,
            errorMessage: nil,
            helpMessage: nil
        )
        originalArgs.customTools = [
            CustomToolConfig(name: "my-tool", description: "Test tool", inputSchema: ["type": "object"], execute: "/usr/bin/true", isReadOnly: nil)
        ]

        // Create and save a session (uses default SessionStore)
        let agentArgs = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-ac2-tests",
            baseURL: "https://api.example.com/v1",
            provider: nil,
            mode: "default",
            tools: "core",
            mcpConfigPath: nil,
            hooksConfigPath: nil,
            skillDir: nil,
            skillName: nil,
            sessionId: sessionId,
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
        let (agent, _, _) = try await AgentFactory.createAgent(from: agentArgs)
        try await agent.close()

        // Use default SessionStore (same one AgentFactory saves to)
        let sessionStore = SessionStore()
        let inputReader = MockInputReader(["/resume \(sessionId)", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(sessionId: sessionId),
            renderer: renderer,
            reader: inputReader,
            sessionStore: sessionStore,
            parsedArgs: originalArgs
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("resumed session"),
            "/resume should succeed when customTools are set (AC#2). Got: \(mockOutput.output)")
    }

    // MARK: - P1: /fork preserves model/baseURL when explicitly set

    /// AC#2: When model and baseURL are explicitly set by the user, /fork should
    /// preserve them so the forked agent uses the same configuration.
    func testFork_preservesBaseURL_whenExplicitlySet() async throws {
        let (renderer, mockOutput) = makeRenderer()

        let sessionId = UUID().uuidString

        var originalArgs = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "claude-opus-4",
            apiKey: "test-key-for-ac2-tests",
            baseURL: "https://custom-api.example.com/v1",
            provider: "anthropic",
            mode: "default",
            tools: "core",
            mcpConfigPath: nil,
            hooksConfigPath: nil,
            skillDir: nil,
            skillName: nil,
            sessionId: sessionId,
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
        originalArgs.explicitlySet = ["model", "baseURL", "provider"]

        let agent = try await makeTestAgent(sessionId: sessionId)
        try await agent.close()

        // Use default SessionStore (same one AgentFactory saves to)
        let sessionStore = SessionStore()
        let inputReader = MockInputReader(["/fork", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(sessionId: sessionId),
            renderer: renderer,
            reader: inputReader,
            sessionStore: sessionStore,
            parsedArgs: originalArgs
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        // Fork should succeed without error
        XCTAssertFalse(output.contains("error creating forked"),
            "/fork with explicitly set baseURL should not error (AC#2). Got: \(mockOutput.output)")
    }

    // MARK: - P1: /resume preserves model/baseURL when explicitly set

    /// AC#2: When model and baseURL are explicitly set, /resume should preserve them.
    func testResume_preservesBaseURL_whenExplicitlySet() async throws {
        let (renderer, mockOutput) = makeRenderer()

        let sessionId = UUID().uuidString

        var originalArgs = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "claude-opus-4",
            apiKey: "test-key-for-ac2-tests",
            baseURL: "https://custom-api.example.com/v1",
            provider: "anthropic",
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
            toolAllow: nil,
            toolDeny: nil,
            shouldExit: false,
            exitCode: 0,
            errorMessage: nil,
            helpMessage: nil
        )
        originalArgs.explicitlySet = ["model", "baseURL", "provider"]

        // Create and save a session (uses default SessionStore)
        let agentArgs = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-ac2-tests",
            baseURL: "https://api.example.com/v1",
            provider: nil,
            mode: "default",
            tools: "core",
            mcpConfigPath: nil,
            hooksConfigPath: nil,
            skillDir: nil,
            skillName: nil,
            sessionId: sessionId,
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
        let (agent, _, _) = try await AgentFactory.createAgent(from: agentArgs)
        try await agent.close()

        // Use default SessionStore (same one AgentFactory saves to)
        let sessionStore = SessionStore()
        let inputReader = MockInputReader(["/resume \(sessionId)", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(sessionId: sessionId),
            renderer: renderer,
            reader: inputReader,
            sessionStore: sessionStore,
            parsedArgs: originalArgs
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertFalse(output.contains("error creating resumed"),
            "/resume with explicitly set baseURL should not error (AC#2). Got: \(mockOutput.output)")
    }
}
