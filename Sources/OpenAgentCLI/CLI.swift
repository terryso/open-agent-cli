import Foundation

/// Top-level CLI orchestrator.
///
/// Dispatches to the appropriate mode (REPL, single-shot, help, version)
/// based on parsed arguments. Contains no business logic -- only routing.
enum CLI {

    /// Run the CLI with the default `CommandLine.arguments`.
    static func run() async {
        let args = ArgumentParser.parse()

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

        // Check for missing API key (only needed for agent operations, not help/version)
        if args.apiKey == nil && args.prompt != nil {
            let msg = "Error: No API key provided. Set --api-key flag or CODEANY_API_KEY environment variable."
            FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
            Foundation.exit(1)
        }

        // Dispatch based on mode
        if let prompt = args.prompt {
            // Single-shot mode
            print("Agent creation not yet implemented. Prompt: \(prompt)")
        } else {
            // REPL mode
            print("REPL mode not yet implemented.")
        }
    }
}
