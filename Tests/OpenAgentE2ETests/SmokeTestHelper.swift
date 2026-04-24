import Foundation
import XCTest
@testable import OpenAgentCLI

// MARK: - Smoke Test Helper Utilities (Story 1.6)
//
// Provides reusable helper methods for smoke, performance, and reliability tests.
// Encapsulates process launching, timing, and memory measurement patterns.

enum SmokeTestHelper {

    // MARK: - Timing Helpers

    /// Measure the execution time of a synchronous closure using CFAbsoluteTimeGetCurrent.
    ///
    /// - Parameter block: The closure to measure.
    /// - Returns: Elapsed time in milliseconds.
    static func measureSyncMs(_ block: () -> Void) -> Int64 {
        let start = CFAbsoluteTimeGetCurrent()
        block()
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        return Int64(elapsed * 1000)
    }

    // MARK: - Executable Path

    /// Resolve the path to the built openagent executable.
    ///
    /// Uses the package directory (detected from the test bundle) to locate
    /// `.build/debug/openagent`. This avoids `swift run` which conflicts with
    /// the SwiftPM lock held by `swift test`.
    static func openagentExecutablePath() -> String? {
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
                return nil
            }
        }
        return nil
    }

    // MARK: - Process Helpers

    /// Launch a subprocess and capture its stdout output.
    ///
    /// - Parameters:
    ///   - executable: Path to the executable (e.g. "/usr/bin/env").
    ///   - arguments: Arguments to pass to the executable.
    ///   - environment: Optional environment variables for the subprocess.
    ///   - timeout: Maximum time to wait in seconds (default: 30).
    /// - Returns: A tuple of (output string, termination status, elapsed time in ms).
    static func launchProcess(
        executable: String,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 30
    ) -> (output: String, terminationStatus: Int32, elapsedMs: Int64) {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe

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
            return ("[launch failed: \(error.localizedDescription)]", -1, 0)
        }

        // Enforce timeout: terminate process if it doesn't exit in time
        let timeoutWork = DispatchWorkItem { [weak process] in
            if let process, process.isRunning {
                process.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        process.waitUntilExit()
        timeoutWork.cancel()

        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let elapsedMs = Int64(elapsed * 1000)

        return (output, process.terminationStatus, elapsedMs)
    }

    // MARK: - Memory Helpers

    /// Get the current process resident memory in bytes using task_info.
    ///
    /// Uses Mach kernel API to query the resident memory size of the current process.
    ///
    /// - Returns: Resident memory size in bytes, or nil if measurement fails.
    static func residentMemoryBytes() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        return info.resident_size
    }
}
