---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: 2026-04-20
storyId: 3-1
inputDocuments:
  - _bmad-output/implementation-artifacts/3-1-auto-save-sessions-on-exit.md
  - Sources/OpenAgentCLI/AgentFactory.swift
  - Sources/OpenAgentCLI/CLI.swift
  - Sources/OpenAgentCLI/ArgumentParser.swift
  - Tests/OpenAgentCLITests/AgentFactoryTests.swift
  - Tests/OpenAgentCLITests/CLISingleShotTests.swift
tddPhase: RED
detectedStack: backend
testFramework: XCTest
---

# ATDD Checklist - Story 3.1: Auto-Save Sessions on Exit

## Story Summary

**As a user**, I want conversations to be automatically saved when I exit the CLI, so I can resume progress later.

## Preflight Verification

| Prerequisite | Status |
|---|---|
| Story approved with clear acceptance criteria | PASS |
| Test framework configured (XCTest) | PASS |
| Development environment available | PASS |
| Existing 248 tests passing | PASS |
| Stack detected: backend (Swift CLI) | PASS |
| SDK SessionStore API available | PASS |
| SDK AgentOptions supports sessionStore/sessionId | PASS |

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
| AC#1 | Exit CLI saves session via SDK SessionStore | Unit + Integration | P0 |
| AC#2 | Save failure shows warning, CLI still exits normally | Unit | P0 |
| AC#3 | --no-restore does not disable auto-save | Unit | P0 |

### Test Priority Matrix

| Priority | Risk | Business Impact | Test Count |
|---|---|---|---|
| P0 | High - Core feature (data loss prevention) | High - User-facing | 18 |
| P1 | Medium - Regression | Medium - Existing features | 5 |
| Total | | | 23 |

## Test File

**File:** `Tests/OpenAgentCLITests/SessionSaveTests.swift`

### Test Methods and AC Coverage

| # | Test Method | AC | Priority | Description |
|---|---|---|---|---|
| 1 | `testCreateAgent_injectsSessionStore_intoAgentOptions` | #1 | P0 | Agent created with SessionStore injected |
| 2 | `testCreateAgent_generatesUUID_whenNoSessionId` | #1 | P0 | No --session -> unique UUID per agent |
| 3 | `testResolveSessionId_usesProvidedSessionId` | #1 | P0 | --session <id> -> use provided ID |
| 4 | `testResolveSessionId_generatesUUID_whenNil` | #1 | P0 | nil sessionId -> UUID format output |
| 5 | `testCreateAgent_sessionStoreEnabled_agentCreated` | #1 | P0 | Agent creation succeeds with session config |
| 6 | `testCreateAgent_sessionSavedToDisk_afterClose` | #1 | P0 | agent.close() triggers disk persistence |
| 7 | `testCLIPromptMode_callsAgentClose` | #1 | P0 | Single-shot exit path calls close() |
| 8 | `testAgentClose_saveFailure_doesNotCrash` | #2 | P0 | close() failure handled gracefully |
| 9 | `testCreateAgent_noRestoreFlag_sessionStillActive` | #3 | P0 | --no-restore does not affect auto-save |
| 10 | `testCreateAgent_noRestoreFalse_sessionActive` | #3 | P0 | Default (no flag) auto-save active |
| 11 | `testResolveSessionId_noRestore_doesNotAffectSessionId` | #3 | P0 | --no-restore does not affect sessionId |
| 12 | `testCreateAgent_persistSession_alwaysTrue_withRestore` | #3 | P0 | persistSession true with both --no-restore states |
| 13 | `testArgumentParser_sessionFlag_parsesCorrectly` | #1 | P1 | ArgumentParser handles --session |
| 14 | `testArgumentParser_noSessionFlag_sessionIdIsNil` | #1 | P1 | No --session -> sessionId nil in ParsedArgs |
| 15 | `testArgumentParser_noRestoreFlag_parsesCorrectly` | #3 | P1 | ArgumentParser handles --no-restore |
| 16 | `testArgumentParser_noRestoreAndSession_bothParsed` | #3 | P1 | Both flags parsed together |
| 17 | `testCreateAgent_withSessionConfig_modelStillCorrect` | - | P1 | Regression: model passthrough |
| 18 | `testCreateAgent_withSessionConfig_maxTurnsStillCorrect` | - | P1 | Regression: maxTurns passthrough |
| 19 | `testCreateAgent_withSessionConfig_systemPromptStillCorrect` | - | P1 | Regression: systemPrompt passthrough |
| 20 | `testComputeToolPool_withSessionConfig_returnsCoreTools` | - | P1 | Regression: tool pool unchanged |
| 21 | `testFullPipeline_sessionArg_agentCreated` | #1 | P0 | Full pipeline: parser -> factory with --session |
| 22 | `testFullPipeline_noSessionArg_agentCreated` | #1 | P0 | Full pipeline: parser -> factory without --session |
| 23 | `testFullPipeline_noRestoreArg_agentCreated` | #3 | P0 | Full pipeline: parser -> factory with --no-restore |

## TDD Red Phase Status

### APIs Not Yet Implemented (Expected Compilation Errors)

| Missing API | Source File | Task | Error Count |
|---|---|---|---|
| `AgentFactory.resolveSessionId(from:)` | AgentFactory.swift | Task 1 | 6 |

### Error Categories

1. **`type 'AgentFactory' has no member 'resolveSessionId'`** -- New static method needed on AgentFactory. Used in 6 test methods.

### Runtime Behavior Changes Needed

| Change | Source File | Task |
|---|---|---|
| Create SessionStore() instance in createAgent | AgentFactory.swift | Task 1 |
| Generate/resolve sessionId in createAgent | AgentFactory.swift | Task 1 |
| Pass sessionStore, sessionId, persistSession to AgentOptions | AgentFactory.swift | Task 1 |
| Change `try? await agent.close()` to explicit error handling | CLI.swift | Task 3 |

### Regression Verification

| Check | Status |
|---|---|
| All 248 existing tests pass (pre-change baseline) | PASS |
| No changes to existing source files | PASS |
| No changes to existing test files | PASS |
| Build succeeds (source only, no tests) | PASS |

## Implementation Requirements (Green Phase Guide)

### Task 1: AgentFactory Session Configuration

Add to `AgentFactory.swift`:

```swift
/// Resolve the session ID: use --session argument or generate a new UUID.
static func resolveSessionId(from args: ParsedArgs) -> String {
    return args.sessionId ?? UUID().uuidString
}
```

Update `createAgent(from:)` to create SessionStore and inject into AgentOptions:

```swift
// Before assembling AgentOptions:
let sessionStore = SessionStore()
let sessionId = resolveSessionId(from: args)

let options = AgentOptions(
    // ... existing parameters ...
    sessionStore: sessionStore,
    sessionId: sessionId,
    persistSession: true
)
```

### Task 2: Verify Exit Paths (Already Implemented)

All three exit paths in CLI.swift already call `try? await agent.close()`:
- REPL mode: line 113
- Single-shot mode: line 101
- --skill mode: line 74

SDK's agent.close() triggers session save when sessionStore is configured.

### Task 3: Graceful Save Failure Handling

Change `try? await agent.close()` to explicit error handling in CLI.swift:

```swift
do {
    try await agent.close()
} catch {
    let warning = "Warning: Failed to save session: \(error.localizedDescription)"
    FileHandle.standardError.write((warning + "\n").data(using: .utf8)!)
}
```

### Task 4-6: Test Fixture Updates

Existing test fixtures that construct `ParsedArgs` with `sessionId: nil` should continue to work since `resolveSessionId` generates a UUID for nil values. No fixture changes expected.

## Key Risks and Assumptions

| Risk | Mitigation |
|---|---|
| SDK Agent doesn't expose sessionStore/sessionId as public properties | Tests verify behavior (close() succeeds, file on disk) rather than internal state |
| SessionStore writes to ~/.open-agent-sdk/sessions/ by default | E2E test uses defer cleanup; integration tests may need custom sessionsDir |
| Existing test fixtures use sessionId: nil | resolveSessionId handles nil gracefully by generating UUID |
| close() may not throw in current SDK version | Tests handle both throwing and non-throwing cases |
| Regex literal not available in Swift < 5.7 | UUID validation uses character counting instead |

## Next Steps

1. **Green Phase**: Implement Tasks 1-3 per story specification
2. **Verify**: All 23 new tests pass + all 248 existing tests pass (271 total)
3. **Refactor**: Clean up any duplication between new and existing test helpers
