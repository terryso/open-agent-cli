import Foundation
import OpenAgentSDK

// MARK: - MCPConfigLoaderError

/// Errors that can occur when loading MCP server configuration.
enum MCPConfigLoaderError: LocalizedError {
    case fileNotFound(String)
    case invalidJSON(String)
    case missingMcpServersKey
    case missingRequiredField(server: String, field: String)
    case emptyCommand(server: String)
    case emptyUrl(server: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "MCP config file not found: \(path)"
        case .invalidJSON(let detail):
            return "Invalid MCP config JSON: \(detail)"
        case .missingMcpServersKey:
            return "Invalid MCP config: missing 'mcpServers' key"
        case .missingRequiredField(let server, let field):
            return "Invalid MCP config for server '\(server)': missing required field '\(field)'. Each server entry must have either 'command' (stdio) or 'url' (sse/http)."
        case .emptyCommand(let server):
            return "Invalid MCP config for server '\(server)': 'command' must not be empty"
        case .emptyUrl(let server):
            return "Invalid MCP config for server '\(server)': 'url' must not be empty"
        }
    }
}

// MARK: - MCPConfigLoader

/// Loads MCP server configuration from a JSON file.
///
/// Parses the standard MCP config format (compatible with Claude Desktop / Claude Code)
/// into SDK-native ``McpServerConfig`` values. Transport type is inferred from the
/// presence of `command` (stdio) or `url` (sse) fields.
///
/// JSON format:
/// ```json
/// {
///   "mcpServers": {
///     "server-name": {
///       "command": "npx",
///       "args": ["-y", "some-mcp-server"]
///     },
///     "remote": {
///       "url": "https://mcp.example.com/sse",
///       "headers": { "Authorization": "Bearer token" }
///     }
///   }
/// }
/// ```
enum MCPConfigLoader {

    /// Load and parse an MCP server configuration file.
    ///
    /// - Parameter path: File system path to the JSON config file.
    /// - Returns: A dictionary mapping server names to their ``McpServerConfig`` values.
    /// - Throws: ``MCPConfigLoaderError`` if the file cannot be read or parsed.
    static func loadMcpConfig(from path: String) throws -> [String: McpServerConfig] {
        // 1. Check file exists
        guard FileManager.default.fileExists(atPath: path) else {
            throw MCPConfigLoaderError.fileNotFound(path)
        }

        // 2. Read file data
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            throw MCPConfigLoaderError.fileNotFound(path)
        }

        // 3. Parse JSON
        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw MCPConfigLoaderError.invalidJSON(error.localizedDescription)
        }

        // 4. Validate top-level structure
        guard let topLevel = jsonObject as? [String: Any] else {
            throw MCPConfigLoaderError.invalidJSON("Expected a JSON object at top level")
        }

        guard let mcpServers = topLevel["mcpServers"] else {
            throw MCPConfigLoaderError.missingMcpServersKey
        }

        // 5. Handle empty mcpServers
        guard let serversDict = mcpServers as? [String: [String: Any]] else {
            // If mcpServers is not a dictionary of objects, it's invalid
            if mcpServers is NSNull {
                return [:]
            }
            throw MCPConfigLoaderError.invalidJSON("'mcpServers' must be an object")
        }

        // 6. Parse each server entry
        var result: [String: McpServerConfig] = [:]
        for (name, config) in serversDict {
            result[name] = try parseServerConfig(name: name, config: config)
        }

        return result
    }

    // MARK: - Private Helpers

    /// Parse a single server entry from the JSON config.
    ///
    /// Transport type inference:
    /// - Has `command` field -> stdio
    /// - Has `url` field -> sse
    /// - Neither -> error
    private static func parseServerConfig(name: String, config: [String: Any]) throws -> McpServerConfig {
        let hasCommand = config["command"] != nil
        let hasUrl = config["url"] != nil

        if hasCommand {
            return try parseStdioConfig(name: name, config: config)
        } else if hasUrl {
            return try parseTransportConfig(name: name, config: config)
        } else {
            throw MCPConfigLoaderError.missingRequiredField(server: name, field: "command or url")
        }
    }

    /// Parse a stdio transport config (has `command` field).
    private static func parseStdioConfig(name: String, config: [String: Any]) throws -> McpServerConfig {
        guard let command = config["command"] as? String, !command.isEmpty else {
            throw MCPConfigLoaderError.emptyCommand(server: name)
        }

        let args = config["args"] as? [String]
        let env = config["env"] as? [String: String]

        return .stdio(McpStdioConfig(command: command, args: args, env: env))
    }

    /// Parse a transport config (has `url` field) as SSE.
    private static func parseTransportConfig(name: String, config: [String: Any]) throws -> McpServerConfig {
        guard let url = config["url"] as? String, !url.isEmpty else {
            throw MCPConfigLoaderError.emptyUrl(server: name)
        }

        let headers = config["headers"] as? [String: String]

        return .sse(McpTransportConfig(url: url, headers: headers))
    }
}
