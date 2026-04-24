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

// MARK: - AgentHolder

/// A class wrapper around Agent to allow mutation within REPLLoop's non-mutating methods.
///
/// Since REPLLoop is a struct and `start()` is non-mutating, we cannot directly
/// replace the `agent` property when `/resume` creates a new Agent. Wrapping it
/// in a class provides reference semantics so mutations are visible everywhere.
final class AgentHolder {
    var agent: Agent
    init(_ agent: Agent) { self.agent = agent }
}

// MARK: - ModeHolder

/// A class wrapper around PermissionMode to allow mutation within REPLLoop's non-mutating methods.
///
/// Uses the same class-wrapper pattern as ``AgentHolder`` and ``CostTracker``
/// so that ``REPLLoop`` — a struct with non-mutating methods — can update the
/// current mode when the user runs `/mode <mode>` and reflect the new color
/// on the next prompt.
final class ModeHolder: @unchecked Sendable {
    var mode: PermissionMode
    init(_ mode: PermissionMode) { self.mode = mode }
}

// MARK: - CostTracker

/// Tracks cumulative session cost and token usage across streaming queries.
///
/// Uses class reference semantics (like ``AgentHolder``) so that ``REPLLoop``
/// — a struct with non-mutating methods — can accumulate values across calls
/// without needing `mutating` access.
final class CostTracker: @unchecked Sendable {
    var cumulativeCostUsd: Double = 0.0
    var cumulativeInputTokens: Int = 0
    var cumulativeOutputTokens: Int = 0

    /// Reset all counters to zero (used by `/clear`).
    func reset() {
        cumulativeCostUsd = 0.0
        cumulativeInputTokens = 0
        cumulativeOutputTokens = 0
    }
}

// MARK: - REPLLoop

/// Interactive read-eval-print loop.
///
/// Reads user input, sends it to the Agent as a streaming query,
/// renders the response via OutputRenderer, and repeats until the user
/// exits with /exit, /quit, or EOF (Ctrl+D).
struct REPLLoop {
    let agentHolder: AgentHolder
    let renderer: OutputRenderer
    let reader: InputReading
    let toolNames: [String]
    let skillRegistry: SkillRegistry?
    let sessionStore: SessionStore?
    let parsedArgs: ParsedArgs?
    let costTracker: CostTracker
    let modeHolder: ModeHolder

    /// Convenience accessor for the current agent.
    var agent: Agent { agentHolder.agent }

    init(agent: Agent, renderer: OutputRenderer, reader: InputReading, toolNames: [String] = [], skillRegistry: SkillRegistry? = nil, sessionStore: SessionStore? = nil, parsedArgs: ParsedArgs? = nil, costTracker: CostTracker = CostTracker()) {
        self.agentHolder = AgentHolder(agent)
        self.renderer = renderer
        self.reader = reader
        self.toolNames = toolNames
        self.skillRegistry = skillRegistry
        self.sessionStore = sessionStore
        self.parsedArgs = parsedArgs
        self.costTracker = costTracker
        let initialMode = PermissionMode(rawValue: parsedArgs?.mode ?? "default") ?? .default
        self.modeHolder = ModeHolder(initialMode)
    }

    /// Start the REPL loop.
    ///
    /// Continues reading input and dispatching to the Agent until the user
    /// types /exit, /quit, or the input reader returns nil (EOF).
    ///
    /// Multiline support (Story 9.5):
    /// - Backslash continuation: lines ending with `\` enter continuation mode
    /// - Triple-quote mode: `"""` on its own line starts/ends a multiline block
    /// - Ctrl+C during multiline: cancels and returns to main prompt
    ///
    /// Signal handling:
    /// - Single Ctrl+C during streaming: interrupts Agent, re-shows prompt
    /// - Double Ctrl+C within 1s: exits CLI (breaks loop)
    /// - SIGTERM: breaks loop for graceful shutdown via closeAgentSafely()
    func start() async {
        var multilineBuffer: [String] = []
        var inMultiline = false
        var inTripleQuote = false

        while true {
            // Choose prompt based on multiline state
            let prompt: String
            if inMultiline || inTripleQuote {
                prompt = ANSI.coloredContinuationPrompt(forMode: modeHolder.mode, forceColor: true)
            } else {
                prompt = ANSI.coloredPrompt(forMode: modeHolder.mode, forceColor: true)
            }

            guard let rawInput = reader.readLine(prompt: prompt) else {
                break  // EOF (Ctrl+D)
            }

            // --- Ctrl+C / empty line handling ---
            // Empty input can mean Ctrl+C (signal) or the user pressed Enter on
            // a blank line.  In multiline mode we distinguish them via
            // SignalHandler: a pending .interrupt means Ctrl+C was pressed.
            // At the main prompt, empty lines are simply ignored.
            if rawInput.isEmpty {
                if inMultiline || inTripleQuote {
                    let sig = SignalHandler.check()
                    if sig == .interrupt || sig == .forceExit {
                        // Ctrl+C during multiline — cancel and return to main prompt
                        renderer.output.write("^C\n")
                        multilineBuffer = []
                        inMultiline = false
                        inTripleQuote = false
                        continue
                    }
                    // Plain Enter in multiline — accumulate as empty content line
                    multilineBuffer.append("")
                    continue
                }
                // Normal empty line at main prompt — ignore
                continue
            }

            let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)

            // --- Triple-quote mode ---
            if inTripleQuote {
                if trimmed == "\"\"\"" {
                    // End triple-quote mode
                    let fullInput = multilineBuffer.joined(separator: "\n")
                    multilineBuffer = []
                    inTripleQuote = false
                    guard !fullInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                    if await processInput(fullInput) { return }
                } else {
                    // Preserve original content (including indentation and empty lines)
                    multilineBuffer.append(rawInput)
                }
                continue
            }

            // --- Backslash continuation mode ---
            if inMultiline {
                let rstripped = rawInput.trimmingCharacters(in: .whitespaces)
                if rstripped.hasSuffix("\\") && rstripped != "\\" {
                    // Continue accumulating, strip trailing backslash
                    let lineWithoutSlash = String(rstripped.dropLast())
                    multilineBuffer.append(lineWithoutSlash)
                } else {
                    // Terminate continuation
                    multilineBuffer.append(rawInput)
                    let fullInput = multilineBuffer.joined(separator: "\n")
                    multilineBuffer = []
                    inMultiline = false
                    guard !fullInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                    if await processInput(fullInput) { return }
                }
                continue
            }

            // --- Not in multiline mode: check for entry conditions ---

            // Triple-quote entry: entire trimmed line is """
            if trimmed == "\"\"\"" {
                inTripleQuote = true
                multilineBuffer = []
                continue
            }

            // Backslash entry: line ends with \ (after rstripping whitespace)
            // but bare "\" alone is not a continuation
            let rstripped = rawInput.trimmingCharacters(in: .whitespaces)
            if rstripped.hasSuffix("\\") && rstripped != "\\" {
                let lineWithoutSlash = String(rstripped.dropLast())
                multilineBuffer = [lineWithoutSlash]
                inMultiline = true
                continue
            }

            // --- Normal single-line input (existing behavior) ---
            guard !trimmed.isEmpty else { continue }
            if await processInput(trimmed) { return }
        }
    }

    /// Process a complete input (after multiline merging if applicable).
    ///
    /// Handles signal checking, slash command dispatch, and Agent streaming.
    /// Returns true if the REPL should exit.
    private func processInput(_ input: String) async -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Check for pending signals between reads.
        let preCheck = SignalHandler.check()
        if preCheck == .terminate || preCheck == .forceExit {
            return true
        }
        if preCheck == .interrupt {
            renderer.output.write("^C\n")
            return false
        }

        // Slash commands
        if trimmed.hasPrefix("/") {
            return await handleSlashCommand(trimmed)
        }

        // Send to Agent and render stream with interrupt checking.
        let stream = agentHolder.agent.stream(trimmed)
        for await message in stream {
            // Intercept result messages to track cumulative cost
            if case .result(let data) = message {
                costTracker.cumulativeCostUsd += data.totalCostUsd
                if let usage = data.usage {
                    costTracker.cumulativeInputTokens += usage.inputTokens
                    costTracker.cumulativeOutputTokens += usage.outputTokens
                }
            }
            let event = SignalHandler.check()
            if event == .interrupt || event == .forceExit || event == .terminate {
                agentHolder.agent.interrupt()
                renderer.output.write("^C\n")
                if event == .forceExit || event == .terminate {
                    return true
                }
                break
            }
            renderer.render(message)
        }
        // Check for pending signals after stream completes.
        let postCheck = SignalHandler.check()
        if postCheck == .interrupt || postCheck == .forceExit || postCheck == .terminate {
            agentHolder.agent.interrupt()
            renderer.output.write("^C\n")
            if postCheck == .forceExit || postCheck == .terminate {
                return true
            }
        }

        return false
    }

    /// Handle a slash command.
    /// Returns true if the REPL should exit.
    private func handleSlashCommand(_ input: String) async -> Bool {
        let parts = input.split(separator: " ", maxSplits: 1)
        let command = parts[0].lowercased()

        switch command {
        case "/exit", "/quit":
            return true  // AC#5
        case "/help":
            printHelp()   // AC#4
        case "/tools":
            printTools()
        case "/skills":
            printSkills()
        case "/sessions":
            await handleSessions()
        case "/resume":
            await handleResume(parts: parts)
        case "/model":
            handleModel(parts: parts)
        case "/mode":
            handleMode(parts: parts)
        case "/cost":
            handleCost()
        case "/clear":
            handleClear()
        case "/fork":
            await handleFork()
        case "/mcp":
            await handleMcp(parts: parts)
        default:
            // Unknown command
            renderer.output.write("Unknown command: \(input). Type /help for available commands.\r\n")
        }
        return false
    }

    /// Print the help text listing available REPL commands.
    private func printHelp() {
        let help = """
        Available commands:
          /help              Show this help message
          /tools             Show loaded tools
          /skills            Show loaded skills
          /model <name>      Switch the LLM model
          /mode <mode>       Switch permission mode
          /cost              Show cumulative session cost and token usage
          /clear             Clear conversation history and reset cost tracker
          /sessions          List saved sessions
          /resume <id>       Resume a saved session
          /fork              Fork the current session into a new branch
          /mcp status              Show MCP server connection status
          /mcp reconnect <name>    Reconnect an MCP server
          /exit              Exit the REPL
          /quit              Exit the REPL
        """
        renderer.output.write(help.replacingOccurrences(of: "\n", with: "\r\n") + "\r\n")
    }

    /// Print the list of loaded tools, sorted alphabetically.
    private func printTools() {
        if toolNames.isEmpty {
            renderer.output.write("No tools loaded.\r\n")
        } else {
            let sorted = toolNames.sorted()
            renderer.output.write("Loaded tools (\(sorted.count)):\r\n")
            for name in sorted {
                renderer.output.write("  \(name)\r\n")
            }
        }
    }

    /// Print the list of loaded skills with name and description, sorted by name.
    private func printSkills() {
        guard let registry = skillRegistry else {
            renderer.output.write("No skills loaded.\r\n")
            return
        }

        let skills = registry.allSkills
        if skills.isEmpty {
            renderer.output.write("No skills loaded.\r\n")
        } else {
            let sorted = skills.sorted { $0.name < $1.name }
            renderer.output.write("Available skills (\(sorted.count)):\r\n")
            for skill in sorted {
                renderer.output.write("  \(skill.name): \(skill.description)\r\n")
            }
        }
    }

    // MARK: - /model command (Story 6.3)

    /// Handle the /model <name> command: dynamically switch the LLM model.
    private func handleModel(parts: [Substring]) {
        // No argument (input is trimmed before reaching here, so /model <spaces>
        // is indistinguishable from bare /model).
        guard parts.count > 1 else {
            renderer.output.write("Usage: /model <model-name> (empty or missing model name)\r\n")
            return
        }

        let modelName = String(parts[1]).trimmingCharacters(in: .whitespaces)

        // Whitespace-only argument
        guard !modelName.isEmpty else {
            renderer.output.write("Error: Model name cannot be empty.\r\n")
            return
        }

        do {
            try agentHolder.agent.switchModel(modelName)
            renderer.output.write("Model switched to \(modelName)\r\n")
        } catch {
            renderer.output.write("Error: \(error.localizedDescription)\r\n")
        }
    }

    // MARK: - /mode command (Story 6.3)

    /// Handle the /mode <mode> command: dynamically switch the permission mode.
    private func handleMode(parts: [Substring]) {
        guard parts.count > 1, !parts[1].trimmingCharacters(in: .whitespaces).isEmpty else {
            renderer.output.write("Usage: /mode <mode>\r\n")
            return
        }

        let modeName = String(parts[1]).trimmingCharacters(in: .whitespaces)

        guard let mode = PermissionMode(rawValue: modeName) else {
            let validModes = PermissionMode.allCases.map(\.rawValue).joined(separator: ", ")
            renderer.output.write("Invalid mode '\(modeName)'. Valid modes: \(validModes)\r\n")
            return
        }

        agentHolder.agent.setPermissionMode(mode)
        modeHolder.mode = mode
        renderer.output.write("Permission mode switched to \(mode.rawValue)\r\n")
    }

    // MARK: - /cost command (Story 6.3)

    /// Handle the /cost command: display cumulative session cost and token usage.
    private func handleCost() {
        renderer.output.write(String(format: "Session cost: $%.4f (input: %d tokens, output: %d tokens)\r\n",
            costTracker.cumulativeCostUsd,
            costTracker.cumulativeInputTokens,
            costTracker.cumulativeOutputTokens
        ))
    }

    // MARK: - /clear command (Story 6.3)

    /// Handle the /clear command: clear conversation history and reset cost tracker.
    private func handleClear() {
        agentHolder.agent.clear()
        costTracker.reset()
        renderer.output.write("Conversation cleared. Starting a new session.\r\n")
    }

    // MARK: - /fork command (Story 7.5)

    /// Handle the /fork command: fork the current session into a new branch.
    ///
    /// Creates a new session that copies the conversation history from the
    /// current session, then switches the agent to the new forked session.
    private func handleFork() async {
        // AC#4: Verify SessionStore is available
        guard let store = sessionStore else {
            renderer.output.write("No session storage available.\r\n")
            return
        }

        // AC#5: Verify current session exists
        guard let currentSessionId = agentHolder.agent.getSessionId() else {
            renderer.output.write("No active session to fork.\r\n")
            return
        }

        // AC#1: Fork the session via SessionStore
        let forkedId: String
        do {
            guard let id = try await store.fork(sourceSessionId: currentSessionId) else {
                renderer.output.write("Error: Source session not found.\r\n")
                return
            }
            forkedId = id
        } catch {
            // AC#6: Display error message, original session unaffected
            renderer.output.write("Error forking session: \(error.localizedDescription)\r\n")
            return
        }

        // Create a new Agent using the forked session ID
        guard let args = parsedArgs else {
            renderer.output.write("Cannot fork: configuration not available.\r\n")
            return
        }

        // Use struct copy to preserve ALL fields (explicitlySet, customTools, etc.)
        var forkArgs = args
        forkArgs.sessionId = forkedId

        do {
            let (newAgent, _, _) = try await AgentFactory.createAgent(from: forkArgs)
            // Save current agent session
            do {
                try await agentHolder.agent.close()
            } catch {
                renderer.output.write("Warning: failed to save current session (\(error.localizedDescription)).\r\n")
            }
            // Switch to forked session
            agentHolder.agent = newAgent
            // AC#3: Display confirmation with short ID
            let shortId = String(forkedId.prefix(8))
            renderer.output.write("Session forked. New session: \(shortId)...\r\n")
        } catch {
            // AC#7: Clean up orphaned session if agent creation fails
            _ = try? await store.delete(sessionId: forkedId)
            renderer.output.write("Error creating forked session: \(error.localizedDescription)\r\n")
        }
    }

    // MARK: - /mcp command (Story 7.6)

    /// Handle the /mcp command group: dispatch to subcommands.
    private func handleMcp(parts: [Substring]) async {
        // Parse subcommand and optional argument from parts[1]
        let subcommand: String
        let subArgs: String?

        if parts.count > 1 {
            let subParts = parts[1].split(separator: " ", maxSplits: 1)
            subcommand = String(subParts[0]).lowercased()
            subArgs = subParts.count > 1 ? String(subParts[1]).trimmingCharacters(in: .whitespaces) : nil
        } else {
            subcommand = ""
            subArgs = nil
        }

        switch subcommand {
        case "status":
            await handleMcpStatus()
        case "reconnect":
            guard let name = subArgs, !name.isEmpty else {
                renderer.output.write("Usage: /mcp reconnect <name>\r\n")
                return
            }
            await handleMcpReconnect(serverName: name)
        default:
            // AC#5: No subcommand or unknown subcommand shows help
            renderer.output.write("MCP commands:\r\n")
            renderer.output.write("  /mcp status              Show MCP server status\r\n")
            renderer.output.write("  /mcp reconnect <name>    Reconnect a server\r\n")
        }
    }

    /// Handle /mcp status: display connection status of all MCP servers.
    private func handleMcpStatus() async {
        let statuses = await agentHolder.agent.mcpServerStatus()
        if statuses.isEmpty {
            renderer.output.write("No MCP servers configured.\r\n")
            return
        }
        renderer.output.write("MCP Servers:\r\n")
        for (name, status) in statuses.sorted(by: { $0.key < $1.key }) {
            let toolCount = status.tools.count
            renderer.output.write("  \(name): \(status.status.rawValue)")
            if let info = status.serverInfo {
                renderer.output.write(" (\(info.name) v\(info.version))")
            }
            if !status.tools.isEmpty {
                renderer.output.write(" — \(toolCount) tool\(toolCount == 1 ? "" : "s")")
            }
            if let error = status.error {
                renderer.output.write("\n    Error: \(error)")
            }
            renderer.output.write("\r\n")
        }
    }

    /// Handle /mcp reconnect <name>: reconnect a specific MCP server.
    private func handleMcpReconnect(serverName: String) async {
        do {
            try await agentHolder.agent.reconnectMcpServer(name: serverName)
            renderer.output.write("Reconnected \(serverName).\r\n")
        } catch is MCPClientManagerError {
            renderer.output.write("Server not found: \(serverName)\r\n")
        } catch {
            renderer.output.write("Error reconnecting \(serverName): \(error.localizedDescription)\r\n")
        }
    }

    // MARK: - /sessions command (Story 3.2)

    /// Handle the /sessions command: list saved sessions.
    private func handleSessions() async {
        guard let store = sessionStore else {
            renderer.output.write("No session storage available.\r\n")
            return
        }

        do {
            let sessions = try await store.list()

            if sessions.isEmpty {
                renderer.output.write("No saved sessions.\r\n")
                return
            }

            renderer.output.write("Saved sessions (\(sessions.count)):\r\n")
            for session in sessions {
                let shortId = String(session.id.prefix(8))
                let timeStr = formatRelativeTime(session.updatedAt)
                let preview: String
                if let firstPrompt = session.firstPrompt {
                    preview = String(firstPrompt.prefix(50))
                } else {
                    preview = await extractFirstPrompt(store: store, sessionId: session.id, messageCount: session.messageCount) ?? "(no preview)"
                }
                renderer.output.write("  \(shortId)  \(timeStr)  \(session.messageCount) msgs  \"\(preview)\"\r\n")
            }
        } catch {
            renderer.output.write("Error listing sessions: \(error.localizedDescription)\r\n")
        }
    }

    /// Extract the first user message from a session as a preview fallback.
    private func extractFirstPrompt(store: SessionStore, sessionId: String, messageCount: Int) async -> String? {
        guard messageCount > 0 else { return nil }
        guard let data = try? await store.load(sessionId: sessionId, limit: 1) else { return nil }
        let messages = data.messages
        for msg in messages {
            guard msg["role"] as? String == "user" else { continue }
            if let content = msg["content"] as? String {
                return String(content.prefix(50))
            }
            if let content = msg["content"] as? [[String: Any]] {
                for block in content {
                    if block["type"] as? String == "text", let text = block["text"] as? String {
                        return String(text.prefix(50))
                    }
                }
            }
        }
        return nil
    }

    // MARK: - /resume command (Story 3.2)

    /// Handle the /resume <id> command: resume a saved session.
    private func handleResume(parts: [Substring]) async {
        guard let store = sessionStore else {
            renderer.output.write("No session storage available.\r\n")
            return
        }

        // Check for missing ID argument
        guard parts.count > 1, !parts[1].isEmpty else {
            renderer.output.write("Usage: /resume <session-id>\r\n")
            return
        }

        let inputId = String(parts[1])

        // Resolve session ID — try exact match first, then prefix match
        let sessionId: String
        do {
            if let _ = try await store.load(sessionId: inputId) {
                sessionId = inputId
            } else {
                let matches = try await store.list().filter { $0.id.hasPrefix(inputId) }
                if matches.isEmpty {
                    renderer.output.write("Session not found: \(inputId)\r\n")
                    return
                } else if matches.count > 1 {
                    renderer.output.write("Ambiguous ID '\(inputId)' matches \(matches.count) sessions. Use a longer prefix.\r\n")
                    return
                }
                sessionId = matches[0].id
            }
        } catch {
            renderer.output.write("Error loading session: \(error.localizedDescription)\r\n")
            return
        }

        // Create a new Agent with the target sessionId using the stored ParsedArgs
        guard let args = parsedArgs else {
            renderer.output.write("Cannot resume session: configuration not available.\r\n")
            return
        }

        // Use struct copy to preserve ALL fields (explicitlySet, customTools, etc.)
        var resumeArgs = args
        resumeArgs.sessionId = sessionId

        do {
            let (newAgent, _, _) = try await AgentFactory.createAgent(from: resumeArgs)
            do {
                try await agentHolder.agent.close()
            } catch {
                renderer.output.write("Warning: failed to save current session (\(error.localizedDescription)). Session history may not be preserved.\r\n")
            }
            agentHolder.agent = newAgent

            let shortId = String(sessionId.prefix(8))
            renderer.output.write("Resumed session \(shortId)... (session history loaded)\r\n")
        } catch {
            renderer.output.write("Error creating resumed session: \(error.localizedDescription)\r\n")
        }
    }

    // MARK: - Time formatting

    /// Format a date as a relative time string (e.g. "2 hours ago", "yesterday").
    /// Falls back to absolute date for dates more than 7 days ago.
    private func formatRelativeTime(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else if interval < 172800 {
            return "yesterday"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days) days ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}
