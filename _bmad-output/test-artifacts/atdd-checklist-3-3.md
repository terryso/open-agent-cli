---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: 2026-04-20
storyId: 3-3
inputDocuments:
  - _bmad-output/implementation-artifacts/3-3-auto-restore-last-session-on-startup.md
  - Sources/OpenAgentCLI/AgentFactory.swift
  - Sources/OpenAgentCLI/CLI.swift
  - Sources/OpenAgentCLI/ArgumentParser.swift
  - Sources/OpenAgentCLI/REPLLoop.swift
  - Tests/OpenAgentCLITests/AgentFactoryTests.swift
  - Tests/OpenAgentCLITests/SessionListResumeTests.swift
  - Tests/OpenAgentCLITests/REPLLoopTests.swift
tddPhase: RED
detectedStack: backend
testFramework: XCTest
---

# ATDD Checklist - Story 3.3: Auto-Restore Last Session on Startup

## Story Summary

**As a user**, I want the CLI to automatically continue my last conversation when it starts, so I don't have to manually resume each time.

## Preflight Verification

| Prerequisite | Status |
|---|---|
| Story approved with clear acceptance criteria | PASS |
| Test framework configured (XCTest) | PASS |
| Development environment available | PASS |
| Stack detected: backend (Swift CLI) | PASS |
| SDK AgentOptions.continueRecentSession API available | PASS |
| --session and --no-restore args already implemented | PASS |
| AgentFactory.createAgent returns (Agent, SessionStore) tuple | PASS |

## Generation Mode

| Dimension | Value |
|---|---|
| Detected Stack | backend |
| Generation Mode | AI Generation (standard scenarios) |
| Test Framework | XCTest |
| TDD Phase | RED (failing tests) |

## Test Strategy

### Acceptance Criteria to Test Mapping

| AC | Description | Test Level | Priority |
|---|---|---|---|
| AC#1 | Default REPL mode auto-loads last session | Unit | P0 |
| AC#2 | --session <id> loads specified session, not auto-restore | Unit | P0 |
| AC#3 | --no-restore forces fresh session | Unit | P0 |
| AC#4 | Corrupt session file -> warning + fresh session | Integration | P1 |

### Test Priority Matrix

| Priority | Risk | Business Impact | Test Count |
|---|---|---|---|
| P0 | High - Core feature (session management) | High - User-facing | 10 |
| P1 | Medium - Edge cases, regression | Medium - Robustness | 8 |
| Total | | | 18 |

## Test File

**File:** `Tests/OpenAgentCLITests/AutoRestoreTests.swift`

### Test Methods and AC Coverage

| # | Test Method | AC | Priority | Description |
|---|---|---|---|---|
| 1 | `testCreateAgent_default_setsContinueRecentSession` | #1 | P0 | Default args (no --session, no --no-restore) creates Agent for auto-restore |
| 2 | `testCreateAgent_default_sessionIdIsNil` | #1 | P0 | resolveSessionId returns nil in auto-restore mode (FAILS until implemented) |
| 3 | `testCreateAgent_withSession_setsExplicitSessionId` | #2 | P0 | --session <id> returns the explicit ID from resolveSessionId |
| 4 | `testCreateAgent_withSession_continueRecentSessionIsFalse` | #2 | P0 | --session does not trigger auto-restore |
| 5 | `testCreateAgent_noRestore_generatesNewSessionId` | #3 | P0 | --no-restore generates a new UUID session ID |
| 6 | `testCreateAgent_noRestore_continueRecentSessionIsFalse` | #3 | P0 | --no-restore does not trigger auto-restore |
| 7 | `testCreateAgent_noRestore_withSession_usesSpecifiedId` | #2,#3 | P0 | --no-restore + --session uses the specified ID |
| 8 | `testRestoreHint_notDisplayed_withNoRestore` | #3 | P0 | --no-restore suppresses restore hint output |
| 9 | `testRestoreHint_notDisplayed_withExplicitSession` | #2 | P0 | --session suppresses auto-restore hint |
| 10 | `testFullPipeline_noArgs_autoRestoreActive` | #1 | P0 | Full CLI pipeline: default args triggers auto-restore |
| 11 | `testRestoreHint_displayed_inReplMode` | #1 | P1 | REPL mode with auto-restore shows hint (if sessions exist) |
| 12 | `testRestoreHint_notDisplayed_inSingleShotMode` | #1 | P1 | Single-shot mode does not trigger auto-restore |
| 13 | `testRestoreHint_notDisplayed_inSkillMode` | #1 | P1 | --skill mode does not trigger auto-restore |
| 14 | `testRestoreFailure_corruptSession_showsWarning` | #4 | P1 | Corrupt session file triggers graceful degradation |
| 15 | `testRestoreFailure_noSessions_silentNewSession` | #4 | P1 | No sessions to restore is silent (no error) |
| 16 | `testCreateAgent_autoRestore_modelStillCorrect` | - | P1 | Regression: model passthrough |
| 17 | `testCreateAgent_autoRestore_maxTurnsStillCorrect` | - | P1 | Regression: maxTurns passthrough |
| 18 | `testCreateAgent_autoRestore_systemPromptStillCorrect` | - | P1 | Regression: systemPrompt passthrough |
| 19 | `testCreateAgent_autoRestore_returnsSessionStore` | - | P1 | Regression: tuple return preserved |
| 20 | `testFullPipeline_noRestore_generatesNewId` | #3 | P0 | Full pipeline: --no-restore generates UUID |
| 21 | `testFullPipeline_session_usesExplicitId` | #2 | P0 | Full pipeline: --session uses explicit ID |

**Total: 21 test methods (10 P0 + 11 P1)**

## TDD Red Phase Status

### Expected Failing Tests

| Test | Reason | Fix Required |
|---|---|---|
| `testCreateAgent_default_sessionIdIsNil` | `resolveSessionId` currently returns `UUID().uuidString` instead of `nil` when noRestore==false && sessionId==nil | Modify `AgentFactory.resolveSessionId(from:)` to return nil in auto-restore case |
| `testFullPipeline_noArgs_autoRestoreActive` | Same as above - resolveSessionId returns UUID instead of nil | Same fix |

### Tests That Pass Immediately (Existing Behavior)

These tests verify behavior that already works and will continue to work after implementation:

- `testCreateAgent_withSession_setsExplicitSessionId` -- resolveSessionId already returns args.sessionId
- `testCreateAgent_noRestore_generatesNewSessionId` -- resolveSessionId already generates UUID
- `testCreateAgent_noRestore_withSession_usesSpecifiedId` -- args.sessionId takes precedence
- All regression tests (model, maxTurns, systemPrompt, tuple return)

### Source Changes Required (Green Phase)

| Change | Source File | Task |
|---|---|---|
| Modify `resolveSessionId` to return nil when auto-restore active | AgentFactory.swift | Task 1 |
| Add `continueRecentSession: true` to AgentOptions when auto-restore | AgentFactory.swift | Task 1 |
| Pass `sessionId: nil` instead of generated UUID when auto-restore | AgentFactory.swift | Task 1 |
| Display restore hint in CLI.swift REPL path | CLI.swift | Task 2 |
| Handle restore failure in REPLLoop error path | REPLLoop.swift | Task 3 |

### Implementation Logic (from Story)

```
| Scenario              | --session | --no-restore | sessionId | continueRecentSession |
|-----------------------|-----------|-------------|-----------|----------------------|
| Auto-restore recent   | none      | false       | nil       | true                 |
| Resume specific       | <id>      | any         | <id>      | false                |
| Force new session     | none      | true        | UUID()    | false                |
```

Key implementation in AgentFactory.createAgent:

```swift
let shouldAutoRestore = !args.noRestore && args.sessionId == nil
let sessionId: String? = shouldAutoRestore ? nil : resolveSessionId(from: args)
// Then pass continueRecentSession: shouldAutoRestore to AgentOptions
```

### Regression Verification

| Check | Status |
|---|---|
| All 285 existing tests pass (pre-change baseline) | PENDING (green phase) |
| No changes to ArgumentParser.swift | PASS (args already exist) |
| No changes to OutputRenderer.swift | PASS |
| No new SessionManager.swift | PASS (uses SDK SessionStore) |

## Key Risks and Assumptions

| Risk | Mitigation |
|---|---|
| resolveSessionId returning nil may break callers expecting non-nil | Audit all callers; only CLI.swift REPL path uses auto-restore |
| AgentOptions does not expose continueRecentSession publicly | Verify SDK public API; story notes it is public |
| Existing tests using resolveSessionId may need update | Only 2 tests call resolveSessionId directly |
| 285 existing tests must still pass after change | Run full suite after implementation |
| Restore hint placement in CLI.swift vs REPLLoop | Story recommends CLI.swift (simpler, non-invasive) |

## Next Steps

1. **Green Phase**: Implement Tasks 1-3 per story specification
2. **Fix resolveSessionId**: Return nil when shouldAutoRestore is true
3. **Add continueRecentSession**: Set to true in AgentOptions when auto-restore active
4. **Add restore hint**: Display in CLI.swift REPL branch
5. **Verify**: All 21 new tests pass + all 285 existing tests pass (306 total)
6. **Refactor**: Clean up any duplication between new and existing test helpers
