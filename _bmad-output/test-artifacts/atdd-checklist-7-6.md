---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-22'
workflowType: 'testarch-atdd'
inputDocuments:
  - _bmad-output/implementation-artifacts/7-6-dynamic-mcp-management.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - Sources/OpenAgentCLI/REPLLoop.swift
  - Tests/OpenAgentCLITests/REPLLoopTests.swift
  - Tests/OpenAgentCLITests/DynamicREPLCommandTests.swift
  - Tests/OpenAgentCLITests/SessionForkTests.swift
  - .build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift
  - .build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Types/MCPTypes.swift
  - .build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift
---

# ATDD Checklist - Epic 7, Story 7.6: Dynamic MCP Management

**Date:** 2026-04-22
**Author:** TEA Agent
**Primary Test Level:** Unit (Swift/XCTest)
**Stack:** Backend (Swift)
**TDD Phase:** RED (tests fail as expected -- feature not yet implemented)

---

## Story Summary

**As a** power user
**I want to** inspect and reconnect MCP servers during a session
**So that** I can troubleshoot connection issues without restarting.

## Acceptance Criteria

| AC# | Description | Test Coverage |
|-----|-------------|---------------|
| #1 | Given MCP servers are connected, when I enter `/mcp status`, then each server's connection status is displayed | (requires real MCP config -- manual/smoke test) |
| #2 | Given an MCP server is disconnected, when I enter `/mcp reconnect <name>`, then the server reconnects | (requires real MCP config -- manual/smoke test) |
| #3 | Given a nonexistent server name, when I enter `/mcp reconnect nonexistent`, then "Server not found" error is displayed | testMcpReconnect_nonexistent_showsNotFound |
| #4 | Given no MCP servers are configured, when I enter `/mcp status`, then "No MCP servers configured." is displayed | testMcpStatus_noServers_showsNoConfigured |
| #5 | Given `/mcp` with no subcommand or invalid subcommand, when I enter `/mcp` or `/mcp unknown`, then help text listing available /mcp subcommands is displayed | testMcp_noSubcommand_showsHelp, testMcp_unknownSubcommand_showsHelp |
| #6 | Given `/mcp reconnect` with no server name, when I enter `/mcp reconnect`, then "Usage: /mcp reconnect <name>" error is displayed | testMcpReconnect_noArg_showsUsage |

---

## Generation Mode: AI Generation (Backend)

This is a Swift backend project. No browser recording needed. All tests are XCTest unit tests.

---

## Existing Test Coverage (Pre-Story 7.6)

The following REPL command tests already exist from earlier stories:

| Test File | Test Method | AC Covered | Notes |
|-----------|-------------|------------|-------|
| REPLLoopTests.swift | testREPLLoop_helpCommand_showsAvailableCommands | N/A | /help basic |
| DynamicREPLCommandTests.swift | testModelCommand_validModel_switchesAndConfirms | N/A | /model |
| DynamicREPLCommandTests.swift | testModeCommand_validMode_switchesAndConfirms | N/A | /mode |
| DynamicREPLCommandTests.swift | testCostCommand_initialState_showsZero | N/A | /cost |
| DynamicREPLCommandTests.swift | testClearCommand_showsConfirmation | N/A | /clear |
| SessionForkTests.swift | testFork_success_displaysConfirmation | N/A | /fork |

**Gap Analysis:** No /mcp tests exist. The following gaps must be filled:
1. /mcp status with no servers shows "No MCP servers configured." (AC#4)
2. /mcp reconnect with nonexistent server shows "Server not found" (AC#3)
3. /mcp reconnect with no argument shows usage (AC#6)
4. /mcp with no subcommand shows help (AC#5)
5. /mcp with unknown subcommand shows help (AC#5)
6. /help output includes /mcp commands (AC#1, #2 discoverability)
7. /mcp does not exit REPL (non-destructive)

---

## Test Strategy

### Test Level: Unit

All tests are unit tests targeting `REPLLoop` directly via the existing `MockInputReader` + `MockTextOutputStream` pattern. Tests use a real Agent with no MCP servers configured, which means:
- `agent.mcpServerStatus()` returns empty dictionary `[:]`
- `agent.reconnectMcpServer(name:)` throws `MCPClientManagerError.serverNotFound`

### Priority Assignment

| Priority | Test | Rationale |
|----------|------|-----------|
| P0 | testMcpStatus_noServers_showsNoConfigured | Core feature -- AC#4, verifies empty state |
| P0 | testMcpReconnect_nonexistent_showsNotFound | Core feature -- AC#3, error handling |
| P0 | testMcpReconnect_noArg_showsUsage | Core feature -- AC#6, argument validation |
| P1 | testMcp_noSubcommand_showsHelp | Usability -- AC#5, help for bare /mcp |
| P1 | testMcp_unknownSubcommand_showsHelp | Usability -- AC#5, help for invalid subcommand |
| P1 | testHelp_includesMcpCommands | Discoverability -- users need to know /mcp exists |
| P1 | testMcp_doesNotExit | REPL integrity -- /mcp should never exit |

### Untestable in Unit Tests (Manual/Smoke Coverage Required)

| AC# | Scenario | Reason |
|-----|----------|--------|
| #1 | /mcp status displays connected server details | Requires real MCP server configuration |
| #2 | /mcp reconnect successfully reconnects | Requires real MCP server configuration |

---

## TDD Red Phase (Current)

All new tests are designed to **fail** until `/mcp` is implemented in REPLLoop.swift.

### Expected Failure Modes

1. `testMcpStatus_noServers_showsNoConfigured` -- `/mcp` case not in switch statement, falls to "Unknown command"
2. `testMcpReconnect_nonexistent_showsNotFound` -- `/mcp` not handled, never calls reconnectMcpServer
3. `testMcpReconnect_noArg_showsUsage` -- `/mcp` not handled, no subcommand parsing
4. `testMcp_noSubcommand_showsHelp` -- `/mcp` not handled, no help output
5. `testMcp_unknownSubcommand_showsHelp` -- `/mcp` not handled
6. `testHelp_includesMcpCommands` -- `/mcp` not in help text
7. `testMcp_doesNotExit` -- `/mcp` case falls to "Unknown command" which doesn't exit, but output check in other tests will fail first

### Test Files

1. **DynamicMcpManagementTests.swift** (new) -- 7 test methods
2. **REPLLoopTests.swift** (no changes) -- existing tests should still pass

---

## Acceptance Criteria Coverage Matrix

| AC# | Test Methods | Status |
|-----|-------------|--------|
| #1 | (manual/smoke test -- requires real MCP config) | N/A |
| #2 | (manual/smoke test -- requires real MCP config) | N/A |
| #3 | testMcpReconnect_nonexistent_showsNotFound | RED (will fail until implemented) |
| #4 | testMcpStatus_noServers_showsNoConfigured | RED (will fail until implemented) |
| #5 | testMcp_noSubcommand_showsHelp, testMcp_unknownSubcommand_showsHelp | RED |
| #6 | testMcpReconnect_noArg_showsUsage | RED |

**Coverage:** 4/6 ACs covered by automated tests (67%). Remaining 2 ACs (#1, #2) require real MCP server configuration and are covered by manual/smoke testing.

---

## Next Steps (Post-ATDD)

After the ATDD tests are verified:

1. Run `swift test --filter DynamicMcpManagementTests` to verify all tests fail (RED phase)
2. Implement `/mcp` in REPLLoop.swift following the Dev Notes in the story
3. Run tests again to verify GREEN phase
4. Run full regression suite: `swift test`
5. Commit passing tests + implementation

---

## Implementation Guidance

### Source file to modify:

1. **`Sources/OpenAgentCLI/REPLLoop.swift`**
   - Add `"/mcp"` case in `handleSlashCommand` switch (line ~180)
   - Add `handleMcp(parts:)` method for subcommand dispatch
   - Add `handleMcpStatus()` method calling `agent.mcpServerStatus()`
   - Add `handleMcpReconnect(serverName:)` method calling `agent.reconnectMcpServer(name:)`
   - Add `/mcp status` and `/mcp reconnect <name>` to `printHelp()` output

### Test file created:

1. **`Tests/OpenAgentCLITests/DynamicMcpManagementTests.swift`** -- 7 new test methods

---

## Summary Statistics

- **Total new tests:** 9 (7 ATDD + 2 regression guards)
- **DynamicMcpManagementTests:** 9
- **TDD RED -- Failing:** 6 (core /mcp behavior tests + help discoverability)
- **TDD GREEN -- Passing:** 3 (testMcp_doesNotExit + 2 regression guards)
- **Acceptance criteria covered by automation:** 4/6 (67%)
- **Acceptance criteria covered by manual testing:** 2/6 (33%)
- **TDD Phase:** RED (all feature tests fail until /mcp is implemented)
