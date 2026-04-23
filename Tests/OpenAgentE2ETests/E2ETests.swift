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
        let result = launchCLI(
            execPath: exec,
            arguments: ["--", "--help"]
        )
        // After --, "--help" is a positional prompt sent to the LLM
        XCTAssertFalse(result.stdout.contains("openagent [options]"),
            "After --, --help should be a positional arg, not trigger help output")
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
}
