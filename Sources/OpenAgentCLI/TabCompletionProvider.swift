import OpenAgentSDK

/// Provides Tab-completion candidates for REPL slash commands.
///
/// A pure-logic struct with no mutable state. Given the current input buffer,
/// returns matching completion options for linenoise to display.
struct TabCompletionProvider {

    /// Built-in slash commands.
    private let builtInCommands: [String] = [
        "/help", "/exit", "/quit", "/tools", "/skills",
        "/model", "/mode", "/cost", "/clear",
        "/sessions", "/resume", "/fork", "/mcp"
    ]

    /// Skill names prefixed with "/" (populated from SkillRegistry).
    private let skillCommands: [String]

    /// All available slash commands (built-in + skills).
    private var commands: [String] {
        builtInCommands + skillCommands
    }

    init(skillNames: [String] = []) {
        self.skillCommands = skillNames.map { "/" + $0 }
    }

    /// /mcp subcommands.
    private let mcpSubcommands: [String] = ["status", "reconnect"]

    /// All valid permission modes (sourced from SDK, not hard-coded).
    private let modes: [String] = PermissionMode.allCases.map(\.rawValue)

    /// Return completion candidates for the given input buffer.
    ///
    /// - Parameter input: The full text currently in the input buffer.
    /// - Returns: Matching completion candidates (empty array means no completion).
    func completions(for input: String) -> [String] {
        // Non-/ prefix: no completion (AC#5)
        guard input.hasPrefix("/") else { return [] }

        // Check for subcommand context (space after command).
        // Use contains(" ") to detect trailing space, since String.split
        // drops trailing empty subsequences (e.g. "/mcp " → only ["/mcp"]).
        if let spaceRange = input.range(of: " ") {
            let command = String(input[..<spaceRange.lowerBound]).lowercased()
            let subPrefix = String(input[spaceRange.upperBound...]).lowercased()

            switch command {
            case "/mcp":
                return mcpSubcommands.filter { $0.lowercased().hasPrefix(subPrefix) }
            case "/mode":
                return modes.filter { $0.lowercased().hasPrefix(subPrefix) }
            default:
                return []
            }
        }

        // Main command prefix matching
        return commands.filter { $0.hasPrefix(input.lowercased()) }
    }
}
