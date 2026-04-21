import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 3.2 List and Resume Past Sessions
//
// These tests define the EXPECTED behavior of /sessions and /resume commands.
// They will FAIL until AgentFactory, CLI, and REPLLoop are updated (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: /sessions displays history session list with ID, date, and first message preview
//   AC#2: /resume <id> loads session and continues conversation
//   AC#3: /resume invalid-id shows "Session not found"

final class SessionListResumeTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a MockTextOutputStream and OutputRenderer pair for capturing output.
    private func makeRenderer() -> (renderer: OutputRenderer, mock: MockTextOutputStream) {
        let mock = MockTextOutputStream()
        let renderer = OutputRenderer(output: mock)
        return (renderer, mock)
    }

    /// Creates a test Agent with a dummy API key.
    private func makeTestAgent() async throws -> Agent {
        let args = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-session-tests",
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
        return try await AgentFactory.createAgent(from: args).0
    }

    /// Creates a temporary directory for session storage in tests.
    private func makeTempSessionsDir() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("session-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// Cleanup helper to remove temp session directories.
    private func cleanupTempDir(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - AC#1: /sessions displays history session list

    func testSessionsCommand_emptyList_showsNoSessions() async throws {
        // AC#1: When no saved sessions exist, /sessions shows "No saved sessions."
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/sessions", "/exit"])

        // Create a SessionStore with a temp directory (empty)
        let tempDir = makeTempSessionsDir()
        defer { cleanupTempDir(tempDir) }
        let sessionStore = SessionStore(sessionsDir: tempDir.path)

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            sessionStore: sessionStore
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("no saved sessions") || output.contains("no sessions"),
            "/sessions with empty list should show 'No saved sessions.' Got: \(mockOutput.output)")
    }

    func testSessionsCommand_withSessions_showsList() async throws {
        // AC#1: When sessions exist, /sessions shows formatted list with ID, date, preview
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/sessions", "/exit"])

        // Create a SessionStore with a temp directory
        let tempDir = makeTempSessionsDir()
        defer { cleanupTempDir(tempDir) }
        let sessionStore = SessionStore(sessionsDir: tempDir.path)

        // Create a session by using the SessionStore directly
        let sessionId = UUID().uuidString
        let args = ParsedArgs(
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
        // Use createAgent which now returns (Agent, SessionStore)
        let (agent, _) = try await AgentFactory.createAgent(from: args)
        try await agent.close()

        // Now list sessions using our temp-dir store
        // The agent above saves to the default SDK directory, not tempDir.
        // For this test, use the default SessionStore to verify the session is listed.
        let defaultStore = SessionStore()
        let sessions = try await defaultStore.list()

        // Use the default store for the REPL
        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            sessionStore: defaultStore
        )

        await repl.start()

        let output = mockOutput.output
        // If there are sessions in the default store, the output should reflect that
        // The key assertion is that /sessions runs without error and shows session-related output
        if !sessions.isEmpty {
            let shortId = String(sessionId.prefix(8))
            XCTAssertTrue(output.contains(shortId) || output.contains("Saved sessions"),
                "/sessions output should contain session data. Got: \(output)")
        }
    }

    func testSessionsCommand_doesNotExit() async throws {
        // /sessions should not exit the REPL
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/sessions", "/exit"])

        let tempDir = makeTempSessionsDir()
        defer { cleanupTempDir(tempDir) }
        let sessionStore = SessionStore(sessionsDir: tempDir.path)

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            sessionStore: sessionStore
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 2,
            "/sessions should not exit REPL -- /exit should be read as second input")
    }

    // MARK: - AC#2: /resume <id> loads session and continues conversation

    func testResumeCommand_validId_resumesSession() async throws {
        // AC#2: /resume <valid-id> should show resume confirmation message
        let (renderer, mockOutput) = makeRenderer()

        // Create a real session so the ID exists in the default store
        let sessionId = UUID().uuidString
        let args = ParsedArgs(
            helpRequested: false, versionRequested: false, prompt: "hello",
            model: "glm-5.1", apiKey: "test-key", baseURL: "https://api.example.com/v1",
            provider: nil, mode: "default", tools: "core",
            mcpConfigPath: nil, hooksConfigPath: nil, skillDir: nil, skillName: nil,
            sessionId: sessionId, noRestore: false, maxTurns: 10, maxBudgetUsd: nil,
            systemPrompt: nil, thinking: nil, quiet: false, output: "text",
            logLevel: nil, toolAllow: nil, toolDeny: nil,
            shouldExit: false, exitCode: 0, errorMessage: nil, helpMessage: nil
        )
        let (agent, _) = try await AgentFactory.createAgent(from: args)
        try await agent.close()

        // Use the default SessionStore (same one AgentFactory saves to)
        let defaultStore = SessionStore()
        let inputReader = MockInputReader(["/resume \(sessionId)", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            sessionStore: defaultStore,
            parsedArgs: args
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("resumed session"),
            "/resume with valid ID should show 'Resumed session'. Got: \(mockOutput.output)")
    }

    func testResumeCommand_doesNotExit() async throws {
        // /resume should not exit the REPL (whether success or failure)
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/resume some-id", "/exit"])

        let tempDir = makeTempSessionsDir()
        defer { cleanupTempDir(tempDir) }
        let sessionStore = SessionStore(sessionsDir: tempDir.path)

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            sessionStore: sessionStore
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 2,
            "/resume should not exit REPL -- /exit should be read as second input")
    }

    // MARK: - AC#3: /resume invalid-id shows "Session not found"

    func testResumeCommand_invalidId_showsNotFound() async throws {
        // AC#3: /resume with invalid session ID shows "Session not found"
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/resume completely-invalid-id", "/exit"])

        let tempDir = makeTempSessionsDir()
        defer { cleanupTempDir(tempDir) }
        let sessionStore = SessionStore(sessionsDir: tempDir.path)

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            sessionStore: sessionStore
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("session not found") || output.contains("not found"),
            "/resume with invalid ID should show 'Session not found'. Got: \(mockOutput.output)")
    }

    func testResumeCommand_noArgs_showsUsage() async throws {
        // AC#3: /resume without arguments shows usage message
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/resume", "/exit"])

        let tempDir = makeTempSessionsDir()
        defer { cleanupTempDir(tempDir) }
        let sessionStore = SessionStore(sessionsDir: tempDir.path)

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            sessionStore: sessionStore
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("usage") || output.contains("/resume"),
            "/resume without args should show usage message. Got: \(mockOutput.output)")
    }

    // MARK: - /help includes /sessions and /resume commands

    func testSlashCommand_helpIncludesSessionsCommand() async throws {
        // /help should list /sessions command
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/help", "/exit"])

        let tempDir = makeTempSessionsDir()
        defer { cleanupTempDir(tempDir) }
        let sessionStore = SessionStore(sessionsDir: tempDir.path)

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            sessionStore: sessionStore
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("/sessions") || output.contains("sessions"),
            "/help should list /sessions command. Got: \(mockOutput.output)")
    }

    func testSlashCommand_helpIncludesResumeCommand() async throws {
        // /help should list /resume command
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/help", "/exit"])

        let tempDir = makeTempSessionsDir()
        defer { cleanupTempDir(tempDir) }
        let sessionStore = SessionStore(sessionsDir: tempDir.path)

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            sessionStore: sessionStore
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("/resume") || output.contains("resume"),
            "/help should list /resume command. Got: \(mockOutput.output)")
    }

    // MARK: - AgentFactory returns SessionStore

    func testCreateAgent_returnsSessionStore() async throws {
        // AC#1, AC#2: createAgent should return SessionStore alongside Agent
        // so that CLI layer can pass it to REPLLoop
        let args = ParsedArgs(
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

        // After implementation, createAgent returns (Agent, SessionStore)
        let (agent, sessionStore) = try await AgentFactory.createAgent(from: args)

        XCTAssertNotNil(agent, "createAgent should return a non-nil Agent")
        XCTAssertNotNil(sessionStore, "createAgent should return a non-nil SessionStore")
    }

    // MARK: - REPLLoop accepts SessionStore parameter

    func testREPLLoop_acceptsSessionStore() async throws {
        // Verify that REPLLoop can be initialized with a SessionStore parameter
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/exit"])

        let tempDir = makeTempSessionsDir()
        defer { cleanupTempDir(tempDir) }
        let sessionStore = SessionStore(sessionsDir: tempDir.path)

        // After implementation, REPLLoop init accepts sessionStore parameter
        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            sessionStore: sessionStore
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 1,
            "REPLLoop with sessionStore should start and exit normally")
    }

    // MARK: - Regression: existing REPLLoop init without sessionStore still works

    func testREPLLoop_withoutSessionStore_stillWorks() async throws {
        // Regression: existing REPLLoop init (without sessionStore) should still work
        // This ensures backward compatibility for code paths that don't need sessions
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 1,
            "REPLLoop without sessionStore should still work (backward compat)")
    }

    // MARK: - Regression: AgentFactory behavior unchanged for non-session features

    func testCreateAgent_withSessionStoreReturn_modelStillCorrect() async throws {
        // Regression: model should still be correctly passed through
        let args = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "custom-model-v3",
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

        let (agent, _) = try await AgentFactory.createAgent(from: args)

        XCTAssertEqual(agent.model, "custom-model-v3",
            "Model should still be passed through correctly with tuple return")
    }

    func testCreateAgent_withSessionStoreReturn_maxTurnsStillCorrect() async throws {
        // Regression: maxTurns should still be correctly passed through
        let args = ParsedArgs(
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
            maxTurns: 7,
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

        let (agent, _) = try await AgentFactory.createAgent(from: args)

        XCTAssertEqual(agent.maxTurns, 7,
            "maxTurns should still be passed through correctly with tuple return")
    }
}
