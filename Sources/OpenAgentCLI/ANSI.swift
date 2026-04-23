import Foundation
import OpenAgentSDK

/// Terminal ANSI escape code helpers for styled CLI output.
///
/// All methods return `String` values for composable output.
/// Use `reset()` to terminate a styled segment.
enum ANSI {
    /// Bold text styling.
    static func bold(_ text: String) -> String {
        "\u{001B}[1m\(text)\u{001B}[0m"
    }

    /// Dim/faint text styling.
    static func dim(_ text: String) -> String {
        "\u{001B}[2m\(text)\u{001B}[0m"
    }

    /// Red foreground color.
    static func red(_ text: String) -> String {
        "\u{001B}[31m\(text)\u{001B}[0m"
    }

    /// Blue foreground color.
    static func blue(_ text: String) -> String {
        "\u{001B}[34m\(text)\u{001B}[0m"
    }

    /// Cyan foreground color.
    static func cyan(_ text: String) -> String {
        "\u{001B}[36m\(text)\u{001B}[0m"
    }

    /// Yellow foreground color.
    static func yellow(_ text: String) -> String {
        "\u{001B}[33m\(text)\u{001B}[0m"
    }

    /// Green foreground color.
    static func green(_ text: String) -> String {
        "\u{001B}[32m\(text)\u{001B}[0m"
    }

    /// Italic text styling (limited terminal support).
    static func italic(_ text: String) -> String {
        "\u{001B}[3m\(text)\u{001B}[0m"
    }

    /// Reset all styling.
    static func reset() -> String {
        "\u{001B}[0m"
    }

    /// Clear the terminal screen.
    static func clear() -> String {
        "\u{001B}[2J\u{001B}[H"
    }

    /// Generate a colored REPL prompt based on the current permission mode.
    ///
    /// Maps each permission mode to a distinctive color so the user can
    /// identify the security level at a glance:
    /// - `.default` → green (safe: read-only auto-approved)
    /// - `.plan` → yellow (cautious: all tools need confirmation)
    /// - `.bypassPermissions` → red (dangerous: all auto-approved)
    /// - `.acceptEdits` → blue (edit-friendly: read + edit auto-approved)
    /// - `.auto` / `.dontAsk` → default/white (fully automatic)
    ///
    /// When stdout is not a tty (e.g. piped output, test environments),
    /// returns plain `"> "` without ANSI escape codes, unless `forceColor`
    /// is set to `true`.
    ///
    /// - Parameters:
    ///   - mode: The current permission mode.
    ///   - forceColor: When `true`, always generate ANSI codes regardless of
    ///     tty status. Useful for testing. Defaults to `false`.
    /// - Returns: A colored prompt string, or plain `"> "` if no tty.
    static func coloredPrompt(forMode mode: PermissionMode, forceColor: Bool = false) -> String {
        let prompt = "> "
        guard forceColor || isatty(STDOUT_FILENO) != 0 else { return prompt }
        let colorCode: String
        switch mode {
        case .default: colorCode = "\u{001B}[32m"   // green
        case .plan: colorCode = "\u{001B}[33m"       // yellow
        case .bypassPermissions: colorCode = "\u{001B}[31m" // red
        case .acceptEdits: colorCode = "\u{001B}[34m" // blue
        case .auto, .dontAsk: return prompt           // default — no color needed
        }
        return colorCode + prompt + "\u{001B}[0m"
    }

    /// Write a message to stderr safely, without force-unwrapping.
    ///
    /// Uses `?? Data()` fallback because `String.data(using: .utf8)` only
    /// returns nil for strings with non-Unicode scalars, which is impossible
    /// with our hardcoded ASCII error messages.
    static func writeToStderr(_ message: String) {
        FileHandle.standardError.write(message.data(using: .utf8) ?? Data())
    }
}
