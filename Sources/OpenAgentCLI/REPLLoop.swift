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

// MARK: - CostTracker

/// Tracks cumulative session cost and token usage across streaming queries.
///
/// Uses class reference semantics (like ``AgentHolder``) so that ``REPLLoop``
/// — a struct with non-mutating methods — can accumulate values across calls
/// without needing `mutating` access.
final class CostTracker {
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
    }

    /// Start the REPL loop.
    ///
    /// Continues reading input and dispatching to the Agent until the user
    /// types /exit, /quit, or the input reader returns nil (EOF).
    ///
    /// Signal handling:
    /// - Single Ctrl+C during streaming: interrupts Agent, re-shows prompt
    /// - Double Ctrl+C within 1s: exits CLI (breaks loop)
    /// - SIGTERM: breaks loop for graceful shutdown via closeAgentSafely()
    func start() async {
        while let input = reader.readLine(prompt: "> ") {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

            // AC#6: Ignore empty/whitespace-only lines
            guard !trimmed.isEmpty else { continue }

            // Check for pending signals between reads.
            // This catches SIGTERM that arrived while waiting for input,
            // and any leftover interrupt state from previous iterations.
            let preCheck = SignalHandler.check()
            if preCheck == .terminate || preCheck == .forceExit {
                break
            }
            // If an interrupt arrived while waiting for input (idle state),
            // just clear it -- the user pressed Ctrl+C at the prompt.
            // Output ^C and re-show the prompt (continue the loop).
            if preCheck == .interrupt {
                renderer.output.write("^C\n")
                continue
            }

            // Slash commands
            if trimmed.hasPrefix("/") {
                if await handleSlashCommand(trimmed) { break }
                continue
            }

            // AC#2, AC#3: Send to Agent and render stream with interrupt checking.
            // Instead of using renderer.renderStream(), we manually iterate
            // the stream so we can check SignalHandler between messages.
            do {
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
                            return  // Exit REPL immediately
                        }
                        break  // Break inner stream loop, continue REPL while loop
                    }
                    renderer.render(message)
                }
                // Also check for pending signals after stream completes.
                // This handles the case where the signal arrives during the
                // last stream iteration but is only processed after for-await exits.
                let postCheck = SignalHandler.check()
                if postCheck == .interrupt || postCheck == .forceExit || postCheck == .terminate {
                    agentHolder.agent.interrupt()
                    renderer.output.write("^C\n")
                    if postCheck == .forceExit || postCheck == .terminate {
                        return
                    }
                }
            } catch {
                renderer.output.write("Error: \(error.localizedDescription)\n")
                // Continue REPL loop -- never crash at REPL boundary
            }
        }
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
          /exit              Exit the REPL
          /quit              Exit the REPL
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

    /// Print the list of loaded skills with name and description, sorted by name.
    private func printSkills() {
        guard let registry = skillRegistry else {
            renderer.output.write("No skills loaded.\n")
            return
        }

        let skills = registry.allSkills
        if skills.isEmpty {
            renderer.output.write("No skills loaded.\n")
        } else {
            let sorted = skills.sorted { $0.name < $1.name }
            renderer.output.write("Available skills (\(sorted.count)):\n")
            for skill in sorted {
                renderer.output.write("  \(skill.name): \(skill.description)\n")
            }
        }
    }

    // MARK: - /model command (Story 6.3)

    /// Handle the /model <name> command: dynamically switch the LLM model.
    private func handleModel(parts: [Substring]) {
        // No argument (input is trimmed before reaching here, so /model <spaces>
        // is indistinguishable from bare /model).
        guard parts.count > 1 else {
            renderer.output.write("Usage: /model <model-name> (empty or missing model name)\n")
            return
        }

        let modelName = String(parts[1]).trimmingCharacters(in: .whitespaces)

        // Whitespace-only argument
        guard !modelName.isEmpty else {
            renderer.output.write("Error: Model name cannot be empty.\n")
            return
        }

        do {
            try agentHolder.agent.switchModel(modelName)
            renderer.output.write("Model switched to \(modelName)\n")
        } catch {
            renderer.output.write("Error: \(error.localizedDescription)\n")
        }
    }

    // MARK: - /mode command (Story 6.3)

    /// Handle the /mode <mode> command: dynamically switch the permission mode.
    private func handleMode(parts: [Substring]) {
        guard parts.count > 1, !parts[1].trimmingCharacters(in: .whitespaces).isEmpty else {
            renderer.output.write("Usage: /mode <mode>\n")
            return
        }

        let modeName = String(parts[1]).trimmingCharacters(in: .whitespaces)

        guard let mode = PermissionMode(rawValue: modeName) else {
            let validModes = PermissionMode.allCases.map(\.rawValue).joined(separator: ", ")
            renderer.output.write("Invalid mode '\(modeName)'. Valid modes: \(validModes)\n")
            return
        }

        agentHolder.agent.setPermissionMode(mode)
        renderer.output.write("Permission mode switched to \(mode.rawValue)\n")
    }

    // MARK: - /cost command (Story 6.3)

    /// Handle the /cost command: display cumulative session cost and token usage.
    private func handleCost() {
        renderer.output.write(String(format: "Session cost: $%.4f (input: %d tokens, output: %d tokens)\n",
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
        renderer.output.write("Conversation cleared. Starting a new session.\n")
    }

    // MARK: - /fork command (Story 7.5)

    /// Handle the /fork command: fork the current session into a new branch.
    ///
    /// Creates a new session that copies the conversation history from the
    /// current session, then switches the agent to the new forked session.
    private func handleFork() async {
        // AC#4: Verify SessionStore is available
        guard let store = sessionStore else {
            renderer.output.write("No session storage available.\n")
            return
        }

        // AC#5: Verify current session exists
        guard let currentSessionId = agentHolder.agent.getSessionId() else {
            renderer.output.write("No active session to fork.\n")
            return
        }

        // AC#1: Fork the session via SessionStore
        let forkedId: String
        do {
            guard let id = try await store.fork(sourceSessionId: currentSessionId) else {
                renderer.output.write("Error: Source session not found.\n")
                return
            }
            forkedId = id
        } catch {
            // AC#6: Display error message, original session unaffected
            renderer.output.write("Error forking session: \(error.localizedDescription)\n")
            return
        }

        // Create a new Agent using the forked session ID
        guard let args = parsedArgs else {
            renderer.output.write("Cannot fork: configuration not available.\n")
            return
        }

        let forkArgs = ParsedArgs(
            helpRequested: args.helpRequested,
            versionRequested: args.versionRequested,
            prompt: args.prompt,
            model: args.model,
            apiKey: args.apiKey,
            baseURL: args.baseURL,
            provider: args.provider,
            mode: args.mode,
            tools: args.tools,
            mcpConfigPath: args.mcpConfigPath,
            hooksConfigPath: args.hooksConfigPath,
            skillDir: args.skillDir,
            skillName: args.skillName,
            sessionId: forkedId,
            noRestore: args.noRestore,
            maxTurns: args.maxTurns,
            maxBudgetUsd: args.maxBudgetUsd,
            systemPrompt: args.systemPrompt,
            thinking: args.thinking,
            quiet: args.quiet,
            output: args.output,
            logLevel: args.logLevel,
            debug: args.debug,
            toolAllow: args.toolAllow,
            toolDeny: args.toolDeny,
            shouldExit: args.shouldExit,
            exitCode: args.exitCode,
            errorMessage: args.errorMessage,
            helpMessage: args.helpMessage
        )

        do {
            let (newAgent, _) = try await AgentFactory.createAgent(from: forkArgs)
            // Save current agent session
            do {
                try await agentHolder.agent.close()
            } catch {
                renderer.output.write("Warning: failed to save current session (\(error.localizedDescription)).\n")
            }
            // Switch to forked session
            agentHolder.agent = newAgent
            // AC#3: Display confirmation with short ID
            let shortId = String(forkedId.prefix(8))
            renderer.output.write("Session forked. New session: \(shortId)...\n")
        } catch {
            renderer.output.write("Error creating forked session: \(error.localizedDescription)\n")
        }
    }

    // MARK: - /sessions command (Story 3.2)

    /// Handle the /sessions command: list saved sessions.
    private func handleSessions() async {
        guard let store = sessionStore else {
            renderer.output.write("No session storage available.\n")
            return
        }

        do {
            let sessions = try await store.list()

            if sessions.isEmpty {
                renderer.output.write("No saved sessions.\n")
                return
            }

            renderer.output.write("Saved sessions (\(sessions.count)):\n")
            for session in sessions {
                let shortId = String(session.id.prefix(8))
                let timeStr = formatRelativeTime(session.updatedAt)
                let preview: String
                if let firstPrompt = session.firstPrompt {
                    preview = String(firstPrompt.prefix(50))
                } else {
                    preview = "(no preview)"
                }
                renderer.output.write("  \(shortId)  \(timeStr)  \(session.messageCount) msgs  \"\(preview)\"\n")
            }
        } catch {
            renderer.output.write("Error listing sessions: \(error.localizedDescription)\n")
        }
    }

    // MARK: - /resume command (Story 3.2)

    /// Handle the /resume <id> command: resume a saved session.
    private func handleResume(parts: [Substring]) async {
        guard let store = sessionStore else {
            renderer.output.write("No session storage available.\n")
            return
        }

        // Check for missing ID argument
        guard parts.count > 1, !parts[1].isEmpty else {
            renderer.output.write("Usage: /resume <session-id>\n")
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
                    renderer.output.write("Session not found: \(inputId)\n")
                    return
                } else if matches.count > 1 {
                    renderer.output.write("Ambiguous ID '\(inputId)' matches \(matches.count) sessions. Use a longer prefix.\n")
                    return
                }
                sessionId = matches[0].id
            }
        } catch {
            renderer.output.write("Error loading session: \(error.localizedDescription)\n")
            return
        }

        // Create a new Agent with the target sessionId using the stored ParsedArgs
        guard let args = parsedArgs else {
            renderer.output.write("Cannot resume session: configuration not available.\n")
            return
        }

        // Override the sessionId to the target session
        let resumeArgs = ParsedArgs(
            helpRequested: args.helpRequested,
            versionRequested: args.versionRequested,
            prompt: args.prompt,
            model: args.model,
            apiKey: args.apiKey,
            baseURL: args.baseURL,
            provider: args.provider,
            mode: args.mode,
            tools: args.tools,
            mcpConfigPath: args.mcpConfigPath,
            hooksConfigPath: args.hooksConfigPath,
            skillDir: args.skillDir,
            skillName: args.skillName,
            sessionId: sessionId,
            noRestore: args.noRestore,
            maxTurns: args.maxTurns,
            maxBudgetUsd: args.maxBudgetUsd,
            systemPrompt: args.systemPrompt,
            thinking: args.thinking,
            quiet: args.quiet,
            output: args.output,
            logLevel: args.logLevel,
            debug: args.debug,
            toolAllow: args.toolAllow,
            toolDeny: args.toolDeny,
            shouldExit: args.shouldExit,
            exitCode: args.exitCode,
            errorMessage: args.errorMessage,
            helpMessage: args.helpMessage
        )

        do {
            let (newAgent, _) = try await AgentFactory.createAgent(from: resumeArgs)
            do {
                try await agentHolder.agent.close()
            } catch {
                renderer.output.write("Warning: failed to save current session (\(error.localizedDescription)). Session history may not be preserved.\n")
            }
            agentHolder.agent = newAgent

            let shortId = String(sessionId.prefix(8))
            renderer.output.write("Resumed session \(shortId)... (session history loaded)\n")
        } catch {
            renderer.output.write("Error creating resumed session: \(error.localizedDescription)\n")
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
