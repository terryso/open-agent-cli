---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-20'
inputDocuments:
  - '_bmad-output/implementation-artifacts/4-1-mcp-server-configuration-and-connection.md'
  - 'Sources/OpenAgentCLI/AgentFactory.swift'
  - 'Sources/OpenAgentCLI/ArgumentParser.swift'
  - 'Sources/OpenAgentCLI/CLI.swift'
  - 'Tests/OpenAgentCLITests/AgentFactoryTests.swift'
  - 'Tests/OpenAgentCLITests/ConfigLoaderTests.swift'
  - 'open-agent-sdk-swift/Sources/OpenAgentSDK/Types/MCPConfig.swift'
---

# ATDD Checklist: Story 4.1 - MCP Server Configuration and Connection

## TDD Red Phase (Current)

Failing tests generated -- all tests reference `MCPConfigLoader` which does not exist yet.

- **Unit Tests**: 13 tests in `Tests/OpenAgentCLITests/MCPConfigLoaderTests.swift` (all will fail to compile)
- **Integration Tests**: 2 tests in `Tests/OpenAgentCLITests/AgentFactoryTests.swift` (will fail to compile until MCPConfigLoader exists)

## Acceptance Criteria Coverage

| AC # | Criterion | Test Coverage | Priority |
|------|-----------|---------------|----------|
| #1 | Valid MCP config JSON -> MCP servers connect at startup | `testLoadMcpConfig_validStdioConfig`, `testLoadMcpConfig_stdioWithArgsAndEnv`, `testLoadMcpConfig_validSseConfig`, `testLoadMcpConfig_validHttpConfig`, `testLoadMcpConfig_multipleServers`, `testCreateAgent_withMcp_mcpServersPopulated` | P0 |
| #2 | MCP tools included with built-in tools in tool pool | `testLoadMcpConfig_multipleServers`, `testCreateAgent_withMcp_mcpServersPopulated` | P0 |
| #3 | MCP server connection failure -> warning displayed, CLI continues | `testCreateAgent_withInvalidMcpServerConfig_doesNotThrow` (runtime behavior tested via SDK) | P1 |
| #4 | Nonexistent MCP config file -> clear error, exit code 1 | `testLoadMcpConfig_fileNotFound`, `testLoadMcpConfig_invalidJson`, `testLoadMcpConfig_missingCommandAndUrl`, `testLoadMcpConfig_missingMcpServersKey` | P0 |

## Test Inventory

### MCPConfigLoaderTests.swift (13 tests)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testLoadMcpConfig_validStdioConfig` | #1 | P0 | Valid stdio config parses to McpStdioConfig |
| 2 | `testLoadMcpConfig_stdioWithArgsAndEnv` | #1 | P0 | Stdio config with full args/env fields |
| 3 | `testLoadMcpConfig_validSseConfig` | #1 | P0 | Valid SSE config parses to McpTransportConfig |
| 4 | `testLoadMcpConfig_validHttpConfig` | #1 | P0 | Valid HTTP config parses to McpTransportConfig |
| 5 | `testLoadMcpConfig_multipleServers` | #1,#2 | P0 | Multiple mixed transport types |
| 6 | `testLoadMcpConfig_emptyServers` | #1 | P1 | Empty mcpServers object returns empty dict |
| 7 | `testLoadMcpConfig_fileNotFound` | #4 | P0 | File not found throws descriptive error |
| 8 | `testLoadMcpConfig_invalidJson` | #4 | P0 | Invalid JSON throws descriptive error |
| 9 | `testLoadMcpConfig_missingCommandAndUrl` | #4 | P0 | Missing required fields throws error |
| 10 | `testLoadMcpConfig_missingMcpServersKey` | #4 | P0 | Missing mcpServers key throws error |
| 11 | `testLoadMcpConfig_stdioMissingCommand` | #4 | P1 | Entry with url+command both missing |
| 12 | `testCreateAgent_withoutMcp_mcpServersIsNil` | #2 | P0 | No --mcp flag -> no MCP servers loaded |
| 13 | `testCreateAgent_withMcp_mcpServersPopulated` | #1,#2 | P0 | --mcp flag -> MCP config loaded and passed |

## Test Strategy

- **Stack**: Backend (Swift, XCTest)
- **Test Levels**: Unit (MCPConfigLoader parsing), Integration (AgentFactory with MCP)
- **Mode**: AI Generation (backend project)
- **Approach**: Create temp JSON fixture files, call MCPConfigLoader, verify parsed output matches expected SDK types

## Implementation Guidance

### Files to Create

1. `Sources/OpenAgentCLI/MCPConfigLoader.swift` -- New file with `loadMcpConfig(from:)` function

### Files to Modify

1. `Sources/OpenAgentCLI/AgentFactory.swift` -- Call MCPConfigLoader when `args.mcpConfigPath` is set, pass result to `AgentOptions.mcpServers`
2. `Sources/OpenAgentCLI/CLI.swift` -- Add MCP connection progress hint

### Key Implementation Notes

- MCPConfigLoader should use Foundation's JSONSerialization (zero third-party deps)
- Transport type inference: `command` field -> stdio, `url` field -> sse
- Error types should be descriptive for CLI output
- SDK handles runtime MCP connection via `AgentOptions.mcpServers` -- CLI only needs to parse and pass config

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Implement `MCPConfigLoader.swift` with `loadMcpConfig(from:)` function
2. Add MCPConfigLoader integration to `AgentFactory.createAgent(from:)`
3. Run tests: `swift test --filter MCPConfigLoaderTests`
4. Verify all tests PASS (green phase)
5. Run full regression: `swift test` (verify 306+ existing tests still pass)
6. Commit passing tests
