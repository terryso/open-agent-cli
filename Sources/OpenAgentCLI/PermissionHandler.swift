import Foundation
import OpenAgentSDK

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

    // MARK: - Public API

    /// Create a `CanUseToolFn` closure for the given permission mode.
    ///
    /// - Parameters:
    ///   - mode: The permission mode controlling tool approval behavior.
    ///   - reader: Input reader for prompting the user (when needed).
    ///   - renderer: Output renderer for displaying permission prompts.
    /// - Returns: A `CanUseToolFn` closure that the SDK will call before each tool execution.
    static func createCanUseTool(
        mode: PermissionMode,
        reader: InputReading,
        renderer: OutputRenderer
    ) -> CanUseToolFn {
        switch mode {
        case .bypassPermissions, .dontAsk, .auto:
            return { _, _, _ in .allow() }

        case .default:
            return { tool, input, context in
                if tool.isReadOnly {
                    return .allow()
                }
                return await promptUser(tool: tool, input: input, reader: reader, renderer: renderer)
            }

        case .acceptEdits:
            return { tool, input, context in
                if tool.isReadOnly {
                    return .allow()
                }
                if editToolNames.contains(tool.name) {
                    return .allow()
                }
                return await promptUser(tool: tool, input: input, reader: reader, renderer: renderer)
            }

        case .plan:
            return { tool, input, context in
                return await promptUser(tool: tool, input: input, reader: reader, renderer: renderer)
            }
        }
    }

    // MARK: - Private Helpers

    /// Display a permission prompt and read user approval.
    ///
    /// Shows the tool name and input summary, then reads y/n from the user.
    /// - Returns: `.allow()` if user approves, `.deny()` if user rejects.
    private static func promptUser(
        tool: ToolProtocol,
        input: Any,
        reader: InputReading,
        renderer: OutputRenderer
    ) async -> CanUseToolResult {
        let inputSummary = summarizeInput(input)
        let warning = ANSI.yellow("\u{26A0}")  // warning sign
        renderer.output.write("\(warning) \(tool.name)(\(inputSummary))\n")
        renderer.output.write("  \(ANSI.bold("Allow?")) (y/n): ")

        guard let response = reader.readLine(prompt: "") else {
            return .deny("No input received")
        }

        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch trimmed {
        case "y", "yes":
            return .allow()
        default:
            return .deny("User denied permission")
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
