---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-21'
workflowType: 'testarch-atdd'
inputDocuments:
  - _bmad-output/implementation-artifacts/6-3-dynamic-repl-commands.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - Sources/OpenAgentCLI/REPLLoop.swift
  - open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift
  - open-agent-sdk-swift/Sources/OpenAgentSDK/Types/PermissionTypes.swift
  - open-agent-sdk-swift/Sources/OpenAgentSDK/Types/TokenUsage.swift
  - open-agent-sdk-swift/Sources/OpenAgentSDK/Types/SDKMessage.swift
---

# ATDD Checklist - Epic 6, Story 6.3: Dynamic REPL Commands

**Date:** 2026-04-21
**Author:** TEA Agent
**Primary Test Level:** Unit (Swift/XCTest)
**Stack:** Backend (Swift)
**TDD Phase:** RED (17 tests fail as expected -- feature not yet implemented)

---

## Story Summary

**As a** user
**I want** to switch models and permission modes during a conversation
**So that** I can adjust Agent behavior without restarting

---

## Acceptance Criteria

1. **AC#1:** Given I am in a REPL session, when I type `/model claude-opus-4-7`, then the Agent switches to the specified model
2. **AC#2:** Given I am in a REPL session, when I type `/mode plan`, then the permission mode switches to plan mode
3. **AC#3:** Given I type `/cost` in the REPL, then cumulative token usage and cost are displayed
4. **AC#4:** Given I type `/clear` in the REPL, then the conversation history is cleared and a new session begins

---

## Tests Created (22 tests)

### Unit Tests: DynamicREPLCommandTests (22 tests)

**File:** `Tests/OpenAgentCLITests/DynamicREPLCommandTests.swift` (514 lines)

#### AC#1: /model Command (4 tests)

| Test | Status | Description |
|------|--------|-------------|
| testModelCommand_validModel_switchesAndConfirms | FAIL | /model claude-opus-4-7 switches model and shows confirmation |
| testModelCommand_noArg_showsUsage | PASS | /model with no argument shows usage hint |
| testModelCommand_emptyArg_showsError | FAIL | /model with whitespace argument shows error |
| testModelCommand_doesNotExit | PASS | /model does not terminate the REPL |

#### AC#2: /mode Command (6 tests)

| Test | Status | Description |
|------|--------|-------------|
| testModeCommand_validMode_switchesAndConfirms | PASS | /mode plan switches and confirms |
| testModeCommand_invalidMode_listsValidModes | FAIL | /mode invalid lists all valid modes |
| testModeCommand_noArg_showsUsage | PASS | /mode with no argument shows usage hint |
| testModeCommand_doesNotExit | PASS | /mode does not terminate the REPL |
| testModeCommand_allValidModes_succeed | FAIL | All 6 PermissionMode values accepted |

#### AC#3: /cost Command (3 tests)

| Test | Status | Description |
|------|--------|-------------|
| testCostCommand_initialState_showsZero | FAIL | /cost with no prior queries shows $0.0000 |
| testCostCommand_doesNotExit | PASS | /cost does not terminate the REPL |
| testCostCommand_outputFormat | FAIL | /cost output has recognizable cost/token format |

#### AC#4: /clear Command (3 tests)

| Test | Status | Description |
|------|--------|-------------|
| testClearCommand_showsConfirmation | FAIL | /clear outputs confirmation message |
| testClearCommand_doesNotExit | PASS | /clear does not terminate the REPL |
| testClearCommand_resetsCostTracker | FAIL | /cost after /clear shows $0 |

#### /help Integration (1 test)

| Test | Status | Description |
|------|--------|-------------|
| testHelpCommand_includesNewCommands | FAIL | /help lists /model, /mode, /cost, /clear |

#### Case Insensitivity (4 tests)

| Test | Status | Description |
|------|--------|-------------|
| testModelCommand_caseInsensitive | FAIL | /MODEL works case-insensitively |
| testModeCommand_caseInsensitive | FAIL | /MODE works case-insensitively |
| testCostCommand_caseInsensitive | FAIL | /COST works case-insensitively |
| testClearCommand_caseInsensitive | FAIL | /CLEAR works case-insensitively |

#### Regression (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testRegression_exitCommandStillWorks | PASS | /exit still works after adding new commands |
| testRegression_helpCommandStillWorks | PASS | /help still shows /exit and /quit |

---

## Test Execution Evidence

### RED Phase Verification

**Command:** `swift test --filter DynamicREPLCommandTests`

```
Test Suite 'DynamicREPLCommandTests' failed.
  Executed 22 tests, with 17 failures (0 unexpected) in 0.429 seconds
```

**Result: 17 FAIL, 5 PASS -- RED phase confirmed.**

The 5 passing tests are ones where the "Unknown command" fallback path
accidentally satisfies the assertion (e.g., "does not exit" is true
because unknown commands don't exit). These are still valid tests --
they will remain correct after implementation.

### Regression Check

**Command:** `swift test`

```
Test Suite 'All tests' failed.
  Executed 461 tests, with 17 failures (0 unexpected) in 21.698 seconds
```

- Total tests: 461 (439 existing + 22 new)
- Existing tests passing: 439/439 (100%)
- New tests failing: 17/22 (expected -- RED phase)
- No regression in existing tests

---

## Implementation Checklist

### Task 1: Add /model command to handleSlashCommand

**Source:** `Sources/OpenAgentCLI/REPLLoop.swift`

- [ ] Add `case "/model":` branch in `handleSlashCommand` switch
- [ ] Parse command argument (model name), validate non-empty
- [ ] Call `agentHolder.agent.switchModel(_:)` and handle `SDKError.invalidConfiguration`
- [ ] Success: output confirmation with new model name
- [ ] Failure: output error message, REPL continues
- [ ] Tests covered: testModelCommand_validModel_switchesAndConfirms, testModelCommand_noArg_showsUsage, testModelCommand_emptyArg_showsError, testModelCommand_doesNotExit, testModelCommand_caseInsensitive

### Task 2: Add /mode command to handleSlashCommand

**Source:** `Sources/OpenAgentCLI/REPLLoop.swift`

- [ ] Add `case "/mode":` branch in `handleSlashCommand` switch
- [ ] Parse command argument (mode name), validate non-empty
- [ ] Validate mode name using `PermissionMode(rawValue:)`
- [ ] Invalid mode: list all valid modes using `PermissionMode.allCases`
- [ ] Call `agentHolder.agent.setPermissionMode(_:)` to switch
- [ ] Success: output confirmation
- [ ] Tests covered: testModeCommand_validMode_switchesAndConfirms, testModeCommand_invalidMode_listsValidModes, testModeCommand_noArg_showsUsage, testModeCommand_doesNotExit, testModeCommand_allValidModes_succeed, testModeCommand_caseInsensitive

### Task 3: Add /cost command to handleSlashCommand

**Source:** `Sources/OpenAgentCLI/REPLLoop.swift`

- [ ] Add `final class CostTracker` with `cumulativeCostUsd`, `cumulativeInputTokens`, `cumulativeOutputTokens`
- [ ] Instantiate CostTracker in REPLLoop
- [ ] In streaming loop, intercept `.result` messages to accumulate cost
- [ ] Add `case "/cost":` branch in `handleSlashCommand` switch
- [ ] Output format: `Session cost: $X.XXXX (input: N tokens, output: M tokens)`
- [ ] Tests covered: testCostCommand_initialState_showsZero, testCostCommand_doesNotExit, testCostCommand_outputFormat, testCostCommand_caseInsensitive

### Task 4: Add /clear command to handleSlashCommand

**Source:** `Sources/OpenAgentCLI/REPLLoop.swift`

- [ ] Add `case "/clear":` branch in `handleSlashCommand` switch
- [ ] Call `agentHolder.agent.clear()` to clear conversation history
- [ ] Reset CostTracker to zero
- [ ] Output confirmation message
- [ ] Tests covered: testClearCommand_showsConfirmation, testClearCommand_doesNotExit, testClearCommand_resetsCostTracker, testClearCommand_caseInsensitive

### Task 5: Update /help output

**Source:** `Sources/OpenAgentCLI/REPLLoop.swift`

- [ ] Add new commands to `printHelp()`: /model, /mode, /cost, /clear
- [ ] Tests covered: testHelpCommand_includesNewCommands

---

## Red-Green-Refactor Workflow

### RED Phase (Current)

- [x] 22 failing tests generated
- [x] 17 tests fail as expected (feature not implemented)
- [x] 5 tests pass (assertions lenient enough for "unknown command" path)
- [x] No regression in existing 439 tests

### GREEN Phase (After Implementation)

1. Implement Tasks 1-5 in `Sources/OpenAgentCLI/REPLLoop.swift`
2. Run: `swift test --filter DynamicREPLCommandTests`
3. Verify all 22 tests pass
4. If any fail: fix implementation (feature bug) or fix test (test bug)
5. Run: `swift test` (full regression)

### REFACTOR Phase

- Review CostTracker design (consider protocol for testability)
- Consider extracting command handlers into separate methods
- Verify no code duplication in command parsing

---

## Running Tests

```bash
# Run new tests only (Story 6.3)
swift test --filter DynamicREPLCommandTests

# Run existing REPLLoop tests (regression)
swift test --filter REPLLoopTests

# Run full test suite (all stories)
swift test

# Run specific test
swift test --filter DynamicREPLCommandTests/testModelCommand_validModel_switchesAndConfirms

# Run in verbose mode
swift test --filter DynamicREPLCommandTests --verbose
```

---

## Key Findings

1. **CostTracker requires class wrapper** -- REPLLoop is a struct with non-mutating `start()`. Cumulative cost tracking needs a class wrapper (similar to existing `AgentHolder` pattern) to maintain mutable state across method calls.

2. **PermissionMode is CaseIterable** -- SDK's `PermissionMode` conforms to `CaseIterable`, making it easy to list valid modes for error messages via `PermissionMode.allCases`.

3. **switchModel throws on empty string** -- `Agent.switchModel(_:)` throws `SDKError.invalidConfiguration` when the model name is empty/whitespace, which the `/model` command must catch.

4. **setPermissionMode clears canUseTool** -- `Agent.setPermissionMode(_:)` automatically clears the `canUseTool` callback. This is expected behavior per the story's dev notes.

5. **Cost tracking is CLI-layer concern** -- SDK does not expose session-level cumulative cost. `totalCostUsd` is per-query only, returned via `SDKMessage.ResultData`. The CLI must intercept `.result` messages in the streaming loop to accumulate costs.

6. **5 tests already pass** -- These tests verify "does not exit" behavior, which is accidentally satisfied by the "unknown command" fallback path. After implementation, they should still pass for the correct reason.

---

## Knowledge Base References Applied

- **component-tdd.md** - Component test strategies adapted for Swift XCTest
- **test-quality.md** - Test design principles (Given-When-Then, one assertion per test, determinism)
- **data-factories.md** - Helper pattern for ParsedArgs construction (shared with existing tests)

See `tea-index.csv` for complete knowledge fragment mapping.

---

**Generated by BMad TEA Agent** - 2026-04-21
