import Foundation

/// Parsed CLI arguments holding all configuration values.
///
/// This struct is produced by ``ArgumentParser/parse(_:)`` and holds raw
/// values ready for conversion to `AgentOptions` (which is Story 1.2's job).
struct ParsedArgs {
    var helpRequested: Bool = false
    var versionRequested: Bool = false
    var prompt: String? = nil
    var model: String = "glm-5.1"
    var apiKey: String? = nil
    var baseURL: String? = nil
    var provider: String? = nil
    var mode: String = "default"
    var tools: String = "core"
    var mcpConfigPath: String? = nil
    var hooksConfigPath: String? = nil
    var skillDir: String? = nil
    var skillName: String? = nil
    var sessionId: String? = nil
    var noRestore: Bool = false
    var maxTurns: Int = 10
    var maxBudgetUsd: Double? = nil
    var systemPrompt: String? = nil
    var thinking: Int? = nil
    var quiet: Bool = false
    var output: String = "text"
    var logLevel: String? = nil
    var debug: Bool = false
    var stdin: Bool = false
    var toolAllow: [String]? = nil
    var toolDeny: [String]? = nil
    /// Custom tools loaded from config file (Story 7.7).
    var customTools: [CustomToolConfig]? = nil
    /// Tracks which value flags were explicitly set by the user on the command line.
    /// Used by ConfigLoader.apply() to avoid overriding explicit CLI args with config values.
    var explicitlySet: Set<String> = []
    var shouldExit: Bool = false
    var exitCode: Int32 = 0
    var errorMessage: String? = nil
    var helpMessage: String? = nil
}

/// Custom argument parser for the OpenAgent CLI.
///
/// Parses command-line flags and positional arguments into a ``ParsedArgs``
/// struct. No third-party CLI libraries are used -- Foundation is sufficient
/// for the ~20 flags supported by the CLI.
enum ArgumentParser {

    // MARK: - Valid Values

    private static let validModes: Set<String> = [
        "default", "acceptEdits", "bypassPermissions", "plan", "dontAsk", "auto"
    ]

    private static let validToolsTiers: Set<String> = [
        "core", "advanced", "specialist", "all"
    ]

    private static let validProviders: Set<String> = [
        "anthropic", "openai"
    ]

    private static let validOutputFormats: Set<String> = [
        "text", "json"
    ]

    private static let validLogLevels: Set<String> = [
        "debug", "info", "warn", "error"
    ]

    // MARK: - Flags That Take a Value

    /// Flags that expect a following value argument.
    private static let valueFlags: Set<String> = [
        "--model", "--mode", "--tools", "--mcp", "--hooks", "--skill-dir",
        "--skill", "--session", "--max-turns", "--max-budget", "--system-prompt",
        "--thinking", "--output", "--log-level", "--api-key", "--base-url",
        "--provider", "--tool-allow", "--tool-deny"
    ]

    // MARK: - Boolean Flags

    /// Flags that do not take a value (presence = true).
    private static let booleanFlags: Set<String> = [
        "--quiet", "--no-restore", "--debug", "-d", "--stdin"
    ]

    // MARK: - Parse

    /// Parse command-line arguments into a ``ParsedArgs`` struct.
    ///
    /// - Parameter args: The argument array. Typically `CommandLine.arguments`
    ///   (where element 0 is the program name). Passing an empty array defaults
    ///   to REPL mode.
    /// - Returns: A ``ParsedArgs`` with all parsed values, validation errors, or
    ///   help/version request signals.
    static func parse(_ args: [String] = CommandLine.arguments) -> ParsedArgs {
        var result = ParsedArgs()

        // Empty array: no program name, no args -> REPL mode
        guard !args.isEmpty else { return result }

        var i = 1 // Skip program name (args[0])
        while i < args.count {
            let arg = args[i]

            if arg == "--help" || arg == "-h" {
                result.helpRequested = true
                result.shouldExit = true
                result.exitCode = 0
                result.helpMessage = generateHelpMessage()
            } else if arg == "--version" || arg == "-v" {
                result.versionRequested = true
                result.shouldExit = true
                result.exitCode = 0
            } else if arg == "--model" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                result.model = value
                result.explicitlySet.insert("model")
                i += 1
            } else if arg == "--mode" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                if !validModes.contains(value) {
                    return makeError(result: &result, message: "Invalid mode '\(value)'. Valid modes: \(validModes.sorted().joined(separator: ", ")). Use --help for available options.")
                }
                result.mode = value
                result.explicitlySet.insert("mode")
                i += 1
            } else if arg == "--tools" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                if !validToolsTiers.contains(value) {
                    return makeError(result: &result, message: "Invalid tools tier '\(value)'. Valid tiers: \(validToolsTiers.sorted().joined(separator: ", ")). Use --help for available options.")
                }
                result.tools = value
                result.explicitlySet.insert("tools")
                i += 1
            } else if arg == "--provider" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                if !validProviders.contains(value) {
                    return makeError(result: &result, message: "Invalid provider '\(value)'. Valid providers: \(validProviders.sorted().joined(separator: ", ")). Use --help for available options.")
                }
                result.provider = value
                result.explicitlySet.insert("provider")
                i += 1
            } else if arg == "--output" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                if !validOutputFormats.contains(value) {
                    return makeError(result: &result, message: "Invalid output format '\(value)'. Valid formats: \(validOutputFormats.sorted().joined(separator: ", ")). Use --help for available options.")
                }
                result.output = value
                result.explicitlySet.insert("output")
                i += 1
            } else if arg == "--log-level" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                if !validLogLevels.contains(value) {
                    return makeError(result: &result, message: "Invalid log level '\(value)'. Valid levels: \(validLogLevels.sorted().joined(separator: ", ")). Use --help for available options.")
                }
                result.logLevel = value
                result.explicitlySet.insert("logLevel")
                i += 1
            } else if arg == "--max-turns" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                guard let intVal = Int(value), intVal > 0 else {
                    return makeError(result: &result, message: "Invalid --max-turns value '\(value)'. Must be a positive integer. Use --help for available options.")
                }
                result.maxTurns = intVal
                result.explicitlySet.insert("maxTurns")
                i += 1
            } else if arg == "--max-budget" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                guard let doubleVal = Double(value), doubleVal > 0 else {
                    return makeError(result: &result, message: "Invalid --max-budget value '\(value)'. Must be a positive number. Use --help for available options.")
                }
                result.maxBudgetUsd = doubleVal
                result.explicitlySet.insert("maxBudgetUsd")
                i += 1
            } else if arg == "--thinking" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                guard let intVal = Int(value), intVal > 0 else {
                    return makeError(result: &result, message: "Invalid --thinking value '\(value)'. Must be a positive integer (token budget). Use --help for available options.")
                }
                result.thinking = intVal
                result.explicitlySet.insert("thinking")
                i += 1
            } else if arg == "--mcp" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                result.mcpConfigPath = value
                result.explicitlySet.insert("mcpConfigPath")
                i += 1
            } else if arg == "--hooks" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                result.hooksConfigPath = value
                result.explicitlySet.insert("hooksConfigPath")
                i += 1
            } else if arg == "--skill-dir" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                result.skillDir = value
                result.explicitlySet.insert("skillDir")
                i += 1
            } else if arg == "--skill" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                result.skillName = value
                result.explicitlySet.insert("skillName")
                i += 1
            } else if arg == "--session" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                result.sessionId = value
                result.explicitlySet.insert("sessionId")
                i += 1
            } else if arg == "--system-prompt" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                result.systemPrompt = value
                result.explicitlySet.insert("systemPrompt")
                i += 1
            } else if arg == "--api-key" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                result.apiKey = value
                result.explicitlySet.insert("apiKey")
                i += 1
            } else if arg == "--base-url" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                result.baseURL = value
                result.explicitlySet.insert("baseURL")
                i += 1
            } else if arg == "--tool-allow" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                result.toolAllow = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                result.explicitlySet.insert("toolAllow")
                i += 1
            } else if arg == "--tool-deny" {
                guard let value = nextValue(after: i, in: args, flag: arg, result: &result) else { return result }
                result.toolDeny = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                result.explicitlySet.insert("toolDeny")
                i += 1
            } else if arg == "--quiet" {
                result.quiet = true
            } else if arg == "--no-restore" {
                result.noRestore = true
            } else if arg == "--debug" || arg == "-d" {
                result.debug = true
                result.logLevel = "debug"
                result.explicitlySet.insert("logLevel")
            } else if arg == "--stdin" {
                result.stdin = true
            } else if arg == "--" {
                // POSIX end-of-flags: remaining args are positional
                i += 1
                while i < args.count {
                    if result.prompt == nil {
                        result.prompt = args[i]
                    }
                    i += 1
                }
                break
            } else if arg.hasPrefix("-") {
                // Unknown flag
                return makeError(result: &result, message: "Unknown flag '\(arg)'. Use --help for available options.")
            } else {
                // Positional argument = prompt (single-shot mode).
                // Only use the first positional arg.
                if result.prompt == nil {
                    result.prompt = arg
                }
            }

            i += 1
        }

        // Resolve API key: --api-key flag > OPENAGENT_API_KEY env var
        // Env var counts as explicitly set to prevent config file override
        if result.apiKey == nil {
            if let envKey = ProcessInfo.processInfo.environment["OPENAGENT_API_KEY"] {
                result.apiKey = envKey
                result.explicitlySet.insert("apiKey")
            }
        }

        // Validate mutual exclusion: --stdin and --skill cannot be used together
        if result.stdin && result.skillName != nil {
            return makeError(result: &result, message: "Cannot use --stdin and --skill together. Both provide prompt content; choose one.")
        }

        return result
    }

    // MARK: - Helpers

    /// Get the next value after a flag, or set an error if missing.
    private static func nextValue(
        after i: Int,
        in args: [String],
        flag: String,
        result: inout ParsedArgs
    ) -> String? {
        let nextIndex = i + 1
        guard nextIndex < args.count else {
            makeError(result: &result, message: "Missing value for \(flag). Use --help for available options.")
            return nil
        }
        return args[nextIndex]
    }

    /// Set error state on the result and return it.
    @discardableResult
    private static func makeError(result: inout ParsedArgs, message: String) -> ParsedArgs {
        result.shouldExit = true
        result.exitCode = 1
        result.errorMessage = message
        return result
    }

    // MARK: - Help Message

    /// Generate the full help message.
    static func generateHelpMessage() -> String {
        """
        openagent [options] [prompt]

        An AI agent CLI powered by OpenAgent SDK.

        Modes:
          REPL mode          Run with no arguments to enter interactive mode.
          Single-shot mode   Provide a prompt string for one-shot execution.

        Startup Options:
          --model <model>          Model to use (default: glm-5.1)
          --mode <mode>            Permission mode: default, acceptEdits, bypassPermissions, plan, dontAsk, auto
          --provider <provider>    LLM provider: anthropic, openai
          --api-key <key>          API key (or set OPENAGENT_API_KEY env var)
          --base-url <url>         API base URL (required for non-Anthropic providers)

        Interaction Options:
          --max-turns <n>          Maximum agent loop turns (default: 10)
          --max-budget <usd>       Maximum spend in USD
          --system-prompt <text>   Override system prompt
          --thinking <budget>      Thinking token budget
          --quiet                  Suppress non-essential output
          --stdin                  Read prompt from standard input (pipe mode)

        Tools Options:
          --tools <tiers>          Tool tiers: core, advanced, specialist, all (default: core)
          --tool-allow <names>     Comma-separated list of allowed tool names
          --tool-deny <names>      Comma-separated list of denied tool names
          --mcp <path>             Path to MCP server configuration file

        Session Options:
          --session <id>           Resume a session by ID
          --no-restore             Do not restore previous session
          --hooks <path>           Path to hooks configuration file
          --skill-dir <path>       Directory to scan for skills
          --skill <name>           Skill name to execute

        Output Options:
          --output <format>        Output format: text, json (default: text)
          -d, --debug              Enable debug output (shorthand for --log-level debug)
          --log-level <level>      Log level: debug, info, warn, error

        General:
          -h, --help               Show this help message
          -v, --version            Show version
        """
    }
}
