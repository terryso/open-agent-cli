import Foundation
import OpenAgentSDK

// MARK: - CLIExitCode

/// Maps `QueryStatus` values to process exit codes for single-shot mode.
///
/// - Success: exit code 0
/// - All error/cancelled statuses: exit code 1
enum CLIExitCode {
    /// Return the appropriate exit code for a given `QueryStatus`.
    ///
    /// - Parameter status: The `QueryStatus` from a `QueryResult`.
    /// - Returns: `Int32` exit code (0 for success, 1 for any error or cancellation).
    static func forQueryStatus(_ status: QueryStatus) -> Int32 {
        switch status {
        case .success:
            return 0
        case .errorMaxTurns,
             .errorDuringExecution,
             .errorMaxBudgetUsd,
             .cancelled:
            return 1
        }
    }
}

// MARK: - CLISingleShot

/// Utilities for single-shot mode: formatting error messages from `QueryResult`.
///
/// This enum has no instances -- it serves as a namespace for static helpers.
enum CLISingleShot {

    /// Format an error message for a non-success `QueryResult`.
    ///
    /// Returns an empty string for success status (no error to report).
    /// For error/cancelled statuses, returns a human-readable description
    /// suitable for writing to stderr.
    ///
    /// - Parameters:
    ///   - result: The `QueryResult` to format.
    ///   - debug: When true, include detailed error messages from the SDK.
    /// - Returns: Error message string, or empty string for success.
    static func formatErrorMessage(_ result: QueryResult, debug: Bool = false) -> String {
        switch result.status {
        case .success:
            return ""
        case .errorMaxTurns:
            return "Error: Max turns (\(result.numTurns)) exceeded."
        case .errorDuringExecution:
            var msg = "Error: Execution failed."
            if debug, let errors = result.errors, !errors.isEmpty {
                msg += " " + errors.joined(separator: "; ")
            }
            return msg
        case .errorMaxBudgetUsd:
            let costStr = String(format: "$%.4f", result.totalCostUsd)
            return "Error: Budget exceeded at \(costStr)."
        case .cancelled:
            return "Error: Query was cancelled."
        }
    }
}
