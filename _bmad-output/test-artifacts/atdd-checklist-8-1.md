---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate']
lastStep: 'step-04c-aggregate'
lastSaved: '2026-04-22'
storyId: '8-1'
storyTitle: 'Technical Debt Cleanup'
detectedStack: 'backend'
testFramework: 'XCTest'
generationMode: 'AI Generation (backend project)'
---

# ATDD Checklist: Story 8-1 Technical Debt Cleanup

## Preflight Summary

- **Stack:** Backend (Swift CLI, XCTest)
- **Framework:** XCTest (no third-party test libs)
- **Test Dir:** `Tests/OpenAgentCLITests/`
- **Source Dir:** `Sources/OpenAgentCLI/`
- **Existing Tests:** ~28 test files, ~600 tests

## Input Documents

- `_bmad-output/implementation-artifacts/8-1-technical-debt-cleanup.md` (Story)
- `Sources/OpenAgentCLI/CLI.swift` (AC#1, #3, #4, #5)
- `Sources/OpenAgentCLI/REPLLoop.swift` (AC#2, #6, #7)
- `Sources/OpenAgentCLI/PermissionHandler.swift` (AC#5)
- `Sources/OpenAgentCLI/ConfigLoader.swift` (AC#1)
- `Sources/OpenAgentCLI/AgentFactory.swift` (AC#1)
- `Sources/OpenAgentCLI/ANSI.swift` (AC#1)
- `Sources/OpenAgentCLI/ArgumentParser.swift` (AC#4)
- `Tests/OpenAgentCLITests/SessionForkTests.swift` (existing patterns)
- `Tests/OpenAgentCLITests/StdinInputTests.swift` (existing patterns)
- `Tests/OpenAgentCLITests/PermissionHandlerTests.swift` (existing patterns)

## Test Strategy

### Test Levels

All tests are **unit tests** (backend Swift project):
- Unit: pure functions, business logic, edge cases
- Integration: protocol-based mock interactions (REPLLoop with MockInputReader/MockTextOutputStream)

### Priority Matrix

| AC | Priority | Test Level | File |
|----|----------|------------|------|
| #1 Force-unwrap elimination | P0 | Unit | StdioHelpersTests.swift |
| #2 ParsedArgs struct copy | P0 | Integration | SessionForkTests.swift (extend) |
| #3 isatty stdin check | P0 | Unit | StdinInputTests.swift (extend) |
| #4 --stdin + --skill exclusion | P0 | Unit | StdinInputTests.swift (extend) |
| #5 Non-interactive permission fix | P1 | Unit | PermissionHandlerTests.swift (extend) |
| #6 CostTracker Sendable | P2 | Unit | CostTrackerTests.swift |
| #7 Orphan fork cleanup | P1 | Integration | SessionForkTests.swift (extend) |

## Acceptance Criteria to Test Mapping

### AC#1: Eliminate all force-unwrap `data(using: .utf8)!`
- **P0** `testWriteToStderr_helperExists` -- ANSI.writeToStderr() or StdioHelpers.writeToStderr() exists
- **P0** `testWriteToStderr_safeFallback_nilUTF8` -- Helper uses `?? Data()` fallback
- **P0** `testCLI_noForceUnwrap_dataUsingUtf8` -- Zero `data(using: .utf8)!` in CLI.swift
- **P0** `testConfigLoader_noForceUnwrap_dataUsingUtf8` -- Zero in ConfigLoader.swift
- **P0** `testAgentFactory_noForceUnwrap_dataUsingUtf8` -- Zero in AgentFactory.swift

### AC#2: Fix handleFork/handleResume ParsedArgs field omission
- **P0** `testFork_preservesExplicitlySetFields` -- /fork copies all explicitlySet fields
- **P0** `testFork_preservesCustomTools` -- /fork copies customTools array
- **P0** `testResume_preservesExplicitlySetFields` -- /resume copies all explicitlySet fields
- **P0** `testResume_preservesCustomTools` -- /resume copies customTools array
- **P1** `testFork_preservesBaseURL_whenExplicitlySet` -- Model+baseURL explicitly set survive fork
- **P1** `testResume_preservesBaseURL_whenExplicitlySet` -- Model+baseURL explicitly set survive resume

### AC#3: Fix stdin infinite blocking on terminal
- **P0** `testReadStdin_terminalInput_returnsError` -- isatty check returns error message
- **P0** `testReadStdin_isattyCheck_errorMessage` -- Error mentions piped input requirement
- **P1** `testReadStdin_pipeInput_succeeds` -- Piped stdin still works (regression)

### AC#4: Fix --stdin + --skill combination
- **P0** `testStdinAndSkill_bothSet_returnsError` -- ArgumentParser validates mutual exclusion
- **P0** `testStdinAndSkill_errorMessage` -- Error message is clear
- **P1** `testStdinWithoutSkill_noError` -- --stdin alone is fine
- **P1** `testSkillWithoutStdin_noError` -- --skill alone is fine

### AC#5: Fix single-shot + default/plan mode denying write tools
- **P0** `testNonInteractive_defaultMode_autoApprovesWriteTool` -- default non-interactive allows writes
- **P0** `testNonInteractive_planMode_autoApprovesAllTools` -- plan non-interactive allows all
- **P1** `testNonInteractive_defaultMode_showsWarning` -- Warning message about auto-approval
- **P1** `testNonInteractive_planMode_showsWarning` -- Warning for plan mode auto-approval

### AC#6: Add Sendable conformance to CostTracker
- **P2** `testCostTracker_conformsToSendable` -- Compiles with Sendable requirement
- **P2** `testCostTracker_resetWorks` -- Functional test (regression guard)

### AC#7: Clean up orphaned fork sessions
- **P0** `testFork_agentCreationFails_cleansUpOrphanedSession` -- Orphan deleted on agent failure
- **P1** `testFork_agentCreationFails_showsUserFriendlyError` -- Error message is clear
- **P1** `testFork_agentCreationFails_originalSessionUnaffected` -- Original session intact

## TDD Red Phase Verification

All tests are designed to **FAIL** until the corresponding implementation changes are made:

- AC#1 tests: `ANSI.writeToStderr` does not exist yet, force-unwrap count > 0
- AC#2 tests: Fork/resume use manual field-by-field copy, not struct copy
- AC#3 tests: `isatty()` check does not exist in readStdin()
- AC#4 tests: No validation for --stdin + --skill mutual exclusion
- AC#5 tests: Non-interactive mode currently denies write tools
- AC#6 tests: `CostTracker` does not conform to `Sendable`
- AC#7 tests: No orphan cleanup in handleFork()

## Test Files Created

1. `Tests/OpenAgentCLITests/TechnicalDebtAC1Tests.swift` -- AC#1 force-unwrap elimination
2. `Tests/OpenAgentCLITests/TechnicalDebtAC2Tests.swift` -- AC#2 ParsedArgs struct copy (fork/resume)
3. `Tests/OpenAgentCLITests/TechnicalDebtAC3Tests.swift` -- AC#3 isatty stdin check
4. `Tests/OpenAgentCLITests/TechnicalDebtAC4Tests.swift` -- AC#4 --stdin + --skill exclusion
5. `Tests/OpenAgentCLITests/TechnicalDebtAC5Tests.swift` -- AC#5 non-interactive permission fix
6. `Tests/OpenAgentCLITests/TechnicalDebtAC6Tests.swift` -- AC#6 CostTracker Sendable
7. `Tests/OpenAgentCLITests/TechnicalDebtAC7Tests.swift` -- AC#7 orphan fork cleanup

## Summary Statistics

- **Total test cases:** 28
- **P0 (must pass):** 16
- **P1 (should pass):** 9
- **P2 (nice to have):** 3
- **AC coverage:** 7/7 (100%)
- **Test level:** Unit + Integration (protocol-based mocking)
