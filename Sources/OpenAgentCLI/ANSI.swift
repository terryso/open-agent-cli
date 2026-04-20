import Foundation

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

    /// Cyan foreground color.
    static func cyan(_ text: String) -> String {
        "\u{001B}[36m\(text)\u{001B}[0m"
    }

    /// Yellow foreground color.
    static func yellow(_ text: String) -> String {
        "\u{001B}[33m\(text)\u{001B}[0m"
    }

    /// Reset all styling.
    static func reset() -> String {
        "\u{001B}[0m"
    }

    /// Clear the terminal screen.
    static func clear() -> String {
        "\u{001B}[2J\u{001B}[H"
    }
}
