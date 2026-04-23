import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 7.5 Session Fork
//
// These tests define the EXPECTED behavior of the /fork command.
// They will FAIL until REPLLoop.swift is updated with /fork handling (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: /fork creates a new branched session from current conversation state
//   AC#2: New session has independent subsequent history (agent switched)
//   AC#3: Confirmation shows new session short ID and "Session forked" message
//   AC#4: SessionStore nil shows "No session storage available."
//   AC#5: sessionId nil shows "No active session to fork."
//   AC#6: SessionStore.fork() error shows error message, original session unaffected

final class SessionForkTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a MockTextOutputStream and OutputRenderer pair for capturing output.
    private func makeRenderer() -> (renderer: OutputRenderer, mock: MockTextOutputStream) {
        let mock = MockTextOutputStream()
        let renderer = OutputRenderer(output: mock)
        return (renderer, mock)
    }

    /// Creates a test Agent with a dummy API key (no session ID).
    private func makeTestAgent() async throws -> Agent {
        let args = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-fork-tests",
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

    /// Creates a test Agent with a specific session ID.
    private func makeTestAgent(sessionId: String) async throws -> Agent {
        let args = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-fork-tests",
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

    /// Creates a temporary directory for session storage in tests.
    private func makeTempSessionsDir() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fork-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// Cleanup helper to remove temp session directories.
    private func cleanupTempDir(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - AC#1, #2, #3: Successful fork displays confirmation with short ID

    func testFork_success_displaysConfirmation() async throws {
        // AC#1: /fork creates a new branched session from current state
        // AC#2: Agent is switched to new forked session
        // AC#3: Confirmation shows short ID and "Session forked" message
        let (renderer, mockOutput) = makeRenderer()

        // Create a session that can be forked
        let sessionId = UUID().uuidString

        // Create agent with sessionId and save it so the session exists on disk
        // Use the default SessionStore (same one AgentFactory saves to)
        let args = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-fork-tests",
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
        let (agent, _, _) = try await AgentFactory.createAgent(from: args)
        try await agent.close()

        // Use the default SessionStore (same one AgentFactory saves to)
        let sessionStore = SessionStore()
        let inputReader = MockInputReader(["/fork", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(sessionId: sessionId),
            renderer: renderer,
            reader: inputReader,
            sessionStore: sessionStore,
            parsedArgs: args
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("session forked"),
            "/fork should show 'Session forked' confirmation (AC#3). Got: \(mockOutput.output)")
        // Verify the output contains a short ID (at least some alphanumeric after "session:")
        // The forkedId is auto-generated by SessionStore.fork(), so we can't predict it,
        // but the output format is "Session forked. New session: <8chars>..."
        XCTAssertTrue(output.contains("new session"),
            "/fork output should say 'New session' with ID (AC#3). Got: \(mockOutput.output)")
    }

    // MARK: - AC#4: SessionStore nil shows error

    func testFork_noSessionStore_showsError() async throws {
        // AC#4: When SessionStore is nil, /fork shows "No session storage available."
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/fork", "/exit"])

        // REPLLoop without sessionStore (nil by default)
        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
            // sessionStore is nil by default
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("no session storage available"),
            "/fork with nil SessionStore should show 'No session storage available.' (AC#4). Got: \(mockOutput.output)")
    }

    // MARK: - AC#5: No active session shows error

    func testFork_noActiveSession_showsError() async throws {
        // AC#5: When sessionId is nil (no active session), /fork shows "No active session to fork."
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/fork", "/exit"])

        let tempDir = makeTempSessionsDir()
        defer { cleanupTempDir(tempDir) }
        let sessionStore = SessionStore(sessionsDir: tempDir.path)

        // Agent without sessionId -- getSessionId() returns nil
        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            sessionStore: sessionStore
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("no active session to fork"),
            "/fork with nil sessionId should show 'No active session to fork.' (AC#5). Got: \(mockOutput.output)")
    }

    // MARK: - AC#6: fork throws error shows error message

    func testFork_forkThrows_showsError() async throws {
        // AC#6: When SessionStore.fork() throws an error, show error message.
        // Original session is unaffected.
        //
        // Strategy: Create a session, then corrupt the storage so fork() throws.
        // Alternatively, fork with an out-of-range upToMessageIndex to trigger SDKError.
        // Since /fork in REPLLoop calls fork() without upToMessageIndex,
        // we need to cause a write failure. We can do this by making the sessions
        // directory read-only after saving the session.
        let (renderer, mockOutput) = makeRenderer()

        let sessionId = UUID().uuidString
        let tempDir = makeTempSessionsDir()
        let sessionStore = SessionStore(sessionsDir: tempDir.path)

        // Create and save a session so it exists
        let agent = try await makeTestAgent(sessionId: sessionId)
        try await agent.close()

        // Make the session directory read-only to cause fork to fail on write
        let sessionDir = tempDir.appendingPathComponent(sessionId)
        if FileManager.default.fileExists(atPath: sessionDir.path) {
            try FileManager.default.setAttributes(
                [FileAttributeKey.posixPermissions: 0o000],
                ofItemAtPath: sessionDir.path
            )
        }
        // Also make the temp dir read-only so fork cannot create new session dir
        try FileManager.default.setAttributes(
            [FileAttributeKey.posixPermissions: 0o444],
            ofItemAtPath: tempDir.path
        )

        defer {
            // Restore permissions for cleanup
            try? FileManager.default.setAttributes(
                [FileAttributeKey.posixPermissions: 0o755],
                ofItemAtPath: tempDir.path
            )
            try? FileManager.default.setAttributes(
                [FileAttributeKey.posixPermissions: 0o755],
                ofItemAtPath: sessionDir.path
            )
            cleanupTempDir(tempDir)
        }

        let args = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-fork-tests",
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

        let inputReader = MockInputReader(["/fork", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(sessionId: sessionId),
            renderer: renderer,
            reader: inputReader,
            sessionStore: sessionStore,
            parsedArgs: args
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("error") || output.contains("failed"),
            "/fork when fork() throws should show error message (AC#6). Got: \(mockOutput.output)")
    }

    // MARK: - AC#6: fork returns nil (source not found) shows error

    func testFork_forkReturnsNil_showsError() async throws {
        // AC#6 variant: When fork returns nil (source session doesn't exist),
        // show an error message.
        let (renderer, mockOutput) = makeRenderer()

        let tempDir = makeTempSessionsDir()
        defer { cleanupTempDir(tempDir) }
        let sessionStore = SessionStore(sessionsDir: tempDir.path)

        // Use a session ID that was never saved -- fork will return nil
        let bogusSessionId = "nonexistent-session-\(UUID().uuidString)"

        let args = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-fork-tests",
            baseURL: "https://api.example.com/v1",
            provider: nil,
            mode: "default",
            tools: "core",
            mcpConfigPath: nil,
            hooksConfigPath: nil,
            skillDir: nil,
            skillName: nil,
            sessionId: bogusSessionId,
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

        let inputReader = MockInputReader(["/fork", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(sessionId: bogusSessionId),
            renderer: renderer,
            reader: inputReader,
            sessionStore: sessionStore,
            parsedArgs: args
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("error") || output.contains("not found"),
            "/fork when source session not found should show error (AC#6). Got: \(mockOutput.output)")
    }

    // MARK: - /help includes /fork command (AC#1 discoverability)

    func testHelp_includesForkCommand() async throws {
        // /help should list /fork command
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
        XCTAssertTrue(output.contains("/fork") || output.contains("fork"),
            "/help should list /fork command. Got: \(mockOutput.output)")
    }

    // MARK: - /fork does not exit REPL

    func testFork_doesNotExit() async throws {
        // /fork should not exit the REPL (whether success or failure)
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["/fork", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
            // No sessionStore -- will show error but should not exit
        )

        await repl.start()

        XCTAssertEqual(inputReader.callCount, 2,
            "/fork should not exit REPL -- /exit should be read as second input")
    }
}
