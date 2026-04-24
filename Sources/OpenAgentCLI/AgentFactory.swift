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
    static func createSkillRegistry(from args: ParsedArgs) -> SkillRegistry {
        let registry = SkillRegistry()

        if let explicitDir = args.skillDir {
            // Explicit --skill-dir: only scan that directory
            registry.registerDiscoveredSkills(from: [explicitDir], skillNames: nil)
        } else {
            // Auto-discover from all standard directories (SDK defaults + openagent-specific)
            registry.registerDiscoveredSkills(from: defaultSkillDirectories(), skillNames: nil)
        }

        return registry
    }

    /// Scans: SDK defaults (~/.config/agents/skills, ~/.agents/skills, ~/.claude/skills,
    /// $PWD/.agents/skills, $PWD/.claude/skills) plus ~/.openagent/skills and $PWD/.openagent/skills.
    /// Same-name skills across directories are deduplicated by the SDK (last-wins).
    private static func defaultSkillDirectories() -> [String] {
        var dirs = SkillLoader.defaultSkillDirectories()

        if let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory() as String? {
            dirs.append(home + "/.openagent/skills")
        }

        let cwd = FileManager.default.currentDirectoryPath
        dirs.append(cwd + "/.openagent/skills")

        return dirs
    }

    /// Create an SDK Agent from parsed CLI arguments.
    ///
    /// - Parameter args: The fully resolved CLI arguments (after ConfigLoader has applied config file values).
    /// - Returns: A tuple of (configured Agent instance, SessionStore used for session management, resolved session ID).
    /// - Throws: `AgentFactoryError` if required configuration is missing or invalid.
    /// - Throws: ``HookConfigLoaderError`` if hooks config file cannot be loaded or parsed.
    static func createAgent(from args: ParsedArgs) async throws -> (Agent, SessionStore, String?) {
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

        // 6c. Load hooks configuration (if --hooks provided)
        var hookRegistry: HookRegistry?
        if let hooksPath = args.hooksConfigPath {
            let config = try HookConfigLoader.loadHooksConfig(from: hooksPath)
            hookRegistry = await createHookRegistry(config: config)
        }

        // 7. Resolve session configuration
        let sessionStore = SessionStore()
        let shouldAutoRestore = !args.noRestore && args.sessionId == nil && args.prompt == nil && args.skillName == nil
        let sessionId: String? = shouldAutoRestore ? nil : resolveSessionId(from: args)

        // 8. Create canUseTool callback via PermissionHandler
        let reader = FileHandleInputReader()
        let permRenderer = OutputRenderer()
        let isInteractive = args.prompt == nil && args.skillName == nil
        let canUseTool = PermissionHandler.createCanUseTool(
            mode: permMode,
            reader: reader,
            renderer: permRenderer,
            isInteractive: isInteractive
        )

        // 9. Resolve model (provider-aware default when not explicitly set)
        let model = resolveModel(from: args, provider: provider)

        // 10. Assemble AgentOptions
        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: args.baseURL,
            provider: provider,
            systemPrompt: args.systemPrompt,
            maxTurns: args.maxTurns,
            maxBudgetUsd: args.maxBudgetUsd,
            thinking: thinking,
            permissionMode: permMode,
            canUseTool: canUseTool,
            cwd: FileManager.default.currentDirectoryPath,
            tools: toolPool,
            mcpServers: mcpServers,
            sessionStore: sessionStore,
            sessionId: sessionId,
            hookRegistry: hookRegistry,
            logLevel: logLevel,
            allowedTools: args.toolAllow,
            disallowedTools: args.toolDeny,
            continueRecentSession: shouldAutoRestore,
            persistSession: true
        )

        // 11. Call SDK factory function
        let agent = OpenAgentSDK.createAgent(options: options)
        return (agent, sessionStore, sessionId)
    }

    // MARK: - Conversion Helpers (exposed for testing)

    /// Compute the assembled tool pool from parsed CLI arguments.
    ///
    /// Single source of truth for tool loading — used by both `createAgent`
    /// and `CLI` (for `/tools` display).
    static func computeToolPool(from args: ParsedArgs, skillRegistry: SkillRegistry = SkillRegistry()) -> [ToolProtocol] {
        let baseTools = mapToolTier(args.tools)

        // Build custom tools array: include Agent tool, Skill tool, and user-defined custom tools
        var customTools: [ToolProtocol]? = nil

        // Include Agent tool (createAgentTool) when tool tier includes advanced tools
        let includeAgentTool = args.tools == "advanced" || args.tools == "all" || args.tools == "specialist"
        if includeAgentTool {
            customTools = (customTools ?? []) + [createAgentTool()]
        }

        // Include SkillTool when skill-related args are present
        if !skillRegistry.allSkills.isEmpty {
            customTools = (customTools ?? []) + [createSkillTool(registry: skillRegistry)]
        }

        // Include user-defined custom tools from config file (Story 7.7)
        let userCustomTools = createCustomTools(from: args.customTools)
        if !userCustomTools.isEmpty {
            customTools = (customTools ?? []) + userCustomTools
        }

        return assembleToolPool(
            baseTools: baseTools,
            customTools: customTools,
            mcpTools: nil,
            allowed: args.toolAllow,
            disallowed: args.toolDeny
        )
    }

    /// Create SDK ToolProtocol instances from CustomToolConfig array.
    ///
    /// Each valid config entry becomes a tool that executes an external script via `Process`.
    /// Invalid configs (empty schema, missing execute path) are skipped with warnings.
    /// - Parameter configs: Array of CustomToolConfig from the config file.
    /// - Returns: Array of valid ToolProtocol instances.
    static func createCustomTools(from configs: [CustomToolConfig]?) -> [ToolProtocol] {
        guard let configs, !configs.isEmpty else { return [] }

        var tools: [ToolProtocol] = []
        for config in configs {
            // AC#4: Skip tools with empty inputSchema
            if config.inputSchema.isEmpty {
                FileHandle.standardError.write("Warning: Custom tool '\(config.name)' has empty inputSchema, skipping.\n".data(using: .utf8) ?? Data())
                continue
            }

            // AC#5: Skip tools with nonexistent or non-executable execute path
            let fm = FileManager.default
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: config.execute, isDirectory: &isDir), isDir.boolValue {
                FileHandle.standardError.write("Warning: Custom tool '\(config.name)' execute path is a directory, skipping: \(config.execute)\n".data(using: .utf8) ?? Data())
                continue
            }
            if !fm.isExecutableFile(atPath: config.execute) {
                FileHandle.standardError.write("Warning: Custom tool '\(config.name)' execute path not found or not executable: \(config.execute)\n".data(using: .utf8) ?? Data())
                continue
            }

            let executePath = config.execute
            let toolIsReadOnly = config.isReadOnly ?? false

            let tool = defineTool(
                name: config.name,
                description: config.description,
                inputSchema: config.inputSchema,
                isReadOnly: toolIsReadOnly
            ) { (input: [String: Any], context: ToolContext) async -> ToolExecuteResult in
                do {
                    let result = try await AgentFactory.executeExternalTool(
                        path: executePath,
                        input: input
                    )
                    return ToolExecuteResult(content: result, isError: false)
                } catch {
                    return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
                }
            }
            tools.append(tool)
        }
        return tools
    }

    /// Execute an external tool script by spawning a Process.
    ///
    /// The script receives JSON input via stdin and returns output via stdout.
    /// A non-zero exit code is treated as an error.
    /// - Parameters:
    ///   - path: Absolute path to the executable script.
    ///   - input: Input dictionary serialized to JSON and sent via stdin.
    /// - Returns: The stdout output as a String.
    /// - Throws: An error if the process fails to launch or exits with non-zero code.
    private static func executeExternalTool(path: String, input: [String: Any]) async throws -> String {
        // Serialize input on calling thread to avoid Sendable issues in the closure
        let inputData = try JSONSerialization.data(withJSONObject: input, options: [])

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: path)

                    let stdinPipe = Pipe()
                    let stdoutPipe = Pipe()
                    let stderrPipe = Pipe()
                    process.standardInput = stdinPipe
                    process.standardOutput = stdoutPipe
                    process.standardError = stderrPipe

                    try process.run()

                    // Write pre-serialized JSON input to stdin
                    stdinPipe.fileHandleForWriting.write(inputData)
                    try? stdinPipe.fileHandleForWriting.close()

                    // 30-second timeout protection to prevent thread pool starvation
                    let timeoutSeconds: TimeInterval = 30
                    let timer = DispatchSource.makeTimerSource()
                    timer.schedule(deadline: .now() + timeoutSeconds)
                    timer.setEventHandler {
                        if process.isRunning {
                            process.terminate()
                        }
                    }
                    timer.resume()

                    process.waitUntilExit()
                    timer.cancel()

                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    if process.terminationStatus != 0 {
                        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let stderrOutput = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let timedOut = process.terminationStatus == 15 // SIGTERM from our timer
                        let errorMsg: String
                        if timedOut {
                            errorMsg = "Custom tool timed out after \(Int(timeoutSeconds))s"
                        } else if stderrOutput.isEmpty {
                            errorMsg = "Process exited with code \(process.terminationStatus)"
                        } else {
                            errorMsg = stderrOutput
                        }
                        continuation.resume(throwing: NSError(
                            domain: "CustomTool",
                            code: Int(process.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: errorMsg]
                        ))
                    } else {
                        continuation.resume(returning: output)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
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

    /// Resolve the model string, applying provider-aware defaults.
    ///
    /// Priority: `--model` flag > config file value > provider-aware default.
    /// Config file values are applied by ConfigLoader before this is called,
    /// so `args.model` already reflects the config when present.
    static func resolveModel(from args: ParsedArgs, provider: LLMProvider) -> String {
        if args.explicitlySet.contains("model") {
            return args.model
        }
        // ConfigLoader may have set args.model from config.json — use it.
        // Only fall back to provider defaults when no model is configured.
        return args.model
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
