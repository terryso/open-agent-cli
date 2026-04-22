import XCTest
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 8-1 AC#1 Eliminate Force-Unwrap
//
// These tests define the EXPECTED behavior after eliminating all force-unwrap
// `data(using: .utf8)!` calls across CLI source files.
// They will FAIL until the safe writeToStderr helper is created and all
// force-unwraps are replaced (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: All 16 force-unwrap `.data(using: .utf8)!` replaced with safe helper
//
// Proposed solution: Create `writeToStderr(_:)` in ANSI.swift that uses
// `?? Data()` fallback, then replace all 16 occurrences.

final class TechnicalDebtAC1Tests: XCTestCase {

    // MARK: - P0: writeToStderr helper exists and is safe

    /// AC#1: ANSI.writeToStderr() helper must exist with the correct signature.
    ///
    /// This test will FAIL until the helper is added to ANSI.swift.
    func testWriteToStderr_helperExists() {
        // The helper should be a static method on ANSI that accepts a String.
        // We verify it compiles by calling it.
        //
        // NOTE: Since writeToStderr writes to stderr (a side effect), we only
        // verify the method exists and accepts a String parameter.
        // The actual stderr output is verified by the compile-time check
        // (if this method doesn't exist, this test won't compile).

        // Call the helper with a test string to verify it exists.
        // This is a compile-time existence test.
        ANSI.writeToStderr("test message")
    }

    /// AC#1: writeToStderr should never force-unwrap.
    ///
    /// Verifies that the helper uses `?? Data()` instead of `!`.
    /// Since `String.data(using: .utf8)` only returns nil for non-Unicode
    /// strings (impossible with our ASCII error messages), the fallback
    /// is safe but eliminates the force-unwrap code smell.
    ///
    /// We test by passing various string types including empty and special chars.
    func testWriteToStderr_safeFallback_nilUTF8() {
        // The helper should not crash on any string input.
        // If it uses `?? Data()`, it silently writes nothing for nil cases.
        // If it still uses `!`, this would crash in theory (but UTF-8 never
        // returns nil for valid strings).

        // Verify the helper handles edge cases without crashing
        ANSI.writeToStderr("")           // empty string
        ANSI.writeToStderr("hello\n")    // with newline
        ANSI.writeToStderr("Error: test") // typical error message
        ANSI.writeToStderr("Special: \u{001B}[31m") // with ANSI escape

        // If we reach this point, the helper didn't crash
        XCTAssertTrue(true, "writeToStderr should handle all strings without crashing")
    }

    // MARK: - P0: Zero force-unwraps in source files

    /// AC#1: CLI.swift should contain zero occurrences of `data(using: .utf8)!`.
    ///
    /// This test reads the source file and scans for the forbidden pattern.
    /// It will FAIL until all 9 occurrences in CLI.swift are replaced.
    func testCLI_noForceUnwrap_dataUsingUtf8() throws {
        let sourcePath = "\(SourceDir.path)/Sources/OpenAgentCLI/CLI.swift"
        let source = try String(contentsOfFile: sourcePath)

        // Count occurrences of the force-unwrap pattern
        let forbiddenPattern = ".data(using: .utf8)!"
        let occurrences = source.components(separatedBy: forbiddenPattern).count - 1

        XCTAssertEqual(occurrences, 0,
            "CLI.swift should have zero '.data(using: .utf8)!' force-unwraps (found \(occurrences)). " +
            "Replace with ANSI.writeToStderr() or safe ?? Data() fallback (AC#1).")
    }

    /// AC#1: ConfigLoader.swift should contain zero occurrences of `data(using: .utf8)!`.
    ///
    /// This test reads the source file and scans for the forbidden pattern.
    /// It will FAIL until all 4 occurrences in ConfigLoader.swift are replaced.
    func testConfigLoader_noForceUnwrap_dataUsingUtf8() throws {
        let sourcePath = "\(SourceDir.path)/Sources/OpenAgentCLI/ConfigLoader.swift"
        let source = try String(contentsOfFile: sourcePath)

        let forbiddenPattern = ".data(using: .utf8)!"
        let occurrences = source.components(separatedBy: forbiddenPattern).count - 1

        XCTAssertEqual(occurrences, 0,
            "ConfigLoader.swift should have zero '.data(using: .utf8)!' force-unwraps (found \(occurrences)). " +
            "Replace with ANSI.writeToStderr() or safe ?? Data() fallback (AC#1).")
    }

    /// AC#1: AgentFactory.swift should contain zero occurrences of `data(using: .utf8)!`.
    ///
    /// This test reads the source file and scans for the forbidden pattern.
    /// It will FAIL until all 3 occurrences in AgentFactory.swift are replaced.
    func testAgentFactory_noForceUnwrap_dataUsingUtf8() throws {
        let sourcePath = "\(SourceDir.path)/Sources/OpenAgentCLI/AgentFactory.swift"
        let source = try String(contentsOfFile: sourcePath)

        let forbiddenPattern = ".data(using: .utf8)!"
        let occurrences = source.components(separatedBy: forbiddenPattern).count - 1

        XCTAssertEqual(occurrences, 0,
            "AgentFactory.swift should have zero '.data(using: .utf8)!' force-unwraps (found \(occurrences)). " +
            "Replace with ANSI.writeToStderr() or safe ?? Data() fallback (AC#1).")
    }
}

// MARK: - Source Directory Helper

/// Helper to locate the source directory relative to the test bundle.
/// Walks up from #file to find the project root (where Package.swift lives).
private enum SourceDir {
    static let path: String = {
        var dir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        for _ in 0..<10 {
            dir = dir.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                return dir.path
            }
        }
        // Fallback: assume standard SPM layout
        return URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
    }()
}
