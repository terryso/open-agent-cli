import Foundation

/// Configuration loaded from ~/.openagent/config.json.
///
/// All fields are optional — only the fields present in the JSON are used
/// as defaults. Priority: CLI args > env vars > config file > code defaults.
struct CLIConfig: Decodable {
    var apiKey: String? = nil
    var baseURL: String? = nil
    var model: String? = nil
    var provider: String? = nil
    var mode: String? = nil
    var tools: String? = nil
    var maxTurns: Int? = nil
    var maxBudgetUsd: Double? = nil
    var systemPrompt: String? = nil
    var thinking: Int? = nil
    var logLevel: String? = nil
    var mcpConfigPath: String? = nil
    var hooksConfigPath: String? = nil
    var skillDir: String? = nil
    var toolAllow: [String]? = nil
    var toolDeny: [String]? = nil
    var output: String? = nil
}

/// Loads CLI configuration from ~/.openagent/config.json.
///
/// If the file does not exist, returns nil silently (no error).
/// If the file exists but is invalid JSON, prints a warning to stderr and returns nil.
enum ConfigLoader {

    /// Default config file path: ~/.openagent/config.json
    static var configFilePath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.openagent/config.json"
    }

    /// Load configuration from the default path.
    static func load() -> CLIConfig? {
        load(from: configFilePath)
    }

    /// Load configuration from a specific path (testable).
    static func load(from path: String) -> CLIConfig? {
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }

        guard let data = FileManager.default.contents(atPath: path) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(CLIConfig.self, from: data)
        } catch {
            let msg = "Warning: Failed to parse \(path): \(error.localizedDescription)\n"
            FileHandle.standardError.write(msg.data(using: .utf8)!)
            return nil
        }
    }

    /// Apply config values to ParsedArgs, filling in nil/default fields only.
    /// CLI args and env vars take precedence — config file is the lowest priority.
    /// Uses `explicitlySet` to distinguish "user didn't pass this flag" from
    /// "user passed this flag with a value that happens to equal the default."
    static func apply(_ config: CLIConfig?, to args: inout ParsedArgs) {
        guard let config = config else { return }

        // Optional fields: fill from config only when args value is nil
        if !args.explicitlySet.contains("apiKey"), let key = config.apiKey {
            args.apiKey = key
        }
        if !args.explicitlySet.contains("baseURL"), let url = config.baseURL {
            args.baseURL = url
        }
        if !args.explicitlySet.contains("provider"), let provider = config.provider {
            args.provider = provider
        }
        if !args.explicitlySet.contains("mode"), let mode = config.mode {
            args.mode = mode
        }
        if !args.explicitlySet.contains("tools"), let tools = config.tools {
            args.tools = tools
        }
        if !args.explicitlySet.contains("maxTurns"), let turns = config.maxTurns {
            args.maxTurns = turns
        }
        if !args.explicitlySet.contains("maxBudgetUsd"), let budget = config.maxBudgetUsd {
            args.maxBudgetUsd = budget
        }
        if !args.explicitlySet.contains("systemPrompt"), let prompt = config.systemPrompt {
            args.systemPrompt = prompt
        }
        if !args.explicitlySet.contains("thinking"), let thinking = config.thinking {
            args.thinking = thinking
        }
        if !args.explicitlySet.contains("logLevel"), let level = config.logLevel {
            args.logLevel = level
        }
        if !args.explicitlySet.contains("model"), let model = config.model {
            args.model = model
        }

        // New fields (Story 7.3): path configs, tool lists, output format
        if !args.explicitlySet.contains("mcpConfigPath"), let mcp = config.mcpConfigPath {
            args.mcpConfigPath = mcp
        }
        if !args.explicitlySet.contains("hooksConfigPath"), let hooks = config.hooksConfigPath {
            args.hooksConfigPath = hooks
        }
        if !args.explicitlySet.contains("skillDir"), let skillDir = config.skillDir {
            args.skillDir = skillDir
        }
        if !args.explicitlySet.contains("toolAllow"), let toolAllow = config.toolAllow {
            args.toolAllow = toolAllow
        }
        if !args.explicitlySet.contains("toolDeny"), let toolDeny = config.toolDeny {
            args.toolDeny = toolDeny
        }
        if !args.explicitlySet.contains("output"), let output = config.output {
            args.output = output
        }

        // Path validation: warn if config-referenced paths don't exist (AC#6)
        warnIfMissing(path: args.mcpConfigPath, label: "mcpConfigPath")
        warnIfMissing(path: args.hooksConfigPath, label: "hooksConfigPath")
        if let skillDir = args.skillDir, !FileManager.default.fileExists(atPath: skillDir) {
            let msg = "Warning: Configured skillDir does not exist: \(skillDir)\n"
            FileHandle.standardError.write(msg.data(using: .utf8)!)
        }
    }

    /// Print a warning to stderr if the given path does not exist.
    private static func warnIfMissing(path: String?, label: String) {
        guard let path = path else { return }
        if !FileManager.default.fileExists(atPath: path) {
            let msg = "Warning: Configured \(label) does not exist: \(path)\n"
            FileHandle.standardError.write(msg.data(using: .utf8)!)
        }
    }

    /// Ensure the configuration directory exists.
    /// Creates the directory (and parents) if needed. Non-blocking on failure.
    /// - Parameter at: The directory path to create. Defaults to `~/.openagent/`.
    static func ensureConfigDirectory(at path: String? = nil) {
        let dir = path ?? {
            let full = configFilePath
            return full.components(separatedBy: "/").dropLast().joined(separator: "/")
        }()
        do {
            try FileManager.default.createDirectory(
                atPath: dir,
                withIntermediateDirectories: true
            )
        } catch {
            let msg = "Warning: Could not create config directory \(dir): \(error.localizedDescription)\n"
            FileHandle.standardError.write(msg.data(using: .utf8)!)
        }
    }
}
