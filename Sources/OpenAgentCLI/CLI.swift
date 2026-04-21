import Foundation
import OpenAgentSDK

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
                FileHandle.standardError.write((error + "\n").data(using: .utf8)!)
            }
            Foundation.exit(args.exitCode)
        }

        // Load config file and fill in nil fields (priority: CLI args > env vars > config file)
        let config = ConfigLoader.load()
        ConfigLoader.apply(config, to: &args)

        // Register signal handlers for graceful interrupt handling (Story 5.3).
        // Must be called before any interactive mode starts.
        SignalHandler.register()

        // Build SkillRegistry if skill-related args are present (computed once, reused throughout)
        let skillRegistry = AgentFactory.createSkillRegistry(from: args)

        // Dispatch based on mode
        let (agent, sessionStore) = await createAgentOrExit(from: args)

        if !args.quiet {
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
            guard let registry = skillRegistry else {
                FileHandle.standardError.write(("Skill not found: \(skillName)\n").data(using: .utf8)!)
                Foundation.exit(1)
            }

            guard let skill = registry.find(skillName) else {
                let available = registry.allSkills.map { $0.name }.sorted().joined(separator: ", ")
                FileHandle.standardError.write(("Skill not found: \(skillName)\nAvailable skills: \(available)\n").data(using: .utf8)!)
                Foundation.exit(1)
            }

            // Invoke the skill's promptTemplate as a streaming query
            do {
                let stream = agent.stream(skill.promptTemplate)
                let renderer = OutputRenderer(quiet: args.quiet)
                await renderer.renderStream(stream)
            } catch {
                FileHandle.standardError.write(("Error invoking skill '\(skillName)': \(error.localizedDescription)\n").data(using: .utf8)!)
            }

            // If no positional prompt, enter REPL; otherwise let single-shot handle it
            if args.prompt == nil {
                let reader = FileHandleInputReader()
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
                FileHandle.standardError.write((errorMessage + "\n").data(using: .utf8)!)
            }

            await closeAgentSafely(agent)
            Foundation.exit(exitCode)
        } else if args.skillName == nil {
            // REPL mode: start interactive loop (only if --skill was not already handled).
            let reader = FileHandleInputReader()
            let renderer = OutputRenderer(quiet: args.quiet)

            // Show restore hint when auto-restore is active
            if !args.noRestore && args.sessionId == nil {
                renderer.output.write("[Restoring last session...]\n")
            }

            // Extract tool names for /tools command display
            let toolNames = AgentFactory.computeToolPool(from: args, skillRegistry: skillRegistry).map { $0.name }

            let repl = REPLLoop(agent: agent, renderer: renderer, reader: reader, toolNames: toolNames, skillRegistry: skillRegistry, sessionStore: sessionStore, parsedArgs: args)
            await repl.start()
            await closeAgentSafely(agent)
        }
    }

    /// Create an Agent from parsed args, or print error to stderr and exit.
    private static func createAgentOrExit(from args: ParsedArgs) async -> (Agent, SessionStore) {
        do {
            return try await AgentFactory.createAgent(from: args)
        } catch {
            let msg = "Error: \(error.localizedDescription)"
            FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
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
            FileHandle.standardError.write((warning + "\n").data(using: .utf8)!)
        }
    }
}
