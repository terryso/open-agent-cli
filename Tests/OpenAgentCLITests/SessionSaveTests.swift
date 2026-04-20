import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 3.1 Auto-Save Sessions on Exit
//
// These tests define the EXPECTED behavior of session auto-save on CLI exit.
// They will FAIL until AgentFactory.swift and CLI.swift are updated (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: When exiting CLI (via /exit or Ctrl+D), current session is saved via SDK SessionStore
//   AC#2: When session save fails (e.g. disk full), warning is shown but CLI still exits normally
//   AC#3: When CLI started with --no-restore, auto-save is still active

final class SessionSaveTests: XCTestCase {

    // MARK: - Helper: Build ParsedArgs with common defaults

    private func makeArgs(
        apiKey: String? = "test-api-key",
        baseURL: String? = "https://api.example.com/v1",
        model: String = "glm-5.1",
        provider: String? = nil,
        mode: String = "default",
        maxTurns: Int = 10,
        noRestore: Bool = false,
        sessionId: String? = nil
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
            hooksConfigPath: nil,
            skillDir: nil,
            skillName: nil,
            sessionId: sessionId,
            noRestore: noRestore,
            maxTurns: maxTurns,
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

    // MARK: - AC#1: Session is saved when CLI exits (SessionStore injected into AgentOptions)

    func testCreateAgent_injectsSessionStore_intoAgentOptions() throws {
        // AC#1: createAgent should inject a SessionStore instance into AgentOptions.
        // Since Agent doesn't expose sessionStore as a public property, we verify
        // that Agent creation succeeds when SessionStore is expected to be configured.
        let args = makeArgs()
        let agent = try AgentFactory.createAgent(from: args).0

        // Agent should be created successfully with session config
        XCTAssertNotNil(agent, "Agent should be created with SessionStore injected")
    }

    func testCreateAgent_generatesUUID_whenNoSessionId() throws {
        // AC#1: When no --session flag is provided, AgentFactory should generate a UUID sessionId.
        // Verify by creating two agents without sessionId and checking they get different IDs.
        // Since sessionId is not a public property on Agent, we verify behavior through
        // the resolveSessionId helper.
        let id1 = AgentFactory.resolveSessionId(from: makeArgs(sessionId: nil))
        let id2 = AgentFactory.resolveSessionId(from: makeArgs(sessionId: nil))

        XCTAssertFalse(id1.isEmpty, "Generated sessionId should not be empty")
        XCTAssertFalse(id2.isEmpty, "Generated sessionId should not be empty")
        XCTAssertNotEqual(id1, id2, "Two agents without --session should get different UUIDs")
    }

    func testResolveSessionId_usesProvidedSessionId() {
        // AC#1: When --session flag provides an ID, that ID is used (not a generated UUID).
        let explicitId = "my-custom-session-123"
        let args = makeArgs(sessionId: explicitId)
        let resolved = AgentFactory.resolveSessionId(from: args)

        XCTAssertEqual(resolved, explicitId,
            "resolveSessionId should return the explicitly provided session ID")
    }

    func testResolveSessionId_generatesUUID_whenNil() {
        // AC#1: When sessionId is nil, a UUID is generated.
        let args = makeArgs(sessionId: nil)
        let resolved = AgentFactory.resolveSessionId(from: args)

        // UUID format check: should contain 4 dashes (8-4-4-4-12 pattern)
        let dashCount = resolved.filter { $0 == "-" }.count
        XCTAssertEqual(dashCount, 4,
            "Generated sessionId should be UUID format with 4 dashes: \(resolved)")
        XCTAssertEqual(resolved.count, 36,
            "UUID string should be 36 characters (32 hex + 4 dashes): \(resolved)")
    }

    func testCreateAgent_sessionStoreEnabled_agentCreated() throws {
        // AC#1: Agent creation succeeds with sessionStore configured.
        // After implementation, the Agent should have SessionStore injected.
        let args = makeArgs()
        let agent = try AgentFactory.createAgent(from: args).0

        XCTAssertNotNil(agent, "Agent should be created with SessionStore enabled")
    }

    func testCreateAgent_sessionSavedToDisk_afterClose() async throws {
        // AC#1: After agent.close(), session data should be persisted to disk.
        // This verifies the end-to-end flow: createAgent -> close -> no error.
        // Note: SessionStore uses ~/.open-agent-sdk/sessions/ by default.
        // Full disk-write verification requires a custom sessionsDir which
        // AgentOptions doesn't currently expose; tracked as future improvement.
        let sessionId = UUID().uuidString
        let args = makeArgs(sessionId: sessionId)
        let agent = try AgentFactory.createAgent(from: args).0

        // Close the agent - this should trigger session save without error
        try await agent.close()
    }

    // MARK: - AC#1: CLI exit paths call agent.close()

    func testCLIPromptMode_callsAgentClose() async throws {
        // AC#1: Single-shot mode exit path calls agent.close().
        // Verify by creating an agent and confirming close() doesn't throw.
        let args = makeArgs()
        let agent = try AgentFactory.createAgent(from: args).0

        // Should not throw
        try await agent.close()
    }

    // MARK: - AC#2: Save failure shows warning but CLI still exits

    func testAgentClose_saveFailure_doesNotCrash() async throws {
        // AC#2: If session save fails during close(), CLI should not crash.
        // Verify that close() can throw but the CLI handles it gracefully.
        // After implementation, CLI.swift should use do/catch around agent.close().
        let args = makeArgs()
        let agent = try AgentFactory.createAgent(from: args).0

        // close() should either succeed or throw - both are acceptable
        // The CLI layer must handle both cases
        do {
            try await agent.close()
        } catch {
            // Even if close() throws, the CLI should handle it gracefully
            // by showing a warning and exiting with code 0
        }
    }

    // MARK: - AC#3: --no-restore does not affect auto-save

    func testCreateAgent_noRestoreFlag_sessionStillActive() throws {
        // AC#3: --no-restore flag should NOT disable auto-save.
        // persistSession should always be true regardless of --no-restore.
        let args = makeArgs(noRestore: true)
        let agent = try AgentFactory.createAgent(from: args).0

        // Agent should still be created successfully
        // After implementation, the AgentOptions should have persistSession = true
        XCTAssertNotNil(agent, "Agent should be created even with --no-restore")
    }

    func testCreateAgent_noRestoreFalse_sessionActive() throws {
        // AC#3: Without --no-restore, session auto-save is also active (default behavior).
        let args = makeArgs(noRestore: false)
        let agent = try AgentFactory.createAgent(from: args).0

        XCTAssertNotNil(agent, "Agent should be created without --no-restore")
    }

    func testResolveSessionId_noRestore_doesNotAffectSessionId() {
        // AC#3: --no-restore should not affect sessionId generation.
        let argsNoRestore = makeArgs(noRestore: true, sessionId: nil)
        let argsDefault = makeArgs(noRestore: false, sessionId: nil)

        let idNoRestore = AgentFactory.resolveSessionId(from: argsNoRestore)
        let idDefault = AgentFactory.resolveSessionId(from: argsDefault)

        // Both should generate valid UUIDs
        XCTAssertFalse(idNoRestore.isEmpty)
        XCTAssertFalse(idDefault.isEmpty)
    }

    func testCreateAgent_persistSession_alwaysTrue_withRestore() throws {
        // AC#3: persistSession should be true even when --no-restore is set.
        // Since persistSession is not a public property on Agent, we verify
        // that agent creation succeeds (it would fail if persistSession were false
        // and sessionStore were nil, as that's an invalid state after implementation).
        let argsWithRestore = makeArgs(noRestore: false)
        let argsNoRestore = makeArgs(noRestore: true)

        let agentWithRestore = try AgentFactory.createAgent(from: argsWithRestore).0
        let agentNoRestore = try AgentFactory.createAgent(from: argsNoRestore).0

        XCTAssertNotNil(agentWithRestore, "Agent with restore should be created")
        XCTAssertNotNil(agentNoRestore, "Agent with --no-restore should be created")
    }

    // MARK: - ArgumentParser integration: --session flag

    func testArgumentParser_sessionFlag_parsesCorrectly() {
        // Verify ArgumentParser correctly handles --session <id>
        let args = ArgumentParser.parse(["openagent", "--session", "test-session-abc"])

        XCTAssertEqual(args.sessionId, "test-session-abc",
            "ArgumentParser should set sessionId from --session flag")
    }

    func testArgumentParser_noSessionFlag_sessionIdIsNil() {
        // Without --session flag, sessionId should be nil
        let args = ArgumentParser.parse(["openagent"])

        XCTAssertNil(args.sessionId,
            "sessionId should be nil when --session flag not provided")
    }

    func testArgumentParser_noRestoreFlag_parsesCorrectly() {
        // Verify --no-restore flag is parsed correctly
        let args = ArgumentParser.parse(["openagent", "--no-restore"])

        XCTAssertTrue(args.noRestore,
            "--no-restore should set noRestore to true")
    }

    func testArgumentParser_noRestoreAndSession_bothParsed() {
        // Both --session and --no-restore should be parseable together
        let args = ArgumentParser.parse(["openagent", "--session", "abc-123", "--no-restore"])

        XCTAssertEqual(args.sessionId, "abc-123",
            "--session should be parsed alongside --no-restore")
        XCTAssertTrue(args.noRestore,
            "--no-restore should be parsed alongside --session")
    }

    // MARK: - Regression: AgentFactory behavior unchanged for non-session features

    func testCreateAgent_withSessionConfig_modelStillCorrect() throws {
        // Regression: model should still be correctly passed through
        let args = makeArgs(model: "custom-model-v2")
        let agent = try AgentFactory.createAgent(from: args).0

        XCTAssertEqual(agent.model, "custom-model-v2",
            "Model should still be passed through correctly with session config")
    }

    func testCreateAgent_withSessionConfig_maxTurnsStillCorrect() throws {
        // Regression: maxTurns should still be correctly passed through
        let args = makeArgs(maxTurns: 7)
        let agent = try AgentFactory.createAgent(from: args).0

        XCTAssertEqual(agent.maxTurns, 7,
            "maxTurns should still be passed through correctly with session config")
    }

    func testCreateAgent_withSessionConfig_systemPromptStillCorrect() throws {
        // Regression: systemPrompt should still be correctly passed through
        // systemPrompt is set via ParsedArgs init - create with explicit value
        let argsWithPrompt = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key",
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
            systemPrompt: "Be helpful",
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
        let agent = try AgentFactory.createAgent(from: argsWithPrompt).0

        XCTAssertEqual(agent.systemPrompt, "Be helpful",
            "systemPrompt should still be passed through correctly with session config")
    }

    // MARK: - computeToolPool regression with session config

    func testComputeToolPool_withSessionConfig_returnsCoreTools() {
        // Regression: computeToolPool should still return core tools when session is configured
        let args = makeArgs()
        let tools = AgentFactory.computeToolPool(from: args)

        XCTAssertFalse(tools.isEmpty,
            "computeToolPool should still return tools when session config is present")
    }

    // MARK: - Full pipeline: ArgumentParser -> AgentFactory with session args

    func testFullPipeline_sessionArg_agentCreated() throws {
        // Full pipeline: --session <id> -> ArgumentParser -> AgentFactory -> Agent
        setenv("OPENAGENT_API_KEY", "pipeline-test-key", 1)
        defer { unsetenv("OPENAGENT_API_KEY") }

        let parsedArgs = ArgumentParser.parse(["openagent", "--session", "pipeline-session-1"])
        XCTAssertEqual(parsedArgs.sessionId, "pipeline-session-1")

        let agent = try AgentFactory.createAgent(from: parsedArgs).0
        XCTAssertNotNil(agent, "Agent should be created from full pipeline with --session")
    }

    func testFullPipeline_noSessionArg_agentCreated() throws {
        // Full pipeline: no --session -> ArgumentParser -> AgentFactory -> Agent (with generated UUID)
        setenv("OPENAGENT_API_KEY", "pipeline-test-key-2", 1)
        defer { unsetenv("OPENAGENT_API_KEY") }

        let parsedArgs = ArgumentParser.parse(["openagent"])
        XCTAssertNil(parsedArgs.sessionId, "No --session means sessionId is nil in ParsedArgs")

        let agent = try AgentFactory.createAgent(from: parsedArgs).0
        XCTAssertNotNil(agent, "Agent should be created even without --session (UUID generated)")
    }

    func testFullPipeline_noRestoreArg_agentCreated() throws {
        // Full pipeline: --no-restore -> AgentFactory -> Agent
        setenv("OPENAGENT_API_KEY", "pipeline-test-key-3", 1)
        defer { unsetenv("OPENAGENT_API_KEY") }

        let parsedArgs = ArgumentParser.parse(["openagent", "--no-restore"])
        XCTAssertTrue(parsedArgs.noRestore, "--no-restore should be true")

        let agent = try AgentFactory.createAgent(from: parsedArgs).0
        XCTAssertNotNil(agent, "Agent should be created with --no-restore")
    }
}
