import Foundation
import LineNoise

// MARK: - LinenoiseInputReader

/// Input reader backed by linenoise-swift, providing line editing,
/// command history navigation, and cross-session history persistence.
///
/// Conforms to ``InputReading`` so it can be used as a drop-in replacement
/// for ``FileHandleInputReader`` in the REPL loop.
///
/// History is stored at `~/.openagent/history` with a 1000-entry FIFO limit.
/// Ctrl+C during input returns an empty string (REPLLoop ignores it and
/// re-displays the prompt). Ctrl+D returns nil (triggers REPL exit).
final class LinenoiseInputReader: InputReading, @unchecked Sendable {

    private let linenoise: LineNoise
    private let historyPath: String

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
        self.linenoise = LineNoise()
        self.linenoise.setHistoryMaxLength(1000)
        self.historyPath = historyPath

        // Ensure parent directory exists
        let dir = (historyPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true)

        // Load history (AC#6: file missing/corrupted -- continue with empty history)
        do {
            try linenoise.loadHistory(fromFile: historyPath)
        } catch {
            // Silently continue -- first launch or corrupted file
        }
    }

    // MARK: - InputReading Conformance

    func readLine(prompt: String) -> String? {
        // Linenoise uses prompt.count for cursor positioning, which breaks with
        // ANSI escape codes (it counts invisible bytes, shifting the cursor right).
        // Strip ANSI codes and pass only the visible text.
        let visiblePrompt = stripANSI(prompt)

        // Ensure cursor is at column 0 before linenoise takes over the terminal.
        // Previous output (welcome screen, command results) may leave the cursor
        // at a non-zero column because linenoise disables OPOST in raw mode,
        // which prevents automatic \n→\r\n conversion.
        FileHandle.standardOutput.write("\r".data(using: .utf8) ?? Data())

        do {
            let line = try linenoise.getLine(prompt: visiblePrompt)
            // Linenoise's editLine returns on Enter without emitting a newline,
            // and raw mode disables OPOST (so \n won't become \r\n).
            // Write explicit \r\n so subsequent output starts on a fresh line.
            FileHandle.standardOutput.write("\r\n".data(using: .utf8) ?? Data())
            if !line.isEmpty {
                linenoise.addHistory(line)
                saveHistorySilently()
            }
            return line
        } catch LinenoiseError.CTRL_C {
            FileHandle.standardOutput.write("\r\n".data(using: .utf8) ?? Data())
            return ""
        } catch {
            return nil
        }
    }

    /// Strip all ANSI CSI escape sequences from a string.
    private func stripANSI(_ text: String) -> String {
        // Match ESC [ ... m (SGR sequences used for colors/styles)
        let pattern = "\u{001B}\\[[0-9;]*m"
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    // MARK: - Tab Completion

    /// Register a Tab-completion callback.
    ///
    /// Wraps linenoise-swift's `setCompletionCallback`, keeping the linenoise
    /// instance private. The callback receives the current input buffer text
    /// and returns a list of matching completion candidates.
    func setCompletionCallback(_ callback: @escaping (String) -> [String]) {
        linenoise.setCompletionCallback(callback)
    }

    // MARK: - Public Helpers (used by tests)

    /// Add a history entry directly (bypasses readLine, used for testing).
    ///
    /// Empty and whitespace-only strings are silently skipped (AC#9).
    /// After adding, the history file is saved immediately so that
    /// persistence can be verified.
    func addHistoryEntry(_ entry: String) {
        guard !entry.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        linenoise.addHistory(entry)
        saveHistorySilently()
    }

    /// Number of entries currently held in the history buffer.
    ///
    /// Since linenoise-swift's `History` class is internal, we determine
    /// the count by re-loading the persisted history file. This is only
    /// used in tests.
    var historyCount: Int {
        do {
            let content = try String(contentsOfFile: historyPath, encoding: .utf8)
            let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
            return lines.count
        } catch {
            return 0
        }
    }

    // MARK: - Private

    private func saveHistorySilently() {
        do {
            try linenoise.saveHistory(toFile: historyPath)
        } catch {
            // Save failure is non-blocking -- the history will be lost
            // if the process exits, but functionality is unaffected.
        }
    }
}
