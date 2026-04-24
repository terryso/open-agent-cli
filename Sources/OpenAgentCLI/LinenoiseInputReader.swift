import Foundation
import LineReader

// MARK: - LinenoiseInputReader

/// Input reader backed by CommandLineKit's LineReader, providing line editing,
/// command history navigation, and cross-session history persistence.
///
/// Conforms to ``InputReading`` so it can be used as a drop-in replacement
/// for ``FileHandleInputReader`` in the REPL loop.
///
/// History is stored at `~/.openagent/history` with a 1000-entry FIFO limit.
/// Ctrl+C during input returns an empty string (REPLLoop ignores it and
/// re-displays the prompt). Ctrl+D returns nil (triggers REPL exit).
final class LinenoiseInputReader: InputReading, @unchecked Sendable {

    private let lineReader: LineReader?
    private let historyPath: String
    private var historyEntries: [String] = []

    // Exposed for testing (AC#5 verification)
    private(set) var historyMaxLength: Int = 1000

    // MARK: - Initializers

    /// Initialize with the default history path (`~/.openagent/history`).
    convenience init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser.path + "/.openagent"
        self.init(historyPath: dir + "/history")
    }

    /// Designated initializer with a custom history file path.
    ///
    /// Used for testing with temporary directories. Creates the parent
    /// directory if it does not exist, and loads any existing history.
    init(historyPath: String) {
        self.lineReader = LineReader()
        self.historyPath = historyPath

        // Ensure parent directory exists
        let dir = (historyPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true)

        // Load history from file
        historyEntries = Self.loadHistoryFromFile(historyPath)

        // Configure LineReader if available (TTY)
        if let lr = lineReader {
            lr.setHistoryMaxLength(UInt(historyMaxLength))
            for entry in historyEntries {
                lr.addHistory(entry)
            }
        }
    }

    // MARK: - InputReading Conformance

    func readLine(prompt: String) -> String? {
        guard let lr = lineReader else {
            // Non-TTY fallback
            FileHandle.standardOutput.write((prompt).data(using: .utf8) ?? Data())
            return Swift.readLine()
        }

        // LineReader uses prompt.count for cursor positioning, which breaks with
        // ANSI escape codes (it counts invisible bytes, shifting the cursor right).
        // Strip ANSI codes from the prompt passed to LineReader, but apply the
        // color at the terminal level so input text still appears colored.
        let visiblePrompt = stripANSI(prompt)
        let colorCode = extractANSIColor(prompt)

        // Ensure cursor is at column 0 before LineReader takes over the terminal.
        FileHandle.standardOutput.write("\r".data(using: .utf8) ?? Data())

        // Set terminal color before LineReader starts editing.
        // This makes the prompt AND user input appear in the mode color.
        if let color = colorCode {
            FileHandle.standardOutput.write(color.data(using: .utf8) ?? Data())
        }

        do {
            let line = try lr.readLine(prompt: visiblePrompt)

            // Reset color after LineReader returns.
            if colorCode != nil {
                FileHandle.standardOutput.write("\u{001B}[0m".data(using: .utf8) ?? Data())
            }

            if !line.isEmpty {
                addHistoryEntry(line)
            }
            return line
        } catch LineReaderError.CTRLC {
            if colorCode != nil {
                FileHandle.standardOutput.write("\u{001B}[0m".data(using: .utf8) ?? Data())
            }
            FileHandle.standardOutput.write("\r\n".data(using: .utf8) ?? Data())
            return ""
        } catch {
            return nil
        }
    }

    /// Strip all ANSI CSI escape sequences from a string.
    private func stripANSI(_ text: String) -> String {
        let pattern = "\u{001B}\\[[0-9;]*m"
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    /// Extract the first ANSI SGR color code from a string.
    private func extractANSIColor(_ text: String) -> String? {
        let pattern = "\u{001B}\\[[0-9;]*m"
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        return String(text[range])
    }

    // MARK: - Tab Completion

    /// Register a Tab-completion callback.
    ///
    /// Wraps LineReader's `setCompletionCallback`, keeping the
    /// instance private. The callback receives the current input buffer text
    /// and returns a list of matching completion candidates.
    func setCompletionCallback(_ callback: @escaping (String) -> [String]) {
        lineReader?.setCompletionCallback(callback)
    }

    // MARK: - Public Helpers (used by tests)

    /// Add a history entry directly (bypasses readLine, used for testing).
    ///
    /// Empty and whitespace-only strings are silently skipped (AC#9).
    /// After adding, the history file is saved immediately so that
    /// persistence can be verified.
    func addHistoryEntry(_ entry: String) {
        guard !entry.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Don't add duplicate at end
        if historyEntries.last == entry { return }

        historyEntries.append(entry)

        // Enforce FIFO limit
        if historyEntries.count > historyMaxLength {
            historyEntries.removeFirst()
        }

        lineReader?.addHistory(entry)
        saveHistorySilently()
    }

    /// Number of entries currently held in the history buffer.
    ///
    /// Determined by reading the persisted history file. This is only
    /// used in tests.
    var historyCount: Int {
        return historyEntries.count
    }

    // MARK: - Private

    private func saveHistorySilently() {
        let content = historyEntries.joined(separator: "\n")
        try? content.write(toFile: historyPath, atomically: true, encoding: .utf8)
    }

    private static func loadHistoryFromFile(_ path: String) -> [String] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        return content.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }
}
