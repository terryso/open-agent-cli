import Foundation
import XCTest

// MARK: - End-to-End Tests
//
// Tests that launch the `openagent` binary as a subprocess and verify
// external behavior: exit codes, stdout, stderr.
//
// These tests do NOT use @testable import — they treat the CLI as a black box.

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
    ///   - environment: Optional env overrides (merged with current env).
    ///   - stdinData: Optional data to pipe to stdin.
    ///   - timeout: Max wait time in seconds.
    /// - Returns: (stdout, stderr, exitCode, elapsedMs).
    private func launchCLI(
        execPath: String,
        arguments: [String],
        environment: [String: String]? = nil,
        stdinData: Data? = nil,
        timeout: TimeInterval = 15
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

        if let env = environment {
            var mergedEnv = ProcessInfo.processInfo.environment
            for (key, value) in env {
                mergedEnv[key] = value
            }
            process.environment = mergedEnv
        }

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
        // Should list valid modes
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

    // MARK: - Valid flag values (parse OK, fail later on missing API key)

    func testValidMode_doesNotExitAtParse() throws {
        // Valid mode should not cause a parse error — it proceeds to agent creation
        // which will fail because no API key is provided.
        let exec = try resolveExecutable()
        for mode in ["default", "acceptEdits", "bypassPermissions", "plan", "dontAsk", "auto"] {
            let result = launchCLI(execPath: exec, arguments: ["--mode", mode, "test"])
            // Should NOT be a parse error (exit 1 with "Invalid mode" message)
            // It may exit 1 for other reasons (no API key), but stderr should not
            // contain the parse error.
            XCTAssertFalse(result.stderr.contains("Invalid mode"),
                "Mode '\(mode)' should be valid, got stderr: \(result.stderr)")
        }
    }

    func testValidToolsTiers_noParseError() throws {
        let exec = try resolveExecutable()
        for tier in ["core", "advanced", "specialist", "all"] {
            let result = launchCLI(execPath: exec, arguments: ["--tools", tier, "test"])
            XCTAssertFalse(result.stderr.contains("Invalid tools tier"),
                "Tier '\(tier)' should be valid, got stderr: \(result.stderr)")
        }
    }

    func testValidOutputFormats_noParseError() throws {
        let exec = try resolveExecutable()
        for format in ["text", "json"] {
            let result = launchCLI(execPath: exec, arguments: ["--output", format, "test"])
            XCTAssertFalse(result.stderr.contains("Invalid output format"),
                "Format '\(format)' should be valid, got stderr: \(result.stderr)")
        }
    }

    // MARK: - Single-shot without API key

    func testSingleShot_noApiKey_exitsOne() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: ["hello world"],
            environment: ["OPENAGENT_API_KEY": ""]
        )
        // Without API key, agent creation fails
        XCTAssertEqual(result.exitCode, 1, "Single-shot without API key should exit 1")
    }

    func testSingleShot_noApiKey_stderrContainsError() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: ["hello"],
            environment: ["OPENAGENT_API_KEY": ""]
        )
        XCTAssertTrue(result.stderr.localizedLowercase.contains("error"),
            "stderr should contain error message, got: \(result.stderr)")
    }

    // MARK: - --stdin flag

    func testStdin_noInput_exitsWithError() throws {
        let exec = try resolveExecutable()
        // Pipe empty data to stdin with --stdin flag
        let result = launchCLI(
            execPath: exec,
            arguments: ["--stdin"],
            environment: ["OPENAGENT_API_KEY": ""],
            stdinData: Data()
        )
        // Empty stdin should produce an error
        XCTAssertEqual(result.exitCode, 1)
    }

    func testStdin_withData_usesStdinAsPrompt() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: ["--stdin"],
            environment: ["OPENAGENT_API_KEY": ""],
            stdinData: "what is 2+2?".data(using: .utf8)!
        )
        // Should not complain about missing stdin; will fail at API key check instead
        XCTAssertFalse(result.stderr.contains("--stdin"),
            "Should not complain about --stdin when data is provided, got: \(result.stderr)")
    }

    // MARK: - Flag combinations

    func testQuietAndDebug_coexist() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: ["--quiet", "--debug", "test"],
            environment: ["OPENAGENT_API_KEY": ""]
        )
        // Should not fail at parse stage
        XCTAssertFalse(result.stderr.contains("Unknown flag"),
            "--quiet and --debug should coexist, got: \(result.stderr)")
    }

    func testShortDebugFlag_works() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: ["-d", "test"],
            environment: ["OPENAGENT_API_KEY": ""]
        )
        XCTAssertFalse(result.stderr.contains("Unknown flag"),
            "-d should be a valid flag, got: \(result.stderr)")
    }

    func testMultipleFlags_combined() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: [
                "--model", "glm-5.1",
                "--mode", "auto",
                "--tools", "core",
                "--output", "json",
                "--max-turns", "5",
                "test prompt"
            ],
            environment: ["OPENAGENT_API_KEY": ""]
        )
        // All flags should parse without error
        XCTAssertFalse(result.stderr.contains("Unknown flag"),
            "Multiple valid flags should parse, got: \(result.stderr)")
        XCTAssertFalse(result.stderr.contains("Invalid"),
            "No validation errors expected, got: \(result.stderr)")
    }

    // MARK: - --tool-allow / --tool-deny

    func testToolAllow_commaSeparated() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: ["--tool-allow", "Bash,Read", "test"],
            environment: ["OPENAGENT_API_KEY": ""]
        )
        XCTAssertFalse(result.stderr.contains("Unknown flag"),
            "--tool-allow should be a valid flag, got: \(result.stderr)")
    }

    func testToolDeny_commaSeparated() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: ["--tool-deny", "Write,Edit", "test"],
            environment: ["OPENAGENT_API_KEY": ""]
        )
        XCTAssertFalse(result.stderr.contains("Unknown flag"),
            "--tool-deny should be a valid flag, got: \(result.stderr)")
    }

    // MARK: - POSIX end-of-flags

    func testDoubleDash_treatsFollowingAsPositional() throws {
        let exec = try resolveExecutable()
        let result = launchCLI(
            execPath: exec,
            arguments: ["--", "--help"],
            environment: ["OPENAGENT_API_KEY": ""]
        )
        // After --, "--help" is treated as a positional prompt, not a flag
        // So it should NOT print help output
        XCTAssertFalse(result.stdout.contains("openagent [options]"),
            "After --, --help should be a positional arg, not a flag")
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
}
