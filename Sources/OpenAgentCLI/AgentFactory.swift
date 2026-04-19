import Foundation
import OpenAgentSDK

// MARK: - AgentFactoryError

/// Errors that can occur when creating an Agent from parsed CLI arguments.
enum AgentFactoryError: LocalizedError {
    case missingApiKey
    case invalidProvider(String)
    case invalidMode(String)

    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "No API key provided. Set --api-key flag or OPENAGENT_API_KEY environment variable."
        case .invalidProvider(let value):
            return "Invalid provider '\(value)'. Valid providers: anthropic, openai."
        case .invalidMode(let value):
            return "Invalid mode '\(value)'. Valid modes: \(PermissionMode.allCases.map(\.rawValue).joined(separator: ", "))."
        }
    }
}

// MARK: - AgentFactory

/// Factory that converts parsed CLI arguments into an SDK Agent.
///
/// This is the single bridge between `ParsedArgs` (raw CLI values) and
/// `Agent` (SDK instance). All conversion and validation logic lives here.
enum AgentFactory {

    // MARK: - Public API

    /// Create an SDK Agent from parsed CLI arguments.
    ///
    /// - Parameter args: The fully resolved CLI arguments (after ConfigLoader has applied config file values).
    /// - Returns: A configured Agent instance.
    /// - Throws: `AgentFactoryError` if required configuration is missing or invalid.
    static func createAgent(from args: ParsedArgs) throws -> Agent {
        // 1. Validate API Key
        guard let apiKey = args.apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentFactoryError.missingApiKey
        }

        // 2. Convert provider
        let provider: LLMProvider = try mapProvider(args.provider)

        // 3. Convert permissionMode
        guard let permMode = PermissionMode(rawValue: args.mode) else {
            throw AgentFactoryError.invalidMode(args.mode)
        }

        // 4. Convert thinking
        let thinking: ThinkingConfig? = args.thinking.map {
            .enabled(budgetTokens: $0)
        }

        // 5. Convert logLevel
        let logLevel: LogLevel = mapLogLevel(args.logLevel)

        // 6. Assemble AgentOptions
        let options = AgentOptions(
            apiKey: apiKey,
            model: args.model,
            baseURL: args.baseURL,
            provider: provider,
            systemPrompt: args.systemPrompt,
            maxTurns: args.maxTurns,
            maxBudgetUsd: args.maxBudgetUsd,
            thinking: thinking,
            permissionMode: permMode,
            cwd: FileManager.default.currentDirectoryPath,
            logLevel: logLevel,
            allowedTools: args.toolAllow,
            disallowedTools: args.toolDeny
        )

        // 7. Call SDK factory function
        return OpenAgentSDK.createAgent(options: options)
    }

    // MARK: - Conversion Helpers (exposed for testing)

    /// Map a log level string to the SDK's `LogLevel` enum.
    ///
    /// - Parameter value: The log level string from CLI args, or nil.
    /// - Returns: The corresponding `LogLevel`.
    static func mapLogLevel(_ value: String?) -> LogLevel {
        switch value {
        case "debug": return .debug
        case "info": return .info
        case "warn": return .warn
        case "error": return .error
        default: return .none
        }
    }

    /// Map a provider string to the SDK's `LLMProvider` enum.
    ///
    /// - Parameter value: The provider string from CLI args, or nil.
    /// - Returns: The corresponding `LLMProvider`.
    /// - Throws: `AgentFactoryError.invalidProvider` if the string is non-nil but invalid.
    static func mapProvider(_ value: String?) throws -> LLMProvider {
        guard let value else {
            return .anthropic  // CLI default
        }
        guard let provider = LLMProvider(rawValue: value) else {
            throw AgentFactoryError.invalidProvider(value)
        }
        return provider
    }
}
