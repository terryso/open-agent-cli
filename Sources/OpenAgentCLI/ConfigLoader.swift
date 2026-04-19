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

    /// Apply config values to ParsedArgs, filling in nil fields only.
    /// CLI args and env vars take precedence — config file is the lowest priority.
    ///
    /// TODO: Sentinel-value comparison — fields with non-Optional defaults (mode, tools,
    /// maxTurns, model) compare against hardcoded defaults to detect "user didn't set this."
    /// This means explicitly passing `--mode default` will still be overridden by the config
    /// file. Fix by tracking explicitly-set fields in ParsedArgs (e.g., via a Set<String>).
    static func apply(_ config: CLIConfig?, to args: inout ParsedArgs) {
        guard let config = config else { return }

        if args.apiKey == nil, let key = config.apiKey {
            args.apiKey = key
        }
        if args.baseURL == nil, let url = config.baseURL {
            args.baseURL = url
        }
        if args.provider == nil, let provider = config.provider {
            args.provider = provider
        }
        if args.mode == "default", let mode = config.mode {
            args.mode = mode
        }
        if args.tools == "core", let tools = config.tools {
            args.tools = tools
        }
        if args.maxTurns == 10, let turns = config.maxTurns {
            args.maxTurns = turns
        }
        if args.maxBudgetUsd == nil, let budget = config.maxBudgetUsd {
            args.maxBudgetUsd = budget
        }
        if args.systemPrompt == nil, let prompt = config.systemPrompt {
            args.systemPrompt = prompt
        }
        if args.thinking == nil, let thinking = config.thinking {
            args.thinking = thinking
        }
        if args.logLevel == nil, let level = config.logLevel {
            args.logLevel = level
        }
        // model: only override if user didn't explicitly change it from default
        if args.model == "glm-5.1", let model = config.model {
            args.model = model
        }
    }
}
