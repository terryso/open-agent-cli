---
stepsCompleted: ['step-01-load-context', 'step-02-discover-tests', 'step-03-map-criteria', 'step-04-analyze-gaps', 'step-05-gate-decision']
lastStep: 'step-05-gate-decision'
lastSaved: '2026-04-22'
---

# Traceability Report: Story 7-6 Dynamic MCP Management

## Gate Decision: CONCERNS

**Rationale:** P0 coverage is 100% (no P0 requirements). P1 coverage is 50% (1 of 2 P1 criteria fully covered). Overall coverage is 67% (4 of 6 criteria fully covered). The two partial-coverage gaps (AC#1: connected server status display, AC#2: successful reconnect) are structural -- they require a real MCP server infrastructure that cannot be simulated in unit tests. Both are explicitly acknowledged in the story as candidates for smoke/manual testing. The testable paths for these ACs (empty state, server not found, usage errors) are fully covered.

---

## Coverage Summary

| Metric | Value |
|--------|-------|
| Total Acceptance Criteria | 6 |
| Fully Covered | 4 (67%) |
| Partially Covered | 2 (33%) |
| Uncovered | 0 (0%) |
| P0 Coverage | 100% (no P0 requirements) |
| P1 Coverage | 50% (1/2 fully covered) |
| P2 Coverage | 100% (3/3 fully covered) |

---

## Traceability Matrix

| AC | Requirement | Priority | Test(s) | Coverage | Notes |
|----|------------|----------|---------|----------|-------|
| AC#1 | /mcp status displays connected server status | P1 | `testMcpStatus_noServers_showsNoConfigured` (empty-state path), `testHelp_includesMcpCommands` (discoverability) | PARTIAL | Happy path (connected servers) requires real MCP infrastructure. Empty-state path covered. Designated for smoke testing. |
| AC#2 | /mcp reconnect reconnects a server | P2 | `testHelp_includesMcpCommands` (discoverability only) | PARTIAL | Successful reconnect requires real MCP server. Error path (server not found) covered via AC#3. Designated for smoke testing. |
| AC#3 | /mcp reconnect nonexistent shows "Server not found" | P1 | `testMcpReconnect_nonexistent_showsNotFound` | FULL | Unit test verifies error message output. |
| AC#4 | /mcp status with no servers shows "No MCP servers configured." | P2 | `testMcpStatus_noServers_showsNoConfigured` | FULL | Unit test verifies empty-state message. |
| AC#5 | /mcp with no/invalid subcommand shows help | P2 | `testMcp_noSubcommand_showsHelp`, `testMcp_unknownSubcommand_showsHelp` | FULL | Both no-arg and invalid-arg paths tested. |
| AC#6 | /mcp reconnect with no arg shows usage | P2 | `testMcpReconnect_noArg_showsUsage` | FULL | Usage message verified. |

### Supplementary Tests (Non-AC)

| Test | Purpose |
|------|---------|
| `testMcp_doesNotExit` | Verifies /mcp commands do not exit REPL (non-destructive behavior) |
| `testRegression_exitCommandStillWorks` | Regression: /exit still functional after /mcp addition |
| `testRegression_helpCommandStillWorks` | Regression: /help still lists /exit and /quit after /mcp addition |

---

## Test Catalog

**File:** `Tests/OpenAgentCLITests/DynamicMcpManagementTests.swift`
**Test Level:** Unit (all tests use real Agent with no MCP servers configured)
**Total Tests:** 9 (6 AC-covering + 3 supplementary/regression)
**Test Strategy:** Real Agent + no MCP config; exercises SDK boundary through public API.

### Test Methods

1. `testMcpStatus_noServers_showsNoConfigured` -- AC#4
2. `testMcpReconnect_nonexistent_showsNotFound` -- AC#3
3. `testMcpReconnect_noArg_showsUsage` -- AC#6
4. `testMcp_noSubcommand_showsHelp` -- AC#5
5. `testMcp_unknownSubcommand_showsHelp` -- AC#5
6. `testHelp_includesMcpCommands` -- AC#1,#2 discoverability
7. `testMcp_doesNotExit` -- supplementary
8. `testRegression_exitCommandStillWorks` -- regression
9. `testRegression_helpCommandStillWorks` -- regression

---

## Coverage Heuristics

| Heuristic | Status |
|-----------|--------|
| API endpoint coverage | N/A (CLI REPL commands, not HTTP endpoints) |
| Auth/authz negative paths | N/A (no auth requirements in this story) |
| Error-path coverage | GOOD -- AC#3 (server not found), AC#4 (no servers), AC#6 (missing arg) all tested |
| Happy-path coverage | PARTIAL -- AC#1 (connected status display) and AC#2 (successful reconnect) require real MCP server |

---

## Gap Analysis

### Critical Gaps (P0)
None.

### High Gaps (P1)

| AC | Gap | Mitigation |
|----|-----|------------|
| AC#1 | No unit test for displaying connected server status with actual MCP data | Requires real MCP server infrastructure. The testable path (empty state = "No MCP servers configured.") is fully covered. Full verification via smoke test with live MCP server. |

### Medium Gaps (P2)

| AC | Gap | Mitigation |
|----|-----|------------|
| AC#2 | No unit test for successful reconnect flow | Requires real MCP server. The error paths (server not found, missing arg) are covered. Full verification via smoke test with live MCP server. |

---

## Recommendations

| Priority | Action |
|----------|--------|
| MEDIUM | Create integration/smoke test for AC#1 with a real MCP server (e.g., stdio-based test server) to verify connected status display |
| MEDIUM | Create integration/smoke test for AC#2 with a real MCP server to verify successful reconnect message |
| LOW | Consider adding a mock/stub layer for MCP server interactions to enable full unit testing of AC#1 and AC#2 happy paths |

---

## Implementation File

**Modified:** `Sources/OpenAgentCLI/REPLLoop.swift`
- Added `/mcp` case in `handleSlashCommand` switch (line 199)
- Added `handleMcp(parts:)` dispatcher method (line 421)
- Added `handleMcpStatus()` method (line 453)
- Added `handleMcpReconnect(serverName:)` method (line 477)
- Updated `printHelp()` to include /mcp commands (lines 221-222)

## Regression Status

Full regression suite passed at story completion: **581 tests, 0 failures**.
