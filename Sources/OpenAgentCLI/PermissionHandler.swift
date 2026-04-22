import Foundation
import OpenAgentSDK

// MARK: - RiskLevel

/// Risk level classification for tool operations.
///
/// Used to categorize tools by the potential impact of their execution,
/// providing visual differentiation in permission prompts.
enum RiskLevel: String, Equatable {
    case high
    case medium
    case low
}

// MARK: - PermissionState

/// Mutable state for permission session-level memory.
///
/// Tracks tools that the user has approved with the "always" option
/// for the duration of the current session only (not persisted).
final class PermissionState: @unchecked Sendable {
    private let lock = NSLock()
    private var _alwaysAllowedTools: Set<String> = []

    /// Check if a tool has been marked as "always allowed" this session.
    func isAlwaysAllowed(_ toolName: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _alwaysAllowedTools.contains(toolName)
    }

    /// Mark a tool as "always allowed" for this session.
    func markAlwaysAllowed(_ toolName: String) {
        lock.lock()
        defer { lock.unlock() }
        _alwaysAllowedTools.insert(toolName)
    }
}

// MARK: - PermissionHandler

/// Creates `CanUseToolFn` closures that enforce permission modes for tool execution.
///
/// Each mode controls how the CLI interacts with the user when tools are about to run:
/// - `bypassPermissions` / `dontAsk` / `auto`: auto-approve everything, no prompts
/// - `default`: auto-approve read-only tools, prompt for write tools
/// - `acceptEdits`: auto-approve read-only and Edit tools, prompt for other writes
/// - `plan`: prompt for all tools (including read-only)
///
/// Uses protocol injection (`InputReading` + `OutputRenderer`) for testability,
/// matching the same pattern used by `REPLLoop`.
enum PermissionHandler {

    // MARK: - Edit tool names

    /// Tool names that are considered "edit" operations for the `acceptEdits` mode.
    private static let editToolNames: Set<String> = ["Edit"]

    // MARK: - Destructive command keywords

    /// Keywords in Bash commands that indicate destructive (high-risk) operations.
    private static let destructiveKeywords: Set<String> = [
        "rm -rf", "rm -r", "rm -f", "rmdir",
        "format", "mkfs", "shred", "wipe"
    ]

    // MARK: - Risk Level Classification

    /// Classify the risk level of a tool operation based on tool name and input.
    ///
    /// - Parameters:
    ///   - tool: The tool being invoked.
    ///   - input: The input parameters for the tool invocation.
    /// - Returns: The risk level classification (`.high`, `.medium`, or `.low`).
    static func classifyRiskLevel(tool: ToolProtocol, input: Any) -> RiskLevel {
        // Edit tools are always low risk
        if editToolNames.contains(tool.name) {
            return .low
        }

        // Bash with destructive commands is high risk
        if tool.name == "Bash" {
            if let dict = input as? [String: Any],
               let command = dict["command"] as? String {
                let lowerCommand = command.lowercased()
                for keyword in destructiveKeywords {
                    if lowerCommand.contains(keyword) {
                        return .high
                    }
                }
            }
            // Bash without destructive commands is medium risk
            return .medium
        }

        // Other write tools (Write, etc.) are medium risk
        return .medium
    }

    // MARK: - Private Helpers (shared by mode closures)

    /// Check whether a tool should be auto-approved due to non-interactive mode.
    /// Returns an allow result with a warning message, or nil if interactive (proceed to prompt).
    private static func checkNonInteractive(
        tool: ToolProtocol,
        isInteractive: Bool,
        renderer: OutputRenderer
    ) -> CanUseToolResult? {
        guard !isInteractive else { return nil }
        let message = "Non-interactive mode: auto-approving '\(tool.name)' (use --mode bypassPermissions to suppress this warning)."
        renderer.output.write("\(ANSI.yellow("\u{26A0}")) \(message)\n")
        return .allow()
    }

    // MARK: - Public API

    /// Create a `CanUseToolFn` closure for the given permission mode.
    ///
    /// - Parameters:
    ///   - mode: The permission mode controlling tool approval behavior.
    ///   - reader: Input reader for prompting the user (when needed).
    ///   - renderer: Output renderer for displaying permission prompts.
    ///   - isInteractive: Whether the session is interactive (has a TTY). Defaults to `true`.
    ///     When `false`, permission prompts are suppressed and write operations are denied
    ///     with a helpful message suggesting `--mode bypassPermissions`.
    /// - Returns: A `CanUseToolFn` closure that the SDK will call before each tool execution.
    static func createCanUseTool(
        mode: PermissionMode,
        reader: InputReading,
        renderer: OutputRenderer,
        isInteractive: Bool = true
    ) -> CanUseToolFn {
        let state = PermissionState()

        switch mode {
        case .bypassPermissions, .dontAsk, .auto:
            return { _, _, _ in .allow() }

        case .default:
            return { tool, input, context in
                if tool.isReadOnly {
                    return .allow()
                }

                if let denial = checkNonInteractive(tool: tool, isInteractive: isInteractive, renderer: renderer) {
                    return denial
                }

                // Check session-level "always" memory
                if state.isAlwaysAllowed(tool.name) {
                    return .allow()
                }

                return await promptUser(tool: tool, input: input, reader: reader, renderer: renderer, state: state)
            }

        case .acceptEdits:
            return { tool, input, context in
                if tool.isReadOnly {
                    return .allow()
                }
                if editToolNames.contains(tool.name) {
                    return .allow()
                }

                if let denial = checkNonInteractive(tool: tool, isInteractive: isInteractive, renderer: renderer) {
                    return denial
                }

                // Check session-level "always" memory
                if state.isAlwaysAllowed(tool.name) {
                    return .allow()
                }

                return await promptUser(tool: tool, input: input, reader: reader, renderer: renderer, state: state)
            }

        case .plan:
            return { tool, input, context in
                if let denial = checkNonInteractive(tool: tool, isInteractive: isInteractive, renderer: renderer) {
                    return denial
                }

                // Check session-level "always" memory
                if state.isAlwaysAllowed(tool.name) {
                    return .allow()
                }

                return await promptUser(tool: tool, input: input, reader: reader, renderer: renderer, state: state)
            }
        }
    }

    // MARK: - Private Helpers

    /// Format the risk level as a colored tag string.
    private static func riskTag(_ level: RiskLevel) -> String {
        switch level {
        case .high:
            return ANSI.red("[HIGH RISK]")
        case .medium:
            return ANSI.yellow("[MEDIUM RISK]")
        case .low:
            return ANSI.dim("[LOW RISK]")
        }
    }

    /// Display a permission prompt and read user approval.
    ///
    /// Shows the risk level tag, tool name, and input summary, then reads y/n/a from the user.
    /// - Returns: `.allow()` if user approves, `.deny()` if user rejects.
    private static func promptUser(
        tool: ToolProtocol,
        input: Any,
        reader: InputReading,
        renderer: OutputRenderer,
        state: PermissionState
    ) async -> CanUseToolResult {
        let riskLevel = classifyRiskLevel(tool: tool, input: input)
        let tag = riskTag(riskLevel)

        let warning = ANSI.yellow("\u{26A0}")  // warning sign
        renderer.output.write("\(warning) \(tag) \(tool.name)\n")

        // Display each parameter on its own indented line
        if let dict = input as? [String: Any] {
            for (key, value) in dict {
                var valStr: String
                if let str = value as? String {
                    valStr = str.count > 40 ? String(str.prefix(37)) + "..." : str
                } else {
                    valStr = String(describing: value)
                    if valStr.count > 40 {
                        valStr = String(valStr.prefix(37)) + "..."
                    }
                }
                renderer.output.write("  \(key): \"\(valStr)\"\n")
            }
        } else {
            let inputSummary = summarizeInput(input)
            renderer.output.write("  \(inputSummary)\n")
        }

        renderer.output.write("  \(ANSI.bold("Allow?")) (y/n/a - yes/no/always): ")

        guard let response = reader.readLine(prompt: "") else {
            return .deny("No input received")
        }

        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch trimmed {
        case "y", "yes":
            return .allow()
        case "a", "always":
            state.markAlwaysAllowed(tool.name)
            return .allow()
        case "n", "no":
            return .deny("User denied permission")
        default:
            // Empty input or unrecognized input defaults to deny
            return .deny("Permission denied (default)")
        }
    }

    /// Produce a short summary of tool input for display in the permission prompt.
    private static func summarizeInput(_ input: Any) -> String {
        if let dict = input as? [String: Any] {
            let pairs = dict.map { key, value in
                var valStr: String
                if let str = value as? String {
                    valStr = str.count > 40 ? String(str.prefix(37)) + "..." : str
                } else {
                    valStr = String(describing: value)
                    if valStr.count > 40 {
                        valStr = String(valStr.prefix(37)) + "..."
                    }
                }
                return "\(key): \"\(valStr)\""
            }
            return pairs.joined(separator: ", ")
        }
        let desc = String(describing: input)
        if desc.count > 60 {
            return String(desc.prefix(57)) + "..."
        }
        return desc
    }
}
