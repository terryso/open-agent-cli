import Foundation
import OpenAgentSDK

// MARK: - InputReading Protocol

/// Protocol for reading terminal input, enabling testability.
///
/// Abstracts stdin reading so REPLLoop can be tested with a mock
/// that returns predefined input sequences.
protocol InputReading: Sendable {
    /// Read a line of input with the given prompt displayed.
    /// Returns nil on EOF (e.g. Ctrl+D).
    func readLine(prompt: String) -> String?
}

// MARK: - FileHandleInputReader

/// Reads input from standard input via Swift's built-in readLine.
///
/// Production implementation of InputReading. Writes the prompt to stdout
/// and reads a line from stdin using Swift's readLine() function.
struct FileHandleInputReader: InputReading {
    func readLine(prompt: String) -> String? {
        // Write prompt to stdout (no trailing newline)
        FileHandle.standardOutput.write((prompt).data(using: .utf8) ?? Data())
        // Read line from stdin via Swift's built-in readLine
        return Swift.readLine()
    }
}

// MARK: - REPLLoop

/// Interactive read-eval-print loop.
///
/// Reads user input, sends it to the Agent as a streaming query,
/// renders the response via OutputRenderer, and repeats until the user
/// exits with /exit, /quit, or EOF (Ctrl+D).
struct REPLLoop {
    let agent: Agent
    let renderer: OutputRenderer
    let reader: InputReading
    let toolNames: [String]

    init(agent: Agent, renderer: OutputRenderer, reader: InputReading, toolNames: [String] = []) {
        self.agent = agent
        self.renderer = renderer
        self.reader = reader
        self.toolNames = toolNames
    }

    /// Start the REPL loop.
    ///
    /// Continues reading input and dispatching to the Agent until the user
    /// types /exit, /quit, or the input reader returns nil (EOF).
    func start() async {
        while let input = reader.readLine(prompt: "> ") {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

            // AC#6: Ignore empty/whitespace-only lines
            guard !trimmed.isEmpty else { continue }

            // Slash commands
            if trimmed.hasPrefix("/") {
                if handleSlashCommand(trimmed) { break }
                continue
            }

            // AC#2, AC#3: Send to Agent and render stream
            do {
                let stream = agent.stream(trimmed)
                await renderer.renderStream(stream)
            } catch {
                renderer.output.write("Error: \(error.localizedDescription)\n")
                // Continue REPL loop -- never crash at REPL boundary
            }
        }
    }

    /// Handle a slash command.
    /// Returns true if the REPL should exit.
    private func handleSlashCommand(_ input: String) -> Bool {
        let parts = input.split(separator: " ", maxSplits: 1)
        let command = parts[0].lowercased()

        switch command {
        case "/exit", "/quit":
            return true  // AC#5
        case "/help":
            printHelp()   // AC#4
        case "/tools":
            printTools()
        default:
            // Unknown command
            renderer.output.write("Unknown command: \(input). Type /help for available commands.\n")
        }
        return false
    }

    /// Print the help text listing available REPL commands.
    private func printHelp() {
        let help = """
        Available commands:
          /help          Show this help message
          /tools         Show loaded tools
          /exit          Exit the REPL
          /quit          Exit the REPL
        """
        renderer.output.write("\(help)\n")
    }

    /// Print the list of loaded tools, sorted alphabetically.
    private func printTools() {
        if toolNames.isEmpty {
            renderer.output.write("No tools loaded.\n")
        } else {
            let sorted = toolNames.sorted()
            renderer.output.write("Loaded tools (\(sorted.count)):\n")
            for name in sorted {
                renderer.output.write("  \(name)\n")
            }
        }
    }
}
