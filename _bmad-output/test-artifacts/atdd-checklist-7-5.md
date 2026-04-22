---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-22'
workflowType: 'testarch-atdd'
inputDocuments:
  - _bmad-output/implementation-artifacts/7-5-session-fork.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - Sources/OpenAgentCLI/REPLLoop.swift
  - Tests/OpenAgentCLITests/REPLLoopTests.swift
  - Tests/OpenAgentCLITests/SessionListResumeTests.swift
  - .build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Stores/SessionStore.swift
---

# ATDD Checklist - Epic 7, Story 7.5: Session Fork

**Date:** 2026-04-22
**Author:** TEA Agent
**Primary Test Level:** Unit (Swift/XCTest)
**Stack:** Backend (Swift)
**TDD Phase:** RED (tests fail as expected -- feature not yet implemented)

---

## Story Summary

**As a** power user
**I want to** fork a conversation from the current point
**So that** I can explore alternative approaches without losing the original context.

## Acceptance Criteria

| AC# | Description | Test Coverage |
|-----|-------------|---------------|
| #1 | Given a REPL session with conversation history, when I enter `/fork`, then a new branched session is created from the current conversation state | testFork_success_displaysConfirmation, testFork_success_createsNewSession |
| #2 | Given the fork is complete, when I continue the conversation, then the new session has independent subsequent history | (covered by testFork_success -- agent is switched to new session) |
| #3 | Given the fork succeeds, when confirmation is displayed, then the new session's short ID and "Session forked" prompt are shown | testFork_success_displaysConfirmation |
| #4 | Given no session storage is available (SessionStore is nil), when I enter `/fork`, then the error message "No session storage available." is displayed | testFork_noSessionStore_showsError |
| #5 | Given no active session (sessionId is nil), when I enter `/fork`, then the error message "No active session to fork." is displayed | testFork_noActiveSession_showsError |
| #6 | Given the fork operation fails (e.g., disk write error), when SessionStore.fork() throws an error, then an error message is displayed and the original session is unaffected | testFork_forkThrows_showsError, testFork_forkReturnsNil_showsError |

---

## Generation Mode: AI Generation (Backend)

This is a Swift backend project. No browser recording needed. All tests are XCTest unit tests.

---

## Existing Test Coverage (Pre-Story 7.5)

The following session-related tests already exist from earlier stories:

| Test File | Test Method | AC Covered | Notes |
|-----------|-------------|------------|-------|
| SessionListResumeTests.swift | testSessionsCommand_emptyList_showsNoSessions | N/A | /sessions command |
| SessionListResumeTests.swift | testResumeCommand_validId_resumesSession | N/A | /resume command |
| SessionListResumeTests.swift | testResumeCommand_invalidId_showsNotFound | N/A | /resume error path |
| SessionListResumeTests.swift | testResumeCommand_noArgs_showsUsage | N/A | /resume missing args |
| SessionListResumeTests.swift | testSlashCommand_helpIncludesResumeCommand | N/A | /help listing |
| SessionListResumeTests.swift | testSlashCommand_helpIncludesSessionsCommand | N/A | /help listing |
| REPLLoopTests.swift | testREPLLoop_helpCommand_showsAvailableCommands | N/A | /help basic |

**Gap Analysis:** No /fork tests exist. The following gaps must be filled:
1. Successful fork with confirmation message (AC#1, #3)
2. SessionStore nil error (AC#4)
3. No active session error (AC#5)
4. Fork throws error (AC#6)
5. Fork returns nil (source not found) (AC#6)
6. /help output includes /fork (AC#1)

---

## Test Strategy

### Test Level: Unit

All tests are unit tests targeting `REPLLoop` directly via the existing `MockInputReader` + `MockTextOutputStream` pattern.

### Priority Assignment

| Priority | Test | Rationale |
|----------|------|-----------|
| P0 | testFork_success_displaysConfirmation | Core feature -- happy path must work |
| P0 | testFork_noSessionStore_showsError | Core feature -- error guard for nil store |
| P0 | testFork_noActiveSession_showsError | Core feature -- error guard for nil session |
| P1 | testFork_forkThrows_showsError | Error handling -- disk failure resilience |
| P1 | testFork_forkReturnsNil_showsError | Error handling -- source session not found |
| P1 | testHelp_includesForkCommand | Discoverability -- users need to know /fork exists |

---

## TDD Red Phase (Current)

All new tests are designed to **fail** until `/fork` is implemented in REPLLoop.swift.

### Expected Failure Modes

1. `testFork_success_displaysConfirmation` -- `/fork` case not in switch statement, falls to "Unknown command"
2. `testFork_noSessionStore_showsError` -- `/fork` case not handled, never checks SessionStore
3. `testFork_noActiveSession_showsError` -- `/fork` case not handled
4. `testFork_forkThrows_showsError` -- `/fork` case not handled
5. `testFork_forkReturnsNil_showsError` -- `/fork` case not handled
6. `testHelp_includesForkCommand` -- `/fork` not in help text

### Test Files

1. **SessionForkTests.swift** (new) -- 6 test methods
2. **REPLLoopTests.swift** (no changes) -- existing tests should still pass

---

## Acceptance Criteria Coverage Matrix

| AC# | Test Methods | Status |
|-----|-------------|--------|
| #1 | testFork_success_displaysConfirmation | RED (will fail until implemented) |
| #2 | testFork_success_displaysConfirmation (agent switched to new session) | RED |
| #3 | testFork_success_displaysConfirmation (short ID + "Session forked" message) | RED |
| #4 | testFork_noSessionStore_showsError | RED |
| #5 | testFork_noActiveSession_showsError | RED |
| #6 | testFork_forkThrows_showsError, testFork_forkReturnsNil_showsError | RED |

---

## Next Steps (Post-ATDD)

After the ATDD tests are verified:

1. Run `swift test --filter SessionForkTests` to verify all tests fail (RED phase)
2. Implement `/fork` in REPLLoop.swift following the Dev Notes in the story
3. Run tests again to verify GREEN phase
4. Run full regression suite: `swift test`
5. Commit passing tests + implementation

---

## Implementation Guidance

### Source file to modify:

1. **`Sources/OpenAgentCLI/REPLLoop.swift`**
   - Add `"/fork"` case in `handleSlashCommand` switch (line ~180)
   - Add `handleFork()` method following `/resume` pattern (lines 364-452)
   - Add `/fork` to `printHelp()` output (line ~209)

### Test file created:

1. **`Tests/OpenAgentCLITests/SessionForkTests.swift`** -- 6 new test methods

---

## Summary Statistics

- **Total new tests:** 6
- **SessionForkTests:** 6
- **Acceptance criteria covered:** 6/6 (100%)
- **TDD Phase:** RED (all tests will fail until feature implemented)
