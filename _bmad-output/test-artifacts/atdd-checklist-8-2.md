---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-23'
workflowType: testarch-atdd
inputDocuments:
  - _bmad-output/implementation-artifacts/8-2-e2e-scenario-validation.md
  - Tests/OpenAgentE2ETests/E2ETests.swift
---

# ATDD Checklist - Epic 8, Story 8.2: End-to-End Scenario Validation

**Date:** 2026-04-23
**Author:** TEA Agent (ATDD workflow, yolo mode)
**Primary Test Level:** E2E (black-box subprocess)

---

## Story Summary

Validate CLI-to-SDK integration integrity through multi-turn real-world scenarios, confirming the SDK's public API is sufficient to power a fully-functional Agent application.

**As a** SDK validator
**I want** to validate CLI-to-SDK integration integrity through multi-turn real-world scenarios
**So that** I can confirm the SDK's public API is sufficient to power a fully-functional Agent application

---

## Acceptance Criteria

1. **AC#1:** Multi-turn programming task with tool call chains -- Agent correctly invokes Write/Bash/Edit tools, progress visible in real-time
2. **AC#2:** MCP server integration and tool discovery -- MCP tools discovered, invoked, `/mcp status` shows connection
3. **AC#3:** Permission mode enforcement and dynamic switching -- auto-approval in non-interactive, `--mode` flag controls behavior
4. **AC#4:** Cross-session conversation continuity -- session persists across restarts, prior context is available

---

## Failing Tests Created (RED Phase)

### E2E Tests (16 new tests, all TDD RED phase)

**File:** `Tests/OpenAgentE2ETests/E2ETests.swift`

#### AC#1: Multi-turn tool call chains (3 tests)

- **Test:** `testMultiTurn_createCompileModify`
  - **Priority:** P0
  - **Verifies:** Agent uses Write + Bash tools to create a Swift file, compile it, and run it
  - **Timeout:** 90s (multi-turn orchestration)
  - **Pass criteria:** exitCode == 0, stdout contains "Hello E2E"

- **Test:** `testMultiTurn_toolCallVisibility`
  - **Priority:** P0
  - **Verifies:** Tool call output markers (tool name, parameters, duration) appear in stdout
  - **Timeout:** 60s
  - **Pass criteria:** exitCode == 0, stdout contains "visibility-test-marker-8-2"

- **Test:** `testMultiTurn_grepAndRead`
  - **Priority:** P1
  - **Verifies:** Agent uses Glob/Grep/Read tools in sequence to find and inspect files
  - **Timeout:** 60s
  - **Pass criteria:** exitCode == 0, stdout mentions "import"

#### AC#2: MCP integration (2 tests)

- **Test:** `testMcp_serverConnectsAndToolsAvailable`
  - **Priority:** P0
  - **Verifies:** --mcp flag connects to MCP server, tools are discovered
  - **Timeout:** 60s
  - **Pass criteria:** exitCode == 0, stdout mentions MCP tool "echo"
  - **Note:** Uses XCTSkip if MCP server is unavailable (graceful degradation)

- **Test:** `testMcp_flagAcceptedAndStarts`
  - **Priority:** P1
  - **Verifies:** --mcp flag with empty config is accepted, CLI starts normally
  - **Timeout:** 30s
  - **Pass criteria:** exitCode == 0, stdout contains "mcp-ok"

#### AC#3: Permission mode enforcement (3 tests)

- **Test:** `testPermission_autoMode_singleShot`
  - **Priority:** P0
  - **Verifies:** --mode auto auto-approves all tools without prompts
  - **Timeout:** 30s
  - **Pass criteria:** exitCode == 0, stdout contains "auto-mode-test-passed"

- **Test:** `testPermission_defaultMode_nonInteractive`
  - **Priority:** P0
  - **Verifies:** --mode default auto-approves in non-interactive single-shot mode
  - **Timeout:** 30s
  - **Pass criteria:** exitCode == 0, stdout contains "default-mode-test-passed"

- **Test:** `testPermission_modeSwitchViaFlag`
  - **Priority:** P1
  - **Verifies:** All valid --mode values (plan, dontAsk, acceptEdits, bypassPermissions) work
  - **Timeout:** 30s per mode (4 modes tested)
  - **Pass criteria:** exitCode == 0 for each mode, stdout contains expected marker

#### AC#4: Session continuity (2 tests)

- **Test:** `testSession_persistAndRestore`
  - **Priority:** P0
  - **Verifies:** Session created in one invocation is restored in the next, prior context is available
  - **Timeout:** 30s per invocation (2 invocations)
  - **Pass criteria:** exitCode == 0 for both, restored session remembers secret marker

- **Test:** `testSession_restoreWithSessionFlag`
  - **Priority:** P0
  - **Verifies:** --session <id> explicitly restores a specific session by ID
  - **Timeout:** 30s per invocation (2 invocations)
  - **Pass criteria:** exitCode == 0, session ID extracted from JSON, marker remembered
  - **Note:** Uses --output json to extract sessionId; skips if format changes

#### Cross-cutting: Flag combinations and edge cases (6 tests, 2 new)

- **Test:** `testModelSwitch_viaFlag`
  - **Priority:** P2
  - **Verifies:** --model flag with different provider/model switches successfully
  - **Note:** Skips if OpenAI provider not configured

- **Test:** `testMultipleToolTiers_combined`
  - **Priority:** P2
  - **Verifies:** --tools advanced loads additional tools

- **Test:** `testOutputFormats_textAndJson`
  - **Priority:** P1
  - **Verifies:** Both --output text and --output json produce valid output

- **Test:** `testQuietMode_suppressesNonEssential`
  - **Priority:** P1
  - **Verifies:** --quiet suppresses Turns/Cost/Duration summary

---

## ATDD Coverage Matrix

| AC# | Acceptance Criterion | Tests | Priority |
|-----|---------------------|-------|----------|
| AC#1 | Multi-turn tool call chains | testMultiTurn_createCompileModify, testMultiTurn_toolCallVisibility, testMultiTurn_grepAndRead | P0, P0, P1 |
| AC#2 | MCP integration | testMcp_serverConnectsAndToolsAvailable, testMcp_flagAcceptedAndStarts | P0, P1 |
| AC#3 | Permission modes | testPermission_autoMode_singleShot, testPermission_defaultMode_nonInteractive, testPermission_modeSwitchViaFlag | P0, P0, P1 |
| AC#4 | Session continuity | testSession_persistAndRestore, testSession_restoreWithSessionFlag | P0, P0 |
| Cross | Flag combinations | testModelSwitch_viaFlag, testMultipleToolTiers_combined, testOutputFormats_textAndJson, testQuietMode_suppressesNonEssential | P2, P2, P1, P1 |

---

## Implementation Checklist

### Test: testMultiTurn_createCompileModify (AC#1, P0)

**Tasks to make this test pass:**

- [ ] Ensure Write tool creates files at specified paths
- [ ] Ensure Bash tool can invoke `swiftc` for compilation
- [ ] Ensure Bash tool can execute compiled binaries
- [ ] Ensure Agent orchestration chains 3+ tool calls within max-turns limit
- [ ] Run: `swift test --filter OpenAgentE2ETests/testMultiTurn_createCompileModify`

### Test: testMultiTurn_toolCallVisibility (AC#1, P0)

**Tasks to make this test pass:**

- [ ] Verify tool call output includes tool name in stdout
- [ ] Verify Bash tool output is captured in stdout
- [ ] Run: `swift test --filter OpenAgentE2ETests/testMultiTurn_toolCallVisibility`

### Test: testMcp_serverConnectsAndToolsAvailable (AC#2, P0)

**Tasks to make this test pass:**

- [ ] Implement MCP server connection in SDK
- [ ] Ensure --mcp flag reads config and connects to servers
- [ ] Ensure MCP tools appear in agent's tool pool
- [ ] Ensure agent can invoke MCP tools and return results
- [ ] Run: `swift test --filter OpenAgentE2ETests/testMcp_serverConnectsAndToolsAvailable`

### Test: testPermission_autoMode_singleShot (AC#3, P0)

**Tasks to make this test pass:**

- [ ] Verify --mode auto auto-approves all tool calls
- [ ] Verify no permission prompts appear in non-interactive mode
- [ ] Run: `swift test --filter OpenAgentE2ETests/testPermission_autoMode_singleShot`

### Test: testPermission_defaultMode_nonInteractive (AC#3, P0)

**Tasks to make this test pass:**

- [ ] Verify --mode default auto-approves in single-shot (non-interactive) mode
- [ ] Verify warning message is logged (not blocking)
- [ ] Run: `swift test --filter OpenAgentE2ETests/testPermission_defaultMode_nonInteractive`

### Test: testSession_persistAndRestore (AC#4, P0)

**Tasks to make this test pass:**

- [ ] Verify session is saved to disk on exit
- [ ] Verify session is auto-restored on next launch (when --no-restore is not set)
- [ ] Verify restored session includes full conversation history
- [ ] Run: `swift test --filter OpenAgentE2ETests/testSession_persistAndRestore`

### Test: testSession_restoreWithSessionFlag (AC#4, P0)

**Tasks to make this test pass:**

- [ ] Verify --output json includes sessionId field
- [ ] Verify --session <id> loads the specific session
- [ ] Verify restored session has access to prior conversation context
- [ ] Run: `swift test --filter OpenAgentE2ETests/testSession_restoreWithSessionFlag`

---

## Running Tests

```bash
# Run all E2E tests (requires valid API key)
swift test --filter OpenAgentE2ETests

# Run specific AC#1 tests
swift test --filter OpenAgentE2ETests/testMultiTurn

# Run specific AC#2 tests
swift test --filter OpenAgentE2ETests/testMcp

# Run specific AC#3 tests
swift test --filter OpenAgentE2ETests/testPermission

# Run specific AC#4 tests
swift test --filter OpenAgentE2ETests/testSession

# Note: E2E tests are NOT in CI -- run manually only
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

- All 16 new tests written in `Tests/OpenAgentE2ETests/E2ETests.swift`
- Tests compile successfully (`swift build --build-tests` passes)
- Tests are designed to exercise real API calls and subprocess behavior
- Tests use existing `launchCLI()` black-box infrastructure

### GREEN Phase (Next Steps)

1. Pick one failing test from implementation checklist (start with P0 tests)
2. Implement minimal code to make that test pass
3. Run the test to verify green
4. Move to next test

### REFACTOR Phase (After All Tests Pass)

1. Review code for quality
2. Extract duplications
3. Ensure tests still pass after each refactor

---

## Manual Test Procedures (Interactive-Only Scenarios)

### Interactive Permission Prompt (AC#3 interactive mode)

1. Start CLI with `--mode default` (no prompt argument)
2. Ask Agent to run a Bash command
3. Verify permission prompt appears in REPL
4. Approve/deny and verify correct behavior
5. Type `/mode auto` to switch mode dynamically
6. Ask Agent to run another Bash command
7. Verify no permission prompt appears in auto mode

### REPL /fork and /resume

1. Start CLI, have a multi-turn conversation
2. Type `/fork` to create a branch
3. Continue conversation in the fork
4. Type `/resume` to return to original session
5. Verify both conversation threads are preserved

### Ctrl+C Interrupt During Streaming

1. Start CLI, ask a question that generates a long response
2. Press Ctrl+C mid-stream
3. Verify graceful shutdown (no crash, partial output preserved)
4. Verify session is saved before exit

---

## Notes

- All tests use real API calls (not mocked); a valid OPENAGENT_API_KEY must be in the environment
- MCP tests use XCTSkip for graceful degradation when MCP servers are unavailable
- Session tests clean up created session files after completion
- The testMultiTurn_createCompileModify test creates temp files in /tmp with random suffixes for isolation
- Multi-turn tests have generous timeouts (60-90s) to account for real LLM response times
- Interactive scenarios (REPL permission prompts, /fork, /resume, Ctrl+C) are documented as manual procedures only

---

**Generated by BMad TEA Agent** - 2026-04-23
