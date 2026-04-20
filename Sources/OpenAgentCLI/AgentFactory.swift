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

    /// Create a SkillRegistry from parsed CLI arguments if skill-related args are present.
    ///
    /// Returns nil when neither `--skill-dir` nor `--skill` is specified.
    /// When `--skill-dir` is provided, discovers all skills from that directory.
    /// When only `--skill` is provided, discovers from SDK default directories.
    /// Note: All skills from the directory are registered (not filtered by skillName)
    /// so that the CLI can list available skills in error messages for invalid names.
    ///
    /// - Parameter args: The fully resolved CLI arguments.
    /// - Returns: A populated SkillRegistry, or nil if no skill args present.
    static func createSkillRegistry(from args: ParsedArgs) -> SkillRegistry? {
        guard args.skillDir != nil || args.skillName != nil else { return nil }

        let registry = SkillRegistry()
        let dirs: [String]? = args.skillDir.map { [$0] }
        // Discover all skills from the directory (don't filter by skillName)
        // so that error messages can list available skills
        registry.registerDiscoveredSkills(from: dirs, skillNames: nil)
        return registry
    }

    /// Create an SDK Agent from parsed CLI arguments.
    ///
    /// - Parameter args: The fully resolved CLI arguments (after ConfigLoader has applied config file values).
    /// - Returns: A tuple of (configured Agent instance, SessionStore used for session management).
    /// - Throws: `AgentFactoryError` if required configuration is missing or invalid.
    static func createAgent(from args: ParsedArgs) throws -> (Agent, SessionStore) {
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

        // 6. Load and assemble tools
        let registry = createSkillRegistry(from: args)
        let toolPool = computeToolPool(from: args, skillRegistry: registry)

        // 6b. Load MCP server configuration (if --mcp provided)
        let mcpServers: [String: McpServerConfig]? = try args.mcpConfigPath.map {
            try MCPConfigLoader.loadMcpConfig(from: $0)
        }

        // 7. Resolve session configuration
        let sessionStore = SessionStore()
        let shouldAutoRestore = !args.noRestore && args.sessionId == nil && args.prompt == nil && args.skillName == nil
        let sessionId: String? = shouldAutoRestore ? nil : resolveSessionId(from: args)

        // 8. Assemble AgentOptions
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
            tools: toolPool,
            mcpServers: mcpServers,
            sessionStore: sessionStore,
            sessionId: sessionId,
            logLevel: logLevel,
            allowedTools: args.toolAllow,
            disallowedTools: args.toolDeny,
            continueRecentSession: shouldAutoRestore,
            persistSession: true
        )

        // 9. Call SDK factory function
        let agent = OpenAgentSDK.createAgent(options: options)
        return (agent, sessionStore)
    }

    // MARK: - Conversion Helpers (exposed for testing)

    /// Compute the assembled tool pool from parsed CLI arguments.
    ///
    /// Single source of truth for tool loading — used by both `createAgent`
    /// and `CLI` (for `/tools` display).
    static func computeToolPool(from args: ParsedArgs, skillRegistry: SkillRegistry? = nil) -> [ToolProtocol] {
        let baseTools = mapToolTier(args.tools)

        // Include SkillTool when skill-related args are present
        var customTools: [ToolProtocol]? = nil
        if let registry = skillRegistry {
            customTools = [createSkillTool(registry: registry)]
        }

        return assembleToolPool(
            baseTools: baseTools,
            customTools: customTools,
            mcpTools: nil,
            allowed: args.toolAllow,
            disallowed: args.toolDeny
        )
    }

    /// Map a tool tier string to an array of SDK tools.
    ///
    /// - Parameter tier: The tier string from CLI args (e.g. "core", "advanced", "specialist", "all").
    /// - Returns: An array of `ToolProtocol` for the specified tier.
    static func mapToolTier(_ tier: String) -> [ToolProtocol] {
        switch tier {
        case "core":
            return getAllBaseTools(tier: .core)
        case "advanced":
            return getAllBaseTools(tier: .core) + getAllBaseTools(tier: .advanced)
        case "specialist":
            return getAllBaseTools(tier: .specialist)
        case "all":
            return getAllBaseTools(tier: .core) + getAllBaseTools(tier: .specialist)
        default:
            return getAllBaseTools(tier: .core)  // Safe fallback
        }
    }

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

    /// Resolve the session ID from parsed CLI arguments.
    ///
    /// When auto-restore is active (no `--session` and no `--no-restore`),
    /// returns `nil` so the SDK's `continueRecentSession` mechanism can
    /// resolve the most recent session from `SessionStore`.
    /// Otherwise uses the explicitly provided `--session` ID or generates
    /// a new UUID string.
    ///
    /// - Parameter args: The fully resolved CLI arguments.
    /// - Returns: A session ID string, or `nil` when auto-restore is active.
    static func resolveSessionId(from args: ParsedArgs) -> String? {
        return args.sessionId ?? UUID().uuidString
    }
}
