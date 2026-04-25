---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate']
lastStep: 'step-04c-aggregate'
lastSaved: '2026-04-25'
story_id: '10-1'
inputDocuments:
  - _bmad-output/implementation-artifacts/10-1-turn-labels-and-visual-separation.md
  - Sources/OpenAgentCLI/OutputRenderer.swift
  - Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift
  - Sources/OpenAgentCLI/ANSI.swift
  - Tests/OpenAgentCLITests/OutputRendererTests.swift
  - Tests/OpenAgentCLITests/ThinkingAndQuietModeTests.swift
---

# ATDD Checklist: Story 10-1 Turn Labels and Visual Separation

## Test Strategy

- **Stack:** Backend (Swift + XCTest)
- **Mode:** AI Generation (sequential, backend project)
- **Levels:** Unit only (no E2E needed -- terminal output rendering layer)

## Acceptance Criteria → Test Mapping

| AC | Test | Level | Priority | Status |
|----|------|-------|----------|--------|
| #1 | `testPartialMessage_firstChunk_outputsBlueBulletPrefix` | Unit | P0 | FAIL (red) |
| #1 | `testPartialMessage_subsequentChunks_noRepeatBulletPrefix` | Unit | P0 | PASS (verifies no repeat yet) |
| #1 | `testPartialMessage_thinkingContent_noBulletPrefix` | Unit | P0 | PASS (thinking unchanged) |
| #1 | `testPartialMessage_newTurnAfterResult_outputsBulletPrefix` | Unit | P0 | FAIL (red) |
| #2 | `testResult_success_hasBlankLineBeforeDivider` | Unit | P0 | PASS (existing `\n---`) |
| #2 | `testResult_cancelled_hasBlankLineBeforeDivider` | Unit | P1 | PASS (existing `\n---`) |
| #4 | `testToolUse_afterAIText_hasBlankLineBeforeToolCall` | Unit | P0 | FAIL (red) |
| #4 | `testToolUse_consecutiveToolCalls_noExtraBlankLine` | Unit | P0 | PASS (no extra blank yet) |
| #6 | `testSystemMessage_hasBlankLineBeforeSystemLine` | Unit | P1 | FAIL (red) |
| #6 | `testSystemMessage_preservesDimStyling` | Unit | P1 | PASS (existing dim) |
| #7 | `testAssistantError_hasBlankLineBeforeError` | Unit | P0 | PASS (error output exists) |
| #7 | `testAssistantError_preservesRedStyling` | Unit | P0 | PASS (existing red) |
| - | `testFullTurnCycle_partialMessageToolUseToolResultPartialMessageResult` | Unit | P0 | FAIL (red) |
| - | `testFullTurnCycle_stateResetsAfterResult_forNextTurn` | Unit | P0 | FAIL (red) |
| - | `testQuietMode_partialMessageStillOutputsBulletPrefix` | Unit | P1 | FAIL (red) |
| - | `testQuietMode_toolUseNotRendered_noBlankLineNeeded` | Unit | P1 | PASS (quiet silences toolUse) |
| - | `testQuietMode_systemMessageNotRendered` | Unit | P1 | PASS (quiet silences system) |
| - | `testPartialMessage_emptyString_noBulletPrefix` | Unit | P1 | PASS (empty guard) |
| - | `testPartialMessage_afterEmptyChunk_firstNonEmptyGetsBullet` | Unit | P1 | FAIL (red) |
| - | `testResult_errorResetsTurnState` | Unit | P1 | FAIL (red) |

## Test Files

- `Tests/OpenAgentCLITests/TurnLabelsTests.swift` -- 20 tests (10 FAIL, 10 PASS)

## TDD Phase

- **Red Phase:** 10 tests fail as expected -- all assert NEW behavior not yet implemented
- **Green Phase:** Implementation in OutputRenderer+SDKMessage.swift and OutputRenderer.swift -- PENDING (dev-story)
- **Refactor Phase:** N/A (minimal changes, state tracking in MarkdownBuffer)

## TDD Red Phase Failures Summary

10 tests fail. Each failure maps to unimplemented behavior:

| # | Test | Expected Behavior | Root Cause |
|---|------|-------------------|------------|
| 1 | `testPartialMessage_firstChunk_outputsBlueBulletPrefix` | Blue "● " prefix before first AI text | `turnHeaderPrinted` state not added to MarkdownBuffer |
| 2 | `testPartialMessage_newTurnAfterResult_outputsBulletPrefix` | Prefix appears in second turn | State reset not implemented in `renderResult` |
| 3 | `testToolUse_afterAIText_hasBlankLineBeforeToolCall` | Blank line before first toolUse after AI text | `firstToolInTurn` state not added |
| 4 | `testSystemMessage_hasBlankLineBeforeSystemLine` | Leading `\n` before `[system]` | `renderSystem` not updated with blank line |
| 5 | `testFullTurnCycle_...Result` | Complete turn has bullet + tool separator | Multiple state changes needed |
| 6 | `testFullTurnCycle_stateResetsAfterResult_forNextTurn` | Turn 2 gets bullet prefix | `resetTurnHeader()` not called in `renderResult` |
| 7 | `testQuietMode_partialMessageStillOutputsBulletPrefix` | Bullet in quiet mode | `turnHeaderPrinted` state needed in all modes |
| 8 | `testPartialMessage_afterEmptyChunk_firstNonEmptyGetsBullet` | Non-empty chunk after empty gets bullet | Bullet logic must check text.isEmpty before setting state |
| 9 | `testResult_errorResetsTurnState` | Error result resets state | `resetTurnHeader()` must be called for all result subtypes |
| 10 | `testAssistantError_hasBlankLineBeforeError` | Blank line before error | `renderAssistant` error branch needs leading `\n` |

## AC Coverage Summary

| AC | Description | Tests | Covered |
|----|-------------|-------|---------|
| #1 | AI text turn prefix | 5 tests | YES |
| #2 | Turn-end separator | 2 tests | YES |
| #3 | User input prefix (no change) | N/A | N/A (existing) |
| #4 | Tool call blank line | 2 tests | YES |
| #5 | Tool result (no change) | N/A | N/A (existing) |
| #6 | System message blank line | 2 tests | YES |
| #7 | Error blank line | 2 tests | YES |
| - | Full turn cycle / state reset | 3 tests | YES |
| - | Quiet mode compatibility | 3 tests | YES |
| - | Edge cases (empty, error reset) | 2 tests | YES |

## Implementation Files to Change

| File | Change |
|------|--------|
| `Sources/OpenAgentCLI/OutputRenderer.swift` | Add `turnHeaderPrinted`, `firstToolInTurn` state to `MarkdownBuffer` |
| `Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift` | Add bullet prefix in `renderPartialMessage`, blank lines in `renderToolUse`/`renderSystem`/`renderAssistant`, state reset in `renderResult` |
| `Sources/OpenAgentCLI/ANSI.swift` | No change needed (`ANSI.blue()` exists) |

## Summary

- **Total tests:** 20
- **AC coverage:** 5/5 actionable criteria covered (AC#3, AC#5 are "no change")
- **Failing tests:** 10 (TDD red phase -- all expected failures)
- **Passing tests:** 10 (verify existing unchanged behavior)
