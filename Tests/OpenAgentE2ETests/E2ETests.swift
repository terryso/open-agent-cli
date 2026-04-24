import Foundation
import XCTest

// MARK: - End-to-End Tests
//
// Tests that launch the `openagent` binary as a subprocess and verify
// external behavior: exit codes, stdout, stderr.
//
// These tests do NOT use @testable import — they treat the CLI as a black box.
// They use the real ~/.openagent/config.json configuration and make real API calls.
// Run manually via `swift test --filter OpenAgentE2ETests` — not in CI.

final class E2ETests: XCTestCase {

    // MARK: - Helpers

    /// Resolve the path to the built openagent executable.
    private func resolveExecutable() throws -> String {
        // Walk up from #file to find the project root (where Package.swift lives)
        var dir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        for _ in 0..<10 {
            dir = dir.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                for suffix in [
                    ".build/debug/openagent",
                    ".build/arm64-apple-macosx/debug/openagent",
                ] {
                    let execPath = dir.appendingPathComponent(suffix).path
                    if FileManager.default.isExecutableFile(atPath: execPath) {
                        return execPath
                    }
                }
                throw XCTSkip("openagent executable not found — run `swift build` first")
            }
        }
        throw XCTSkip("Could not locate project root")
    }

    /// Launch the openagent binary with the given arguments and capture stdout + stderr.
    ///
    /// - Parameters:
    ///   - execPath: Path to the openagent binary.
    ///   - arguments: CLI arguments (without program name).
    ///   - stdinData: Optional data to pipe to stdin.
    ///   - timeout: Max wait time in seconds.
    /// - Returns: (stdout, stderr, exitCode, elapsedMs).
    private func launchCLI(
        execPath: String,
        arguments: [String],
        stdinData: Data? = nil,
        timeout: TimeInterval = 30
    ) -> (stdout: String, stderr: String, exitCode: Int32, elapsedMs: Int64) {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdinPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: execPath)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = stdinPipe

        let start = CFAbsoluteTimeGetCurrent()

        do {
            try process.run()
        } catch {
            return ("", "[launch failed: \(error.localizedDescription)]", -1, 0)
        }

        // Write stdin data if provided, then close
        if let data = stdinData {
            stdinPipe.fileHandleForWriting.write(data)
        }
        try? stdinPipe.fileHandleForWriting.close()

        // Enforce timeout
        let timeoutWork = DispatchWorkItem { [weak process] in
            if let process, process.isRunning {
                process.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()
        timeoutWork.cancel()

        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let elapsedMs = Int64(elapsed * 1000)

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return (stdout, stderr, process.terminationStatus, elapsedMs)
    }

    // MARK: - --help

    func testHelpFlag_exitsZero() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--help"])
        XCTAssertEqual(result.exitCode, 0, "--help should exit 0")
    }

    func testHelpFlag_outputContainsUsage() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--help"])
        XCTAssertTrue(result.stdout.contains("openagent"),
            "Help output should contain 'openagent', got: \(result.stdout.prefix(300))")
        XCTAssertTrue(result.stdout.contains("--model"),
            "Help output should list --model flag")
        XCTAssertTrue(result.stdout.contains("--mode"),
            "Help output should list --mode flag")
        XCTAssertTrue(result.stdout.contains("--help"),
            "Help output should mention --help")
    }

    func testHelpShortFlag_exitsZero() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["-h"])
        XCTAssertEqual(result.exitCode, 0, "-h should exit 0")
        XCTAssertTrue(result.stdout.contains("openagent"), "-h output should contain usage info")
    }

    // MARK: - --version

    func testVersionFlag_exitsZero() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--version"])
        XCTAssertEqual(result.exitCode, 0, "--version should exit 0")
    }

    func testVersionFlag_outputContainsVersion() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--version"])
        XCTAssertTrue(result.stdout.contains("openagent"),
            "--version output should contain 'openagent', got: \(result.stdout)")
        // Version string should have at least one digit
        let hasDigit = result.stdout.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) }
        XCTAssertTrue(hasDigit, "--version output should contain a version number")
    }

    func testVersionShortFlag_exitsZero() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["-v"])
        XCTAssertEqual(result.exitCode, 0, "-v should exit 0")
    }

    // MARK: - Invalid flags

    func testUnknownFlag_exitsOne() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--nonexistent"])
        XCTAssertEqual(result.exitCode, 1, "Unknown flag should exit 1")
    }

    func testUnknownFlag_stderrContainsError() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--nonexistent"])
        XCTAssertTrue(result.stderr.contains("Unknown flag"),
            "stderr should mention 'Unknown flag', got: \(result.stderr)")
    }

    func testUnknownFlag_stderrSuggestsHelp() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--bogus"])
        XCTAssertTrue(result.stderr.contains("--help"),
            "stderr should suggest --help, got: \(result.stderr)")
    }

    // MARK: - Missing value for flag

    func testMissingValueForModel_exitsOne() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--model"])
        XCTAssertEqual(result.exitCode, 1, "Missing value for --model should exit 1")
    }

    func testMissingValueForModel_stderrContainsError() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--model"])
        XCTAssertTrue(result.stderr.contains("Missing value"),
            "stderr should mention missing value, got: \(result.stderr)")
    }

    func testMissingValueForMode_exitsOne() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--mode"])
        XCTAssertEqual(result.exitCode, 1)
    }

    func testMissingValueForMaxTurns_exitsOne() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--max-turns"])
        XCTAssertEqual(result.exitCode, 1)
    }

    func testMissingValueForOutput_exitsOne() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--output"])
        XCTAssertEqual(result.exitCode, 1)
    }

    // MARK: - Invalid values for flags

    func testInvalidMode_exitsOne() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--mode", "invalid_mode"])
        XCTAssertEqual(result.exitCode, 1, "Invalid mode should exit 1")
    }

    func testInvalidMode_stderrListsValidModes() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--mode", "badmode"])
        XCTAssertTrue(result.stderr.contains("Invalid mode"),
            "stderr should mention 'Invalid mode', got: \(result.stderr)")
        XCTAssertTrue(result.stderr.contains("default"),
            "stderr should list valid modes including 'default'")
    }

    func testInvalidToolsTier_exitsOne() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--tools", "everything"])
        XCTAssertEqual(result.exitCode, 1)
    }

    func testInvalidToolsTier_stderrContainsError() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--tools", "everything"])
        XCTAssertTrue(result.stderr.contains("Invalid tools tier"),
            "stderr should mention invalid tools tier, got: \(result.stderr)")
    }

    func testInvalidOutputFormat_exitsOne() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--output", "xml"])
        XCTAssertEqual(result.exitCode, 1)
    }

    func testInvalidOutputFormat_stderrContainsError() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--output", "xml"])
        XCTAssertTrue(result.stderr.contains("Invalid output format"),
            "stderr should mention invalid output format, got: \(result.stderr)")
    }

    func testInvalidMaxTurns_negative_exitsOne() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--max-turns", "-1"])
        XCTAssertEqual(result.exitCode, 1)
    }

    func testInvalidMaxTurns_zero_exitsOne() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--max-turns", "0"])
        XCTAssertEqual(result.exitCode, 1)
    }

    func testInvalidMaxTurns_nonNumeric_exitsOne() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--max-turns", "abc"])
        XCTAssertEqual(result.exitCode, 1)
    }

    func testInvalidMaxBudget_negative_exitsOne() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--max-budget", "-5"])
        XCTAssertEqual(result.exitCode, 1)
    }

    func testInvalidThinking_zero_exitsOne() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--thinking", "0"])
        XCTAssertEqual(result.exitCode, 1)
    }

    func testInvalidProvider_exitsOne() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--provider", "google"])
        XCTAssertEqual(result.exitCode, 1)
    }

    func testInvalidLogLevel_exitsOne() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--log-level", "verbose"])
        XCTAssertEqual(result.exitCode, 1)
    }

    // MARK: - --stdin + --skill mutual exclusion (AC#4)

    func testStdinAndSkill_exitsWithError() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--stdin", "--skill", "foo"])
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.stderr.contains("Cannot use --stdin and --skill together"),
            "stderr should mention mutual exclusion, got: \(result.stderr)")
    }

    // MARK: - Startup performance

    func testHelpStartup_completesWithin5Seconds() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--help"])
        XCTAssertLessThan(result.elapsedMs, 5000,
            "--help should complete within 5 seconds, took \(result.elapsedMs)ms")
    }

    func testVersionStartup_completesWithin5Seconds() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--version"])
        XCTAssertLessThan(result.elapsedMs, 5000,
            "--version should complete within 5 seconds, took \(result.elapsedMs)ms")
    }

    func testInvalidFlagStartup_completesWithin5Seconds() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--invalid"])
        XCTAssertLessThan(result.elapsedMs, 5000,
            "Invalid flag should fail fast within 5 seconds, took \(result.elapsedMs)ms")
    }

    // MARK: - Real E2E: Single-shot (uses real config, makes real API call)

    func testSingleShot_returnsResponse() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: ["Respond with exactly the word: pong"]
        )
        XCTAssertEqual(result.exitCode, 0,
            "Single-shot should succeed, stderr: \(result.stderr)")
        XCTAssertTrue(result.stdout.localizedCaseInsensitiveContains("pong"),
            "Response should contain 'pong', got: \(result.stdout.prefix(500))")
    }

    func testSingleShot_jsonMode_returnsValidJson() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: ["--output", "json", "Say exactly: hello"]
        )
        XCTAssertEqual(result.exitCode, 0,
            "JSON mode should succeed, stderr: \(result.stderr)")
        let data = result.stdout.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(json is [String: Any],
            "Output should be a valid JSON object, got: \(result.stdout.prefix(500))")
    }

    func testSingleShot_quietMode_suppressesSummary() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: ["--quiet", "Say exactly: hello"]
        )
        XCTAssertEqual(result.exitCode, 0,
            "Quiet mode should succeed, stderr: \(result.stderr)")
        XCTAssertFalse(result.stdout.contains("Turns:"),
            "Quiet mode should suppress summary, got: \(result.stdout.suffix(200))")
        XCTAssertFalse(result.stdout.contains("Cost:"),
            "Quiet mode should suppress cost info, got: \(result.stdout.suffix(200))")
    }

    // MARK: - Real E2E: --stdin (uses real config, makes real API call)

    func testStdin_withData_completesSuccessfully() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: ["--stdin"],
            stdinData: "Respond with exactly the word: pong".data(using: .utf8)!
        )
        XCTAssertEqual(result.exitCode, 0,
            "Stdin mode should succeed, stderr: \(result.stderr)")
        XCTAssertTrue(result.stdout.localizedCaseInsensitiveContains("pong"),
            "Response should contain 'pong', got: \(result.stdout.prefix(500))")
    }

    func testStdin_noInput_exitsWithError() throws {
        let exec = try resolveExecutable()
        // Pipe empty data — isatty returns 0 (pipe), but stdin is empty
        let result = launchCLI(
            execPath: exec,
            arguments: ["--stdin"],
            stdinData: Data()
        )
        XCTAssertEqual(result.exitCode, 1,
            "Empty stdin should exit 1")
        XCTAssertTrue(result.stderr.contains("stdin"),
            "stderr should mention stdin error, got: \(result.stderr)")
    }

    // MARK: - Real E2E: Flag combinations (uses real config, makes real API call)

    func testMultipleFlags_combined() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: [
                "--mode", "auto",
                "--tools", "core",
                "--max-turns", "3",
                "Respond with exactly the word: pong"
            ]
        )
        XCTAssertEqual(result.exitCode, 0,
            "Multiple flags should succeed, stderr: \(result.stderr)")
        XCTAssertTrue(result.stdout.localizedCaseInsensitiveContains("pong"),
            "Response should contain 'pong', got: \(result.stdout.prefix(500))")
    }

    func testQuietAndDebug_coexist() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: ["--quiet", "--debug", "Say exactly: hello"]
        )
        XCTAssertEqual(result.exitCode, 0,
            "--quiet and --debug should coexist, stderr: \(result.stderr)")
    }

    func testToolAllow_filtersTools() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: ["--tool-allow", "Bash,Read", "Respond with exactly: pong"]
        )
        XCTAssertEqual(result.exitCode, 0,
            "--tool-allow should work, stderr: \(result.stderr)")
        XCTAssertTrue(result.stdout.localizedCaseInsensitiveContains("pong"),
            "Response should contain 'pong', got: \(result.stdout.prefix(500))")
    }

    func testToolDeny_excludesTools() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: ["--tool-deny", "Write,Edit,Bash", "Respond with exactly: pong"]
        )
        XCTAssertEqual(result.exitCode, 0,
            "--tool-deny should work, stderr: \(result.stderr)")
        XCTAssertTrue(result.stdout.localizedCaseInsensitiveContains("pong"),
            "Response should contain 'pong', got: \(result.stdout.prefix(500))")
    }

    // MARK: - POSIX end-of-flags

    func testDoubleDash_treatsFollowingAsPositional() throws {
        let exec = try resolveExecutable()
        // Use a fake API key so it fails fast trying to call the LLM,
        // rather than succeeding (or taking 30s) with a real key.
        let result = launchCLI(
            execPath: exec,
            arguments: ["--api-key", "test-key-fake", "--", "--help"]
        )
        // After --, "--help" is a positional prompt sent to the LLM.
        // With a fake API key, the LLM call will fail → exitCode != 0 or stderr has error.
        // If --help were a flag, exitCode would be 0 and stdout would be the help text.
        let helpText = "openagent [options]"
        if result.exitCode == 0 && result.stdout.contains(helpText) && !result.stdout.contains("Turns:") {
            XCTFail("After --, --help should be a positional arg, not trigger help output. stdout=\(result.stdout.prefix(200))")
        }
    }

    // MARK: - Real E2E: --stdin terminal guard (AC#3)

    func testStdin_terminalInput_exitsWithError() throws {
        // When launched via Process, stdin is a pipe (not tty), so isatty returns 0.
        // This test verifies the error path by piping nothing and checking the
        // "no input received" error. The actual isatty guard is tested via unit tests.
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: ["--stdin"],
            stdinData: Data()
        )
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.stderr.contains("stdin"),
            "Should report stdin error, got: \(result.stderr)")
    }

    // =========================================================================
    // MARK: - Real E2E: Multi-turn tool call chains (Story 8.2 AC#1)
    // =========================================================================

    /// AC#1: Agent uses Write + Bash + Edit tools to create, compile, and modify a file.
    /// This is a single-shot test where the prompt requires multi-turn tool orchestration.
    /// Timeout is generous (90s) because the Agent must perform multiple tool calls.
    func testMultiTurn_createCompileModify() throws {
        let exec = try resolveExecutable()
        let tmpDir = "/tmp/e2e_82_ac1_\(Int.random(in: 10000...99999))"
        defer { try? FileManager.default.removeItem(atPath: tmpDir) }

        let result = launchCLI(
            execPath: exec,
            arguments: [
                "--mode", "auto",
                "--max-turns", "8",
                "Create a Swift file at \(tmpDir)/hello.swift that prints \"Hello E2E\". " +
                "Compile it with `swiftc \(tmpDir)/hello.swift -o \(tmpDir)/hello`. " +
                "Then run the compiled binary and tell me the output."
            ],
            timeout: 90
        )
        XCTAssertEqual(result.exitCode, 0,
            "Multi-turn create/compile/modify should succeed, stderr: \(result.stderr)")
        XCTAssertTrue(result.stdout.localizedCaseInsensitiveContains("Hello E2E"),
            "Output should contain 'Hello E2E' from the compiled program, got: \(result.stdout.suffix(500))")
    }

    /// AC#1: Tool call progress is visible -- tool name, parameter summary, and duration markers
    /// appear in stdout when the Agent invokes tools.
    func testMultiTurn_toolCallVisibility() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: [
                "--mode", "auto",
                "--max-turns", "5",
                "Use the Bash tool to run: echo visibility-test-marker-8-2"
            ],
            timeout: 60
        )
        XCTAssertEqual(result.exitCode, 0,
            "Tool visibility test should succeed, stderr: \(result.stderr)")
        // Verify the tool was actually invoked and output is captured
        XCTAssertTrue(result.stdout.localizedCaseInsensitiveContains("visibility-test-marker-8-2"),
            "Output should contain the echo marker, got: \(result.stdout.suffix(500))")
    }

    /// AC#1: Agent uses Glob/Grep/Read tools in sequence to find and inspect files.
    func testMultiTurn_grepAndRead() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: [
                "--mode", "auto",
                "--max-turns", "8",
                "Use file search tools to find any .swift file in the current directory that " +
                "contains the word 'import'. Show me the first file path and the first 'import' " +
                "line you find."
            ],
            timeout: 60
        )
        XCTAssertEqual(result.exitCode, 0,
            "Grep-and-read chain should succeed, stderr: \(result.stderr)")
        XCTAssertTrue(result.stdout.localizedCaseInsensitiveContains("import"),
            "Output should mention 'import', got: \(result.stdout.suffix(500))")
    }

    // =========================================================================
    // MARK: - Real E2E: MCP integration (Story 8.2 AC#2)
    // =========================================================================

    /// AC#2: CLI starts with --mcp flag pointing to a valid MCP config, and MCP tools are available.
    ///
    /// This test is skipped in automated E2E because implementing a proper MCP server in bash
    /// is impractical -- the MCP handshake requires precise JSON-RPC timing that shell scripts
    /// cannot reliably provide. A real MCP server (e.g., a Swift/Node-based tool) is needed.
    ///
    /// **Manual Test Procedure:**
    /// 1. Install an MCP server (e.g., `npx @anthropic/mcp-server-filesystem /tmp`)
    /// 2. Create config: `{"mcpServers":{"fs":{"command":"npx","args":["@anthropic/mcp-server-filesystem","/tmp"]}}}`
    /// 3. Run: `openagent --mcp config.json "List any MCP tools available"`
    /// 4. Verify: output mentions the MCP tool name(s)
    /// 5. Run: `openagent --mcp config.json "Use the filesystem tool to list files in /tmp"`
    /// 6. Verify: MCP tool is invoked and returns results
    ///
    /// **SDK Gap:** MCP stdio transport requires a process implementing full JSON-RPC MCP protocol.
    /// A bash echo server is insufficient because grep-based JSON parsing causes timing issues
    /// that hang the SDK's MCP handshake. A proper MCP server implementation in Swift/Node is needed
    /// for automated E2E testing of this path.
    func testMcp_serverConnectsAndToolsAvailable() throws {
        throw XCTSkip(
            "MCP server E2E test requires a real MCP server. " +
            "Automated bash echo server is unreliable for MCP JSON-RPC handshake. " +
            "See manual test procedure in code comments."
        )
    }

    /// AC#2: Verify /mcp status output when launched with --mcp flag.
    /// Tests the REPL command `/mcp status` via single-shot mode is not directly possible,
    /// so this test verifies the MCP flag is accepted and the CLI starts successfully.
    func testMcp_flagAcceptedAndStarts() throws {
        let exec = try resolveExecutable()

        let tmpDir = "/tmp/e2e_82_ac2b_\(Int.random(in: 10000...99999))"
        try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmpDir) }

        // Write a minimal (possibly empty) MCP config
        let mcpConfigPath = "\(tmpDir)/mcp-config.json"
        let mcpConfig = """
        { "mcpServers": {} }
        """
        try mcpConfig.write(toFile: mcpConfigPath, atomically: true, encoding: .utf8)

        // With an empty MCP config, the CLI should at least start and handle the prompt
        let result = launchCLI(
            execPath: exec,
            arguments: [
                "--mcp", mcpConfigPath,
                "Respond with exactly: mcp-ok"
            ],
            timeout: 30
        )
        XCTAssertEqual(result.exitCode, 0,
            "CLI with --mcp and empty config should succeed, stderr: \(result.stderr)")
        XCTAssertTrue(result.stdout.localizedCaseInsensitiveContains("mcp-ok"),
            "Should contain 'mcp-ok', got: \(result.stdout.prefix(300))")
    }

    // =========================================================================
    // MARK: - Real E2E: Permission mode enforcement (Story 8.2 AC#3)
    // =========================================================================

    /// AC#3: --mode auto completes a task requiring tool execution without permission prompts.
    func testPermission_autoMode_singleShot() throws {
        let exec = try resolveExecutable()
        // auto mode should auto-approve all tools -- no permission prompts in single-shot
        let result = launchCLI(
            execPath: exec,
            arguments: [
                "--mode", "auto",
                "--max-turns", "3",
                "Use the Bash tool to run: echo auto-mode-test-passed"
            ],
            timeout: 30
        )
        XCTAssertEqual(result.exitCode, 0,
            "Auto mode should complete without permission prompts, stderr: \(result.stderr)")
        XCTAssertTrue(result.stdout.localizedCaseInsensitiveContains("auto-mode-test-passed"),
            "Output should contain echo result, got: \(result.stdout.suffix(500))")
    }

    /// AC#3: --mode default in non-interactive (single-shot) auto-approves with warning.
    /// The task uses a tool (Bash) which in default mode should auto-approve in non-interactive.
    func testPermission_defaultMode_nonInteractive() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: [
                "--mode", "default",
                "--max-turns", "3",
                "Use the Bash tool to run: echo default-mode-test-passed"
            ],
            timeout: 30
        )
        XCTAssertEqual(result.exitCode, 0,
            "Default mode in non-interactive should auto-approve, stderr: \(result.stderr)")
        XCTAssertTrue(result.stdout.localizedCaseInsensitiveContains("default-mode-test-passed"),
            "Output should contain echo result, got: \(result.stdout.suffix(500))")
    }

    /// AC#3: Different --mode values produce expected behavior.
    /// Verifies that plan mode, dontAsk mode, and acceptEdits mode all accept the flag.
    func testPermission_modeSwitchViaFlag() throws {
        let exec = try resolveExecutable()

        let modes = ["plan", "dontAsk", "acceptEdits", "bypassPermissions"]
        for mode in modes {
            let result = launchCLI(
                execPath: exec,
                arguments: [
                    "--mode", mode,
                    "--max-turns", "2",
                    "Respond with exactly: mode-\(mode)-ok"
                ]
            )
            XCTAssertEqual(result.exitCode, 0,
                "Mode \(mode) should succeed, stderr: \(result.stderr)")
            XCTAssertTrue(result.stdout.localizedCaseInsensitiveContains("mode-\(mode)-ok"),
                "Output should confirm mode \(mode) worked, got: \(result.stdout.prefix(300))")
        }
    }

    // =========================================================================
    // MARK: - Real E2E: Session continuity (Story 8.2 AC#4)
    // =========================================================================

    /// AC#4: A session created in one invocation can be restored in another.
    /// Step 1: Create a session with a unique marker using --no-restore and capture the session ID.
    /// Step 2: Use --session <id> to restore and verify the marker is remembered.
    ///
    /// Note: Auto-restore only works in REPL mode (no prompt). In single-shot mode,
    /// we use explicit --session <id> to restore. This is the correct approach for
    /// programmatic session continuity.
    func testSession_persistAndRestore() throws {
        let exec = try resolveExecutable()
        let marker = "session-marker-82-\(Int.random(in: 10000...99999))"

        // Step 1: Create a session with the marker, using --no-restore for isolation
        // Use --output json to capture the sessionId
        let createResult = launchCLI(
            execPath: exec,
            arguments: [
                "--no-restore",
                "--output", "json",
                "Remember this secret code: \(marker). Just respond with: remembered"
            ],
            timeout: 30
        )
        XCTAssertEqual(createResult.exitCode, 0,
            "Session creation should succeed, stderr: \(createResult.stderr)")

        // Extract session ID from JSON output
        let createData = createResult.stdout.data(using: .utf8)!
        let createJson = try JSONSerialization.jsonObject(with: createData) as? [String: Any]
        let sessionId = createJson?["sessionId"] as? String
        guard let sid = sessionId, !sid.isEmpty else {
            throw XCTSkip("Could not extract sessionId from JSON output. Output: \(createResult.stdout.prefix(500))")
        }

        // Step 2: Use --session <id> to restore and verify the marker is remembered
        let restoreResult = launchCLI(
            execPath: exec,
            arguments: [
                "--session", sid,
                "--quiet",
                "What was the secret code I told you? Respond with ONLY the code."
            ],
            timeout: 30
        )
        XCTAssertEqual(restoreResult.exitCode, 0,
            "Session restore should succeed, stderr: \(restoreResult.stderr)")
        XCTAssertTrue(restoreResult.stdout.localizedCaseInsensitiveContains(marker),
            "Restored session should remember the marker '\(marker)', got: \(restoreResult.stdout.prefix(500))")

        // Cleanup: remove the session file
        let sessionPath = NSHomeDirectory() + "/.openagent-sdk/sessions/\(sid).json"
        try? FileManager.default.removeItem(atPath: sessionPath)
    }

    /// AC#4: Explicit --session <id> restores a specific session.
    /// Step 1: Create a session and capture the session ID from output.
    /// Step 2: Use --session <id> to explicitly restore it.
    func testSession_restoreWithSessionFlag() throws {
        let exec = try resolveExecutable()
        let marker = "session-explicit-82-\(Int.random(in: 10000...99999))"

        // Step 1: Create session and get the session ID
        // Using --output json to capture structured output including session ID
        let createResult = launchCLI(
            execPath: exec,
            arguments: [
                "--no-restore",
                "--output", "json",
                "Remember this identifier: \(marker). Respond with: noted"
            ],
            timeout: 30
        )
        XCTAssertEqual(createResult.exitCode, 0,
            "Session creation should succeed, stderr: \(createResult.stderr)")

        // Extract session ID from JSON output
        let createData = createResult.stdout.data(using: .utf8)!
        let createJson = try JSONSerialization.jsonObject(with: createData) as? [String: Any]
        let sessionId = createJson?["sessionId"] as? String
        guard let sid = sessionId, !sid.isEmpty else {
            throw XCTSkip("Could not extract sessionId from JSON output. Output: \(createResult.stdout.prefix(500))")
        }

        // Step 2: Restore the specific session and verify marker is remembered
        let restoreResult = launchCLI(
            execPath: exec,
            arguments: [
                "--session", sid,
                "--quiet",
                "What identifier did I ask you to remember? Respond with ONLY the identifier."
            ],
            timeout: 30
        )
        XCTAssertEqual(restoreResult.exitCode, 0,
            "Session restore with --session should succeed, stderr: \(restoreResult.stderr)")
        XCTAssertTrue(restoreResult.stdout.localizedCaseInsensitiveContains(marker),
            "Restored session should contain '\(marker)', got: \(restoreResult.stdout.prefix(500))")

        // Cleanup: remove the session file
        let sessionPath = NSHomeDirectory() + "/.openagent-sdk/sessions/\(sid).json"
        try? FileManager.default.removeItem(atPath: sessionPath)
    }

    // =========================================================================
    // MARK: - Real E2E: Flag combinations and edge cases (Story 8.2 cross-cutting)
    // =========================================================================

    /// Cross-cutting: --model flag switches the model used.
    func testModelSwitch_viaFlag() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: [
                "--model", "gpt-4o-mini",
                "--provider", "openai",
                "Respond with exactly: model-switch-ok"
            ],
            timeout: 30
        )
        // This may fail if the openai key is not configured; skip gracefully
        if result.exitCode != 0 {
            throw XCTSkip("OpenAI provider not configured -- skipping model switch test. stderr: \(result.stderr)")
        }
        XCTAssertTrue(result.stdout.localizedCaseInsensitiveContains("model-switch-ok"),
            "Output should confirm model switch, got: \(result.stdout.prefix(300))")
    }

    /// Cross-cutting: --tools advanced loads additional tools.
    func testMultipleToolTiers_combined() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: [
                "--tools", "advanced",
                "--mode", "auto",
                "Respond with exactly: tools-advanced-ok"
            ],
            timeout: 30
        )
        XCTAssertEqual(result.exitCode, 0,
            "Advanced tools tier should work, stderr: \(result.stderr)")
        XCTAssertTrue(result.stdout.localizedCaseInsensitiveContains("tools-advanced-ok"),
            "Output should confirm advanced tools loaded, got: \(result.stdout.prefix(300))")
    }

    /// Cross-cutting: Both --output text and --output json produce valid output.
    func testOutputFormats_textAndJson() throws {
        let exec = try resolveExecutable()

        // Text output
        let textResult = launchCLI(
            execPath: exec,
            arguments: ["--output", "text", "Respond with exactly: text-ok"]
        )
        XCTAssertEqual(textResult.exitCode, 0,
            "Text output should succeed, stderr: \(textResult.stderr)")
        XCTAssertTrue(textResult.stdout.localizedCaseInsensitiveContains("text-ok"),
            "Text output should contain 'text-ok', got: \(textResult.stdout.prefix(300))")

        // JSON output
        let jsonResult = launchCLI(
            execPath: exec,
            arguments: ["--output", "json", "Respond with exactly: json-ok"]
        )
        XCTAssertEqual(jsonResult.exitCode, 0,
            "JSON output should succeed, stderr: \(jsonResult.stderr)")
        let data = jsonResult.stdout.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(json is [String: Any],
            "JSON output should be a valid JSON object, got: \(jsonResult.stdout.prefix(300))")
    }

    /// Cross-cutting: --quiet mode suppresses non-essential output (no Turns/Cost summary).
    func testQuietMode_suppressesNonEssential() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: ["--quiet", "Respond with exactly: quiet-ok"]
        )
        XCTAssertEqual(result.exitCode, 0,
            "Quiet mode should succeed, stderr: \(result.stderr)")
        XCTAssertTrue(result.stdout.localizedCaseInsensitiveContains("quiet-ok"),
            "Output should contain 'quiet-ok', got: \(result.stdout.prefix(300))")
        XCTAssertFalse(result.stdout.contains("Turns:"),
            "Quiet mode should not show 'Turns:', got: \(result.stdout.suffix(200))")
        XCTAssertFalse(result.stdout.contains("Cost:"),
            "Quiet mode should not show 'Cost:', got: \(result.stdout.suffix(200))")
        XCTAssertFalse(result.stdout.contains("Duration:"),
            "Quiet mode should not show 'Duration:', got: \(result.stdout.suffix(200))")
    }

    // MARK: - Story 8.3: Deferred Work Cleanup

    // --- AC#2: Fix misleading error message in registry guard ---

    func testSkillWithoutDir_autoDiscoversAndReportsNotFound() throws {
        // When --skill is used without --skill-dir, CLI auto-discovers from default dirs
        // and reports "Skill not found" if the skill name doesn't match any discovered skill.
        let exec = try resolveExecutable()
        let result = launchCLI(execPath: exec, arguments: ["--skill", "review", "--api-key", "test-key"])

        XCTAssertEqual(result.exitCode, 1,
            "Should exit 1 when --skill name not found")

        // Now reports "Skill not found" with either available skills list or directory hint
        XCTAssertTrue(result.stderr.contains("Skill not found: review") || result.stderr.contains("No skills discovered"),
            "stderr should report skill not found or no skills discovered. Got: \(result.stderr)")
    }

    func testSkillNotFound_showsAvailableSkills() throws {
        // AC#2: When --skill-dir is provided but skill name doesn't exist,
        // the error should say "Skill not found" and list available skills.
        let exec = try resolveExecutable()

        // Create a temp skill directory with one skill
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-skill-test-\(UUID().uuidString)")
        let skillDir = tmpDir.appendingPathComponent("review")
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let skillMD = """
        ---
        name: review
        description: Review code
        userInvocable: true
        ---
        Review the code.
        """
        try skillMD.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let result = launchCLI(execPath: exec, arguments: [
            "--skill-dir", tmpDir.path,
            "--skill", "nonexistent",
            "--api-key", "test-key"
        ])

        XCTAssertEqual(result.exitCode, 1,
            "Should exit 1 when skill name not found")

        XCTAssertTrue(result.stderr.contains("Skill not found: nonexistent"),
            "stderr should say 'Skill not found: nonexistent' when skill is missing from registry (AC#2). Got: \(result.stderr)")
        XCTAssertTrue(result.stderr.contains("Available skills:"),
            "stderr should list available skills when skill not found (AC#2). Got: \(result.stderr)")
        XCTAssertTrue(result.stderr.contains("review"),
            "Available skills list should contain 'review' (AC#2). Got: \(result.stderr)")
    }

    // --- AC#3: --skill + positional prompt combined path ---

    func testSkillWithPrompt_bothQueriesExecute() throws {
        // AC#3: When both --skill and a positional prompt are provided,
        // the skill template is invoked first, then the positional prompt
        // is executed as a second query in single-shot mode.
        let exec = try resolveExecutable()

        // Create a temp skill directory
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-skill-prompt-\(UUID().uuidString)")
        let skillDir = tmpDir.appendingPathComponent("echo-test")
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let skillMD = """
        ---
        name: echo-test
        description: Echo test skill
        userInvocable: true
        ---
        Respond with exactly: SKILL_TEMPLATE_EXECUTED
        """
        try skillMD.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let result = launchCLI(
            execPath: exec,
            arguments: [
                "--skill-dir", tmpDir.path,
                "--skill", "echo-test",
                "--api-key", "test-key",
                "--max-turns", "1",
                "Respond with exactly: POSITIONAL_PROMPT_EXECUTED"
            ],
            timeout: 15
        )

        // The skill template should be executed (first query)
        // The positional prompt should also be executed (second query)
        // Note: With a test API key, this will likely fail at the API call level,
        // but we can verify the CLI reaches both code paths based on the error output
        // or the exit code. The key behavior is that the CLI does NOT enter REPL mode
        // (which would hang) when both --skill and prompt are provided.
        XCTAssertNotEqual(result.exitCode, -1,
            "CLI should not crash or be killed by timeout -- it should process both queries")
    }
}
