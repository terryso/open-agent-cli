import Foundation
import OpenAgentSDK

// MARK: - HookConfigLoaderError

/// Errors that can occur when loading hooks configuration.
enum HookConfigLoaderError: LocalizedError {
    case fileNotFound(String)
    case invalidJSON(String)
    case missingHooksKey
    case invalidEventName(String)
    case missingCommand(event: String)
    case emptyCommand(event: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Hooks config file not found: \(path)"
        case .invalidJSON(let detail):
            return "Invalid hooks config JSON: \(detail)"
        case .missingHooksKey:
            return "Invalid hooks config: missing 'hooks' key"
        case .invalidEventName(let name):
            return "Invalid hooks config: unknown event name '\(name)'. Valid events: \(HookEvent.allCases.map(\.rawValue).sorted().joined(separator: ", "))"
        case .missingCommand(let event):
            return "Invalid hooks config for event '\(event)': missing required field 'command'"
        case .emptyCommand(let event):
            return "Invalid hooks config for event '\(event)': 'command' must not be empty"
        }
    }
}

// MARK: - HookConfigLoader

/// Loads hooks configuration from a JSON file.
///
/// Parses the hooks config format into SDK-native ``HookDefinition`` values.
/// Only shell command hooks are supported (via the `command` field); handler
/// closures cannot be represented in JSON.
///
/// JSON format:
/// ```json
/// {
///   "hooks": {
///     "preToolUse": [
///       { "command": "echo 'Before tool'", "matcher": "Bash", "timeout": 5000 }
///     ],
///     "postToolUse": [
///       { "command": "echo 'After tool'" }
///     ]
///   }
/// }
/// ```
enum HookConfigLoader {

    /// Load and parse a hooks configuration file.
    ///
    /// - Parameter path: File system path to the JSON config file.
    /// - Returns: A dictionary mapping event name strings to arrays of ``HookDefinition`` values.
    /// - Throws: ``HookConfigLoaderError`` if the file cannot be read or parsed.
    static func loadHooksConfig(from path: String) throws -> [String: [HookDefinition]] {
        // 1. Check file exists
        guard FileManager.default.fileExists(atPath: path) else {
            throw HookConfigLoaderError.fileNotFound(path)
        }

        // 2. Read file data
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            throw HookConfigLoaderError.fileNotFound(path)
        }

        // 3. Parse JSON
        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw HookConfigLoaderError.invalidJSON(error.localizedDescription)
        }

        // 4. Validate top-level structure
        guard let topLevel = jsonObject as? [String: Any] else {
            throw HookConfigLoaderError.invalidJSON("Expected a JSON object at top level")
        }

        guard let hooks = topLevel["hooks"] else {
            throw HookConfigLoaderError.missingHooksKey
        }

        // 5. Handle empty hooks
        guard let hooksDict = hooks as? [String: Any] else {
            if hooks is NSNull {
                return [:]
            }
            throw HookConfigLoaderError.invalidJSON("'hooks' must be an object")
        }

        if hooksDict.isEmpty {
            return [:]
        }

        // 6. Parse each event entry
        var result: [String: [HookDefinition]] = [:]
        let validEventNames = Set(HookEvent.allCases.map(\.rawValue))

        for (eventName, entry) in hooksDict {
            // Skip invalid event names silently (matches SDK's registerFromConfig behavior)
            guard validEventNames.contains(eventName) else {
                continue
            }

            // Each event maps to an array of hook objects
            guard let hookArray = entry as? [[String: Any]] else {
                throw HookConfigLoaderError.invalidJSON("Event '\(eventName)' must be an array of hook objects")
            }

            var definitions: [HookDefinition] = []
            for hookEntry in hookArray {
                definitions.append(try parseHookDefinition(event: eventName, entry: hookEntry))
            }
            result[eventName] = definitions
        }

        return result
    }

    // MARK: - Private Helpers

    /// Parse a single hook entry from the JSON config.
    private static func parseHookDefinition(event: String, entry: [String: Any]) throws -> HookDefinition {
        // command is required
        guard let command = entry["command"] as? String else {
            throw HookConfigLoaderError.missingCommand(event: event)
        }

        guard !command.isEmpty else {
            throw HookConfigLoaderError.emptyCommand(event: event)
        }

        let matcher = entry["matcher"] as? String
        let timeout = entry["timeout"] as? Int

        return HookDefinition(
            command: command,
            matcher: matcher,
            timeout: timeout
        )
    }
}
