import Foundation

/// Configuration for a custom tool registered via config file.
///
/// Custom tools are defined in `~/.openagent/config.json` under the `customTools` array.
/// Each tool has a name, description, JSON Schema for input, and an executable script path.
/// The script receives JSON input via stdin and returns output via stdout.
struct CustomToolConfig {
    let name: String
    let description: String
    let inputSchema: [String: Any]
    let execute: String
    let isReadOnly: Bool?

    /// Programmatic initializer for use in tests and factory methods.
    init(name: String, description: String, inputSchema: [String: Any], execute: String, isReadOnly: Bool?) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.execute = execute
        self.isReadOnly = isReadOnly
    }

    /// Parse a single custom tool from a JSON dictionary.
    /// Returns nil if required fields are missing or inputSchema is not a dictionary.
    static func fromDictionary(_ dict: [String: Any]) -> CustomToolConfig? {
        guard let name = dict["name"] as? String,
              let description = dict["description"] as? String,
              let schema = dict["inputSchema"] as? [String: Any],
              let execute = dict["execute"] as? String else {
            return nil
        }
        let isReadOnly = dict["isReadOnly"] as? Bool
        return CustomToolConfig(
            name: name,
            description: description,
            inputSchema: schema,
            execute: execute,
            isReadOnly: isReadOnly
        )
    }
}

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
    /// Custom tools parsed manually via JSONSerialization (not Decodable).
    var customTools: [CustomToolConfig]? = nil

    // Explicit coding keys (excludes customTools which is handled separately)
    private enum CodingKeys: String, CodingKey {
        case apiKey, baseURL, model, provider, mode, tools
        case maxTurns, maxBudgetUsd, systemPrompt, thinking, logLevel
        case mcpConfigPath, hooksConfigPath, skillDir
        case toolAllow, toolDeny, output
    }

    // Custom Decodable init: decode all standard fields, skip customTools
    // (customTools is populated separately in ConfigLoader.load() via JSONSerialization)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        provider = try container.decodeIfPresent(String.self, forKey: .provider)
        mode = try container.decodeIfPresent(String.self, forKey: .mode)
        tools = try container.decodeIfPresent(String.self, forKey: .tools)
        maxTurns = try container.decodeIfPresent(Int.self, forKey: .maxTurns)
        maxBudgetUsd = try container.decodeIfPresent(Double.self, forKey: .maxBudgetUsd)
        systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt)
        thinking = try container.decodeIfPresent(Int.self, forKey: .thinking)
        logLevel = try container.decodeIfPresent(String.self, forKey: .logLevel)
        mcpConfigPath = try container.decodeIfPresent(String.self, forKey: .mcpConfigPath)
        hooksConfigPath = try container.decodeIfPresent(String.self, forKey: .hooksConfigPath)
        skillDir = try container.decodeIfPresent(String.self, forKey: .skillDir)
        toolAllow = try container.decodeIfPresent([String].self, forKey: .toolAllow)
        toolDeny = try container.decodeIfPresent([String].self, forKey: .toolDeny)
        output = try container.decodeIfPresent(String.self, forKey: .output)
        // customTools is NOT decoded here -- populated by ConfigLoader.load()
        customTools = nil
    }

    // Memberwise init for programmatic construction (used by tests)
    init(
        apiKey: String? = nil,
        baseURL: String? = nil,
        model: String? = nil,
        provider: String? = nil,
        mode: String? = nil,
        tools: String? = nil,
        maxTurns: Int? = nil,
        maxBudgetUsd: Double? = nil,
        systemPrompt: String? = nil,
        thinking: Int? = nil,
        logLevel: String? = nil,
        mcpConfigPath: String? = nil,
        hooksConfigPath: String? = nil,
        skillDir: String? = nil,
        toolAllow: [String]? = nil,
        toolDeny: [String]? = nil,
        output: String? = nil,
        customTools: [CustomToolConfig]? = nil
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.provider = provider
        self.mode = mode
        self.tools = tools
        self.maxTurns = maxTurns
        self.maxBudgetUsd = maxBudgetUsd
        self.systemPrompt = systemPrompt
        self.thinking = thinking
        self.logLevel = logLevel
        self.mcpConfigPath = mcpConfigPath
        self.hooksConfigPath = hooksConfigPath
        self.skillDir = skillDir
        self.toolAllow = toolAllow
        self.toolDeny = toolDeny
        self.output = output
        self.customTools = customTools
    }
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
    ///
    /// Two-pass loading: JSONDecoder for standard Decodable fields,
    /// then JSONSerialization for the customTools array (which contains
    /// [String: Any] inputSchema that is not directly Decodable).
    static func load(from path: String) -> CLIConfig? {
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }

        guard let data = FileManager.default.contents(atPath: path) else {
            return nil
        }

        do {
            // Pass 1: Decode standard Decodable fields
            var config = try JSONDecoder().decode(CLIConfig.self, from: data)

            // Pass 2: Extract customTools via JSONSerialization for [String: Any] support
            if let topLevel = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let toolsArray = topLevel["customTools"] as? [[String: Any]] {
                config.customTools = toolsArray.compactMap { CustomToolConfig.fromDictionary($0) }
                // If none parsed successfully from the array, set to nil (not empty)
                if config.customTools?.isEmpty == true {
                    config.customTools = nil
                }
            }

            return config
        } catch {
            let msg = "Warning: Failed to parse \(path): \(error.localizedDescription)\n"
            ANSI.writeToStderr(msg)
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

        // Story 7.7: customTools pass-through from config file
        if args.customTools == nil, let customTools = config.customTools {
            args.customTools = customTools
        }

        // Path validation: warn if config-referenced paths don't exist (AC#6)
        warnIfMissing(path: args.mcpConfigPath, label: "mcpConfigPath")
        warnIfMissing(path: args.hooksConfigPath, label: "hooksConfigPath")
        if let skillDir = args.skillDir, !FileManager.default.fileExists(atPath: skillDir) {
            let msg = "Warning: Configured skillDir does not exist: \(skillDir)\n"
            ANSI.writeToStderr(msg)
        }
    }

    /// Print a warning to stderr if the given path does not exist.
    private static func warnIfMissing(path: String?, label: String) {
        guard let path = path else { return }
        if !FileManager.default.fileExists(atPath: path) {
            let msg = "Warning: Configured \(label) does not exist: \(path)\n"
            ANSI.writeToStderr(msg)
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
            ANSI.writeToStderr(msg)
        }
    }
}
