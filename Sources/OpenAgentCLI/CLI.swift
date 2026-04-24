import Foundation
import OpenAgentSDK
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Top-level CLI orchestrator.
///
/// Dispatches to the appropriate mode (REPL, single-shot, help, version)
/// based on parsed arguments. Contains no business logic -- only routing.
enum CLI {

    /// Run the CLI with the default `CommandLine.arguments`.
    static func run() async {
        var args = ArgumentParser.parse()

        // Handle exit-signaling conditions
        if args.helpRequested {
            if let help = args.helpMessage {
                print(help)
            }
            Foundation.exit(args.exitCode)
        }

        if args.versionRequested {
            print("openagent \(CLIVersion.current)")
            Foundation.exit(args.exitCode)
        }

        if args.shouldExit {
            // Error case: print error to stderr
            if let error = args.errorMessage {
                ANSI.writeToStderr(error + "\n")
            }
            Foundation.exit(args.exitCode)
        }

        // Load config file and fill in nil fields (priority: CLI args > env vars > config file)
        let config = ConfigLoader.load()
        ConfigLoader.apply(config, to: &args)

        // Handle --stdin: read prompt from standard input (Story 7.1).
        // Only reads stdin when --stdin flag is set and no positional prompt was provided
        // (positional args take priority per AC#2).
        if args.stdin {
            if args.prompt == nil {
                do {
                    guard let stdinContent = try readStdin() else {
                        ANSI.writeToStderr(
                            "Error: --stdin specified but no input received on standard input.\n"
                        )
                        Foundation.exit(1)
                    }
                    args.prompt = stdinContent
                } catch {
                    ANSI.writeToStderr(error.localizedDescription)
                    Foundation.exit(1)
                }
            }
            // If positional prompt exists, it takes priority -- stdin is ignored (AC#2)
        }

        // Register signal handlers for graceful interrupt handling (Story 5.3).
        // Must be called before any interactive mode starts.
        SignalHandler.register()

        // Build SkillRegistry — always scans default skill directories
        let skillRegistry = AgentFactory.createSkillRegistry(from: args)

        // Dispatch based on mode
        let (agent, sessionStore, resolvedSessionId) = await createAgentOrExit(from: args)

        if !args.quiet && args.output != "json" {
            if args.mcpConfigPath != nil {
                let renderer = OutputRenderer()
                renderer.output.write("[MCP servers configured]\n")
            }

            if args.hooksConfigPath != nil {
                let renderer = OutputRenderer()
                renderer.output.write("[Hooks configured]\n")
            }
        }

        // Handle --skill auto-invocation
        if let skillName = args.skillName {
            guard let skill = skillRegistry.find(skillName) else {
                let available = skillRegistry.allSkills.map { $0.name }.sorted().joined(separator: ", ")
                if available.isEmpty {
                    ANSI.writeToStderr("Skill not found: \(skillName)\nNo skills discovered. Checked standard directories (~/.openagent/skills, ~/.claude/skills, etc.).\n")
                } else {
                    ANSI.writeToStderr("Skill not found: \(skillName)\nAvailable skills: \(available)\n")
                }
                Foundation.exit(1)
            }

            // Invoke the skill's promptTemplate as a streaming query
            let stream = agent.stream(skill.promptTemplate)
            if args.output == "json" {
                // JSON mode: silently consume stream, then output JSON from result
                let jsonRenderer = JsonOutputRenderer()
                await jsonRenderer.renderStream(stream)
                // Note: For streaming skill invocation, JSON mode silences output.
                // The final result JSON would need a collectAndRender approach
                // for complete integration (deferred to future enhancement).
            } else {
                let renderer = OutputRenderer(quiet: args.quiet)
                await renderer.renderStream(stream)
            }

            // If no positional prompt, enter REPL; otherwise let single-shot handle it
            if args.prompt == nil {
                let reader = LinenoiseInputReader()
                let skillNames = skillRegistry.allSkills.map { $0.name }
                let completionProvider = TabCompletionProvider(skillNames: skillNames)
                reader.setCompletionCallback { input in
                    completionProvider.completions(for: input)
                }
                let renderer = OutputRenderer(quiet: args.quiet)
                let toolNames = AgentFactory.computeToolPool(from: args, skillRegistry: skillRegistry).map { $0.name }
                let repl = REPLLoop(agent: agent, renderer: renderer, reader: reader, toolNames: toolNames, skillRegistry: skillRegistry, sessionStore: sessionStore, parsedArgs: args)
                await repl.start()
                await closeAgentSafely(agent)
                return
            }
        }

        if let prompt = args.prompt {
            // Single-shot mode: use agent.prompt() for blocking query, then exit.
            let result = await agent.prompt(prompt)

            if args.output == "json" {
                // JSON mode: output structured JSON to stdout (Story 7.2).
                // JSON is the sole content of stdout -- no ANSI codes, no extra text.
                // Errors are also output as JSON to stdout (AC#2).
                let jsonRenderer = JsonOutputRenderer()
                jsonRenderer.renderSingleShotJson(result, sessionId: resolvedSessionId)

                let exitCode = CLIExitCode.forQueryStatus(result.status)
                await closeAgentSafely(agent)
                Foundation.exit(exitCode)
            }

            let renderer = OutputRenderer(quiet: args.quiet)

            // Output response text to stdout
            if !result.text.isEmpty {
                print(result.text)
            }

            // Render summary line (turns, cost, duration) -- suppressed in quiet mode
            let isDebug = args.debug || args.logLevel == "debug"
            if !args.quiet {
                renderer.renderSingleShotSummary(result, debug: isDebug)
            }

            // Determine exit code based on query status
            let exitCode = CLIExitCode.forQueryStatus(result.status)

            // For non-success statuses, write error to stderr
            let errorMessage = CLISingleShot.formatErrorMessage(result, debug: isDebug)
            if !errorMessage.isEmpty {
                ANSI.writeToStderr(errorMessage + "\n")
            }

            await closeAgentSafely(agent)
            Foundation.exit(exitCode)
        } else if args.skillName == nil {
            // REPL mode: start interactive loop (only if --skill was not already handled).
            let reader = LinenoiseInputReader()
            let skillNames = skillRegistry.allSkills.map { $0.name }
            let completionProvider = TabCompletionProvider(skillNames: skillNames)
            reader.setCompletionCallback { input in
                completionProvider.completions(for: input)
            }
            let renderer = OutputRenderer(quiet: args.quiet)

            // Show restore hint when auto-restore is active
            if !args.noRestore && args.sessionId == nil {
                renderer.output.write("\r[Restoring last session...]\r\n")
            }

            // Extract tool names for /tools command display and welcome screen
            let toolNames = AgentFactory.computeToolPool(from: args, skillRegistry: skillRegistry).map { $0.name }

            // Welcome screen (Story 9.1): show config summary before first prompt
            if !args.quiet && args.output != "json" {
                let welcomeLine = "openagent \(CLIVersion.current) | model: \(args.model) | tools: \(toolNames.count) | mode: \(args.mode)\r\n"
                renderer.output.write(ANSI.dim(welcomeLine))
            }

            let repl = REPLLoop(agent: agent, renderer: renderer, reader: reader, toolNames: toolNames, skillRegistry: skillRegistry, sessionStore: sessionStore, parsedArgs: args)
            await repl.start()
            await closeAgentSafely(agent)
        }
    }

    /// Read all available data from stdin and return as a trimmed string.
    ///
    /// Returns `nil` if stdin is empty (no data available or only whitespace).
    /// Throws a descriptive string if stdin data is not valid UTF-8.
    /// This method should only be called when `--stdin` flag is set to avoid
    /// blocking on terminal input.
    static func readStdin() throws -> String? {
        // Guard against reading from a terminal (tty), which would block forever.
        if isatty(STDIN_FILENO) != 0 {
            throw StdinError.terminalInput
        }
        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard let rawText = String(data: data, encoding: .utf8) else {
            throw StdinError.invalidEncoding
        }
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// Errors that can occur during stdin reading.
    enum StdinError: Error, LocalizedError {
        case invalidEncoding
        case terminalInput

        var errorDescription: String? {
            switch self {
            case .invalidEncoding:
                return "Error: --stdin received data that is not valid UTF-8.\n"
            case .terminalInput:
                return "Error: --stdin requires piped input. Use 'echo \"text\" | openagent --stdin'.\n"
            }
        }
    }

    /// Create an Agent from parsed args, or print error to stderr and exit.
    private static func createAgentOrExit(from args: ParsedArgs) async -> (Agent, SessionStore, String?) {
        do {
            return try await AgentFactory.createAgent(from: args)
        } catch {
            let msg = "Error: \(error.localizedDescription)"
            ANSI.writeToStderr(msg + "\n")
            Foundation.exit(1)
        }
    }

    /// Close the agent, handling session save failures gracefully.
    ///
    /// If `agent.close()` throws (e.g. disk full), a warning is printed to stderr
    /// but the CLI still exits normally. The exit code is always 0 regardless of
    /// save failures -- the session data is non-critical.
    private static func closeAgentSafely(_ agent: Agent) async {
        do {
            try await agent.close()
        } catch {
            let warning = "Warning: Failed to save session: \(error.localizedDescription)"
            ANSI.writeToStderr(warning + "\n")
        }
    }
}
