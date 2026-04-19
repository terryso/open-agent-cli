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

        // Dispatch based on mode
        let agent = createAgentOrExit(from: args)

        if let prompt = args.prompt {
            // Single-shot mode — streaming output is Story 1.3's scope.
            print("Agent created. Prompt: \(prompt)")
            _ = agent
        } else {
            // REPL mode — REPL loop is Story 1.4's scope.
            print("Agent created. REPL mode ready.")
            _ = agent
        }
    }

    /// Create an Agent from parsed args, or print error to stderr and exit.
    private static func createAgentOrExit(from args: ParsedArgs) -> Agent {
        do {
            return try AgentFactory.createAgent(from: args)
        } catch {
            let msg = "Error: \(error.localizedDescription)"
            FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
            Foundation.exit(1)
        }
    }
}
