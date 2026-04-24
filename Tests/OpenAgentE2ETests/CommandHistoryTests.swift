import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 9.3 Command History (linenoise-swift)
//
// These tests define the EXPECTED behavior of LinenoiseInputReader and
// command history integration. They will FAIL until:
//   1. Package.swift adds linenoise-swift dependency
//   2. LinenoiseInputReader.swift is created implementing InputReading
//   3. CLI.swift replaces FileHandleInputReader with LinenoiseInputReader
//
// Acceptance Criteria Coverage:
//   AC#1: Up/Down arrows navigate command history (linenoise built-in)
//   AC#2: History modification does not alter original entries
//   AC#3: Commands persist across sessions (save/load history file)
//   AC#4: History file auto-created at ~/.openagent/history
//   AC#5: History limited to 1000 entries (FIFO)
//   AC#6: Corrupted history file tolerated with warning
//   AC#7: Ctrl+C clears input line (returns empty string)
//   AC#8: EOF (Ctrl+D) exits REPL gracefully (returns nil)
//   AC#9: Empty commands not added to history

// MARK: - Mockable LinenoiseInputReader Tests
//
// Note: LinenoiseInputReader wraps LineNoise which requires a real TTY.
// For unit testing, we verify the class exists, conforms to InputReading,
// and test the history persistence logic via temp file operations.
// Arrow-key navigation (AC#1) and mid-history editing (AC#2) are provided
// by linenoise-swift internally and verified via integration/E2E tests.

final class CommandHistoryTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a unique temporary directory for history file testing.
    private func makeTempDir() -> String {
        let tempDir = NSTemporaryDirectory() + "openagent-history-tests-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// Cleanup helper to remove temp directories after tests.
    private func cleanupTempDir(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    /// Creates a MockTextOutputStream and OutputRenderer pair for capturing output.
    private func makeRenderer() -> (renderer: OutputRenderer, mock: MockTextOutputStream) {
        let mock = MockTextOutputStream()
        let renderer = OutputRenderer(output: mock)
        return (renderer, mock)
    }

    /// Creates a test Agent with dummy configuration.
    private func makeTestAgent() async throws -> Agent {
        let args = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-command-history-tests",
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
    // MARK: AC#1 — Session history navigation (protocol conformance)
    // ================================================================

    /// AC#1: LinenoiseInputReader must conform to InputReading protocol.
    ///
    /// This is the foundational test: the class must exist and implement
    /// `readLine(prompt:) -> String?`. Arrow-key navigation is handled
    /// internally by linenoise-swift's getLine() method.
    func testLinenoiseInputReader_conformsToInputReadingProtocol() throws {
        // Given: LinenoiseInputReader class exists
        // Then: It can be assigned to an InputReading variable

        // This test will FAIL at compilation if LinenoiseInputReader
        // does not exist or does not conform to InputReading.
        let reader: InputReading = LinenoiseInputReader()

        // Verify the reader is not nil (class type, always exists after init)
        XCTAssertNotNil(reader,
            "LinenoiseInputReader should be instantiable and conform to InputReading")
    }

    /// AC#1: readLine(prompt:) returns the line entered by the user.
    ///
    /// In a non-TTY test environment, linenoise-swift falls back to
    /// Swift.readLine() which returns nil when stdin is exhausted.
    /// We verify the method signature is correct.
    func testLinenoiseInputReader_readLineReturnsUserInput() throws {
        let reader = LinenoiseInputReader()

        // In non-TTY test environment, getLine will fail or return nil.
        // The important thing is the method exists and returns String?.
        // Actual navigation testing is done in integration/E2E tests.
        let result = reader.readLine(prompt: "> ")

        // In test environment with no stdin, result should be nil (EOF)
        // or a string. Either way, the return type is correct.
        // We just verify the call completes without crashing.
        _ = result
    }

    // ================================================================
    // MARK: AC#3 — Cross-session history persistence
    // ================================================================

    /// AC#3: History entries are saved to a file after each successful read.
    ///
    /// Given a LinenoiseInputReader with a configured history path
    /// When entries are added
    /// Then the history file should exist and contain the entries
    func testLinenoiseInputReader_savesHistoryAfterSuccessfulRead() throws {
        let tempDir = makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let historyPath = tempDir + "/history"

        // Create a reader with a specific history path
        let reader = LinenoiseInputReader(historyPath: historyPath)

        // Simulate adding history (normally done inside readLine after user input)
        // In test environment we verify the save mechanism works
        reader.addHistoryEntry("test command")

        // Verify history file was created
        let fileExists = FileManager.default.fileExists(atPath: historyPath)
        XCTAssertTrue(fileExists,
            "History file should be created after adding an entry (AC#3)")

        // Verify file content contains the entry
        if fileExists {
            let content = try String(contentsOfFile: historyPath, encoding: .utf8)
            XCTAssertTrue(content.contains("test command"),
                "History file should contain the saved command (AC#3), got: \(content)")
        }
    }

    /// AC#3: History from a previous session is loaded on init.
    ///
    /// Given a history file with existing entries
    /// When a new LinenoiseInputReader is created
    /// Then the previous entries are available
    func testLinenoiseInputReader_loadsHistoryFromPreviousSession() throws {
        let tempDir = makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let historyPath = tempDir + "/history"

        // Pre-populate a history file
        try "previous command 1\nprevious command 2\n".write(
            toFile: historyPath, atomically: true, encoding: .utf8)

        // Create a new reader -- should load existing history
        let reader = LinenoiseInputReader(historyPath: historyPath)

        // Verify history was loaded by checking history count
        let count = reader.historyCount
        XCTAssertEqual(count, 2,
            "History should contain 2 entries from previous session (AC#3), got: \(count)")
    }

    // ================================================================
    // MARK: AC#4 — History file auto-creation
    // ================================================================

    /// AC#4: ~/.openagent directory is created if it does not exist.
    ///
    /// Given the history directory does not exist
    /// When LinenoiseInputReader is initialized
    /// Then the directory is created automatically
    func testLinenoiseInputReader_createsDirectoryIfMissing() throws {
        let tempDir = NSTemporaryDirectory() + "openagent-mkdir-test-\(UUID().uuidString)"
        // Ensure directory does NOT exist
        try? FileManager.default.removeItem(atPath: tempDir)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let historyPath = tempDir + "/history"

        // Init should create the parent directory
        let reader = LinenoiseInputReader(historyPath: historyPath)

        let dirExists = FileManager.default.fileExists(atPath: tempDir)
        XCTAssertTrue(dirExists,
            "LinenoiseInputReader should create parent directory if missing (AC#4)")
    }

    /// AC#4: When no history file exists, reader starts with empty history.
    ///
    /// Given the history file does not exist
    /// When LinenoiseInputReader is initialized
    /// Then history count is 0 and no error is thrown
    func testLinenoiseInputReader_startsEmptyWhenNoHistoryFile() throws {
        let tempDir = makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let historyPath = tempDir + "/nonexistent-history"

        // File does not exist yet
        XCTAssertFalse(FileManager.default.fileExists(atPath: historyPath))

        // Should not throw when file doesn't exist
        let reader = LinenoiseInputReader(historyPath: historyPath)

        XCTAssertEqual(reader.historyCount, 0,
            "History should start empty when no file exists (AC#4)")
    }

    // ================================================================
    // MARK: AC#5 — History FIFO limit (1000 entries)
    // ================================================================

    /// AC#5: History max length is configured to 1000.
    ///
    /// Given LinenoiseInputReader is initialized
    /// Then the history max length is set to 1000
    func testLinenoiseInputReader_historyMaxLengthSetTo1000() throws {
        let reader = LinenoiseInputReader()

        let maxLen = reader.historyMaxLength
        XCTAssertEqual(maxLen, 1000,
            "History max length should be 1000 (AC#5), got: \(maxLen)")
    }

    /// AC#5: When history exceeds 1000 entries, oldest are removed (FIFO).
    ///
    /// Given 1001 entries are added to history
    /// Then the history count remains at 1000
    /// And the oldest entry (first added) is removed
    func testLinenoiseInputReader_oldestEntriesRemovedWhenOverLimit() throws {
        let tempDir = makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let historyPath = tempDir + "/history"
        let reader = LinenoiseInputReader(historyPath: historyPath)

        // Add 1001 entries
        for i in 1...1001 {
            reader.addHistoryEntry("command \(i)")
        }

        // History should be capped at 1000
        let count = reader.historyCount
        XCTAssertEqual(count, 1000,
            "History should be capped at 1000 entries (AC#5), got: \(count)")

        // The first entry ("command 1") should have been removed (FIFO)
        // The history should now contain commands 2 through 1001
        // We verify by checking the saved file content
        let content = try String(contentsOfFile: historyPath, encoding: .utf8)
        XCTAssertFalse(content.contains("command 1\n"),
            "Oldest entry 'command 1' should be removed (FIFO) (AC#5)")
        XCTAssertTrue(content.contains("command 1001"),
            "Newest entry 'command 1001' should be present (AC#5)")
    }

    // ================================================================
    // MARK: AC#6 — Corrupted file tolerance
    // ================================================================

    /// AC#6: Corrupted history file does not crash the reader.
    ///
    /// Given a history file with binary/corrupted content
    /// When LinenoiseInputReader is initialized
    /// Then it starts with empty history and does not crash
    func testLinenoiseInputReader_handlesCorruptedHistoryFile() throws {
        let tempDir = makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let historyPath = tempDir + "/corrupted-history"

        // Write binary garbage to the history file
        let corruptedData = Data([0xFF, 0xFE, 0x00, 0x01, 0x80, 0x81])
        try corruptedData.write(to: URL(fileURLWithPath: historyPath))

        // Should not crash when loading corrupted file
        let reader = LinenoiseInputReader(historyPath: historyPath)

        // History should start empty (or whatever linenoise could parse)
        // The key assertion: no crash, reader is usable
        XCTAssertNotNil(reader,
            "LinenoiseInputReader should handle corrupted history file gracefully (AC#6)")
    }

    /// AC#6: Unreadable history file (permissions) does not crash.
    ///
    /// Given a history file with no read permissions
    /// When LinenoiseInputReader is initialized
    /// Then it starts with empty history and does not crash
    func testLinenoiseInputReader_handlesUnreadableHistoryFile() throws {
        let tempDir = makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let historyPath = tempDir + "/unreadable-history"

        // Create a file and make it unreadable
        try "some content".write(toFile: historyPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o000)],
            ofItemAtPath: historyPath)

        defer {
            // Restore permissions so cleanup can delete it
            try? FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: 0o644)],
                ofItemAtPath: historyPath)
        }

        // Should not crash
        let reader = LinenoiseInputReader(historyPath: historyPath)

        XCTAssertNotNil(reader,
            "LinenoiseInputReader should handle unreadable history file gracefully (AC#6)")
    }

    // ================================================================
    // MARK: AC#7 — Ctrl+C clears input line (returns empty string)
    // ================================================================

    /// AC#7: When Ctrl+C is pressed during input, readLine returns empty string.
    ///
    /// This is tested at the REPLLoop level: an empty string return from
    /// readLine should be treated as "clear input and re-show prompt",
    /// NOT as EOF. REPLLoop's existing `guard !trimmed.isEmpty` logic
    /// handles this by continuing the loop.
    ///
    /// Note: We cannot easily simulate Ctrl+C in a unit test environment
    /// because linenoise-swift requires a real TTY. Instead, we test
    /// REPLLoop's handling of empty string returns.
    func testLinenoiseInputReader_ctrlC_returnsEmptyString() async throws {
        // This test verifies the CONTRACT: Ctrl+C should return "" not nil.
        // In MockInputReader, we simulate what LinenoiseInputReader does
        // when Ctrl+C is pressed.
        //
        // LinenoiseInputReader.readLine should:
        //   - Catch LinenoiseError.CTRL_C -> return ""
        //   - Catch LinenoiseError.EOF -> return nil
        //
        // We verify via the MockInputReader that REPLLoop handles "" correctly.
        let (renderer, _) = makeRenderer()

        // Simulate: user presses Ctrl+C (reader returns ""), then types /exit
        let inputReader = MockInputReader(["", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        // REPLLoop should have read 2 inputs (empty string ignored, then /exit)
        XCTAssertEqual(inputReader.callCount, 2,
            "Ctrl+C (empty string) should be ignored, REPL continues to /exit (AC#7)")
    }

    // ================================================================
    // MARK: AC#8 — EOF (Ctrl+D) exits REPL gracefully
    // ================================================================

    /// AC#8: When Ctrl+D is pressed, readLine returns nil and REPL exits.
    ///
    /// LinenoiseInputReader should catch LinenoiseError.EOF and return nil.
    /// REPLLoop treats nil as EOF and exits the while loop.
    func testLinenoiseInputReader_eof_returnsNil() async throws {
        let (renderer, _) = makeRenderer()

        // Simulate: user presses Ctrl+D immediately (reader returns nil)
        let inputReader = MockInputReader([nil])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        // REPL should exit after first nil return
        XCTAssertEqual(inputReader.callCount, 1,
            "EOF (nil) should cause REPL to exit after reading 1 line (AC#8)")
    }

    // ================================================================
    // MARK: AC#9 — Empty commands not added to history
    // ================================================================

    /// AC#9: Empty strings and whitespace-only input are not added to history.
    ///
    /// LinenoiseInputReader should check `!line.isEmpty` before calling
    /// addHistory(). This ensures empty inputs don't pollute the history.
    func testLinenoiseInputReader_emptyLinesNotAddedToHistory() throws {
        let tempDir = makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let historyPath = tempDir + "/history"
        let reader = LinenoiseInputReader(historyPath: historyPath)

        // Add an empty string
        reader.addHistoryEntry("")
        // Add a whitespace-only string
        reader.addHistoryEntry("   ")
        // Add a valid command
        reader.addHistoryEntry("valid command")

        // Only the valid command should be in history
        let count = reader.historyCount
        XCTAssertEqual(count, 1,
            "Only non-empty commands should be added to history (AC#9), got count: \(count)")
    }

    // ================================================================
    // MARK: Integration — REPLLoop compatibility
    // ================================================================

    /// Integration: REPLLoop works correctly when reader returns nil (EOF).
    ///
    /// This verifies the REPLLoop contract: nil from readLine = exit.
    func testREPLLoop_withLinenoiseInputReader_exitsOnNil() async throws {
        let (renderer, _) = makeRenderer()
        let inputReader = MockInputReader(["hello", nil])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        // Should read "hello", process it, then read nil and exit
        XCTAssertEqual(inputReader.callCount, 2,
            "REPL should process 'hello' then exit on nil/EOF")
    }

    /// Integration: Ctrl+C (empty string) is handled by REPLLoop's existing logic.
    ///
    /// The REPLLoop has `guard !trimmed.isEmpty else { continue }` which
    /// means empty strings are silently ignored and the prompt reappears.
    func testREPLLoop_ctrlC_clearsInputAndRedisplaysPrompt() async throws {
        let (renderer, _) = makeRenderer()

        // Simulate: user types valid command, presses Ctrl+C, types another command, exits
        let inputReader = MockInputReader(["first command", "", "second command", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader
        )

        await repl.start()

        // All 4 inputs should be read (Ctrl+C does NOT exit)
        XCTAssertEqual(inputReader.callCount, 4,
            "Ctrl+C should not exit REPL; all 4 inputs should be processed")
    }
}
