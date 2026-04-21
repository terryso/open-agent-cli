---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests']
lastStep: 'step-04-generate-tests'
lastSaved: '2026-04-21'
storyId: '5-2'
storyTitle: 'Interactive Permission Prompts'
inputDocuments:
  - '_bmad-output/implementation-artifacts/5-2-interactive-permission-prompts.md'
  - 'Sources/OpenAgentCLI/PermissionHandler.swift'
  - 'Sources/OpenAgentCLI/AgentFactory.swift'
  - 'Sources/OpenAgentCLI/ANSI.swift'
  - 'Sources/OpenAgentCLI/REPLLoop.swift'
  - 'Sources/OpenAgentCLI/OutputRenderer.swift'
  - 'Tests/OpenAgentCLITests/PermissionHandlerTests.swift'
  - 'Tests/OpenAgentCLITests/REPLLoopTests.swift'
---

# ATDD Checklist: Story 5.2 - Interactive Permission Prompts

## Preflight Summary

- **Stack:** Backend (Swift)
- **Test Framework:** XCTest
- **Story Status:** ready-for-dev
- **Test Dir:** Tests/OpenAgentCLITests/
- **Generation Mode:** AI Generation (backend project, no browser recording)

## Acceptance Criteria Mapping

### AC#1: Prompt displays tool name, input summary, and risk level
| Test | Level | Priority | File |
|------|-------|----------|------|
| testRiskLevel_highRisk_destructiveBash | Unit | P0 | PermissionHandlerTests.swift |
| testRiskLevel_highRisk_formatCommand | Unit | P0 | PermissionHandlerTests.swift |
| testRiskLevel_mediumRisk_writeTool | Unit | P0 | PermissionHandlerTests.swift |
| testRiskLevel_mediumRisk_bashNonDestructive | Unit | P1 | PermissionHandlerTests.swift |
| testRiskLevel_lowRisk_editTool | Unit | P0 | PermissionHandlerTests.swift |
| testPromptDisplays_riskLevelTag | Unit | P0 | PermissionHandlerTests.swift |
| testPromptDisplays_toolName | Unit | P0 | PermissionHandlerTests.swift |
| testPromptDisplays_inputSummary | Unit | P0 | PermissionHandlerTests.swift |
| testPromptHighRisk_usesRedColor | Unit | P1 | PermissionHandlerTests.swift |
| testPromptMediumRisk_usesYellowColor | Unit | P1 | PermissionHandlerTests.swift |
| testPromptLowRisk_usesDimStyle | Unit | P1 | PermissionHandlerTests.swift |

### AC#2: User input y/yes allows tool execution (enhanced with "always")
| Test | Level | Priority | File |
|------|-------|----------|------|
| testPromptOffers_alwaysOption | Unit | P0 | PermissionHandlerTests.swift |
| testAlwaysOption_allowsFirstCall | Unit | P0 | PermissionHandlerTests.swift |
| testAlwaysOption_fullWord_allowsFirstCall | Unit | P1 | PermissionHandlerTests.swift |
| testAlwaysOption_sessionLevelMemory | Unit | P0 | PermissionHandlerTests.swift |
| testAlwaysOption_doesNotAffectOtherTools | Unit | P0 | PermissionHandlerTests.swift |

### AC#3: User input n/no denies tool execution (enhanced with empty input + non-interactive)
| Test | Level | Priority | File |
|------|-------|----------|------|
| testEmptyInput_defaultsToDeny | Unit | P0 | PermissionHandlerTests.swift |
| testNonInteractive_defaultMode_deniesWriteTool | Unit | P0 | PermissionHandlerTests.swift |
| testNonInteractive_defaultMode_allowsReadOnlyTool | Unit | P0 | PermissionHandlerTests.swift |
| testNonInteractive_planMode_deniesAllTools | Unit | P0 | PermissionHandlerTests.swift |
| testNonInteractive_bypassPermissions_autoAllows | Unit | P0 | PermissionHandlerTests.swift |
| testNonInteractive_acceptEdits_deniesNonEditWrite | Unit | P1 | PermissionHandlerTests.swift |
| testNonInteractive_acceptEdits_allowsEditTool | Unit | P1 | PermissionHandlerTests.swift |
| testNonInteractive_dontAsk_autoAllows | Unit | P1 | PermissionHandlerTests.swift |
| testNonInteractive_auto_autoAllows | Unit | P1 | PermissionHandlerTests.swift |

## Test Strategy

- **Unit tests only** - PermissionHandler is a pure function component producing CanUseToolFn closures
- **No E2E tests** - Backend project, no browser-based testing needed
- **Mock patterns:** MockInputReader (reuses existing pattern), MockTool (implements ToolProtocol), MockPermissionOutput (captures output)
- **New types needed (to be implemented):**
  - `RiskLevel` enum with `.high`, `.medium`, `.low`
  - `PermissionHandler.classifyRiskLevel(tool:input:)` static method
  - `PermissionHandler.createCanUseTool(mode:reader:renderer:isInteractive:)` with `isInteractive` parameter
  - `PermissionState` class for session-level "always" memory

## TDD Red Phase Status

All 27 new tests fail compilation until the following are implemented:

1. **`RiskLevel` enum** - Type with `.high`, `.medium`, `.low` cases (5 test errors)
2. **`PermissionHandler.classifyRiskLevel(tool:input:)`** - Static method for risk classification (5 test errors)
3. **`PermissionHandler.createCanUseTool(mode:reader:renderer:isInteractive:)`** - New parameter (22 test errors)

Total compilation errors: 62 (3 unique categories)

## Implementation Required to Turn Tests Green

### PermissionHandler.swift changes:
1. Add `RiskLevel` enum with `.high`, `.medium`, `.low` cases
2. Add `classifyRiskLevel(tool:input:)` static method
3. Add `isInteractive: Bool = true` parameter to `createCanUseTool`
4. Add `PermissionState` class for session-level "always" memory
5. Enhance `promptUser` to display risk level tag with color coding
6. Add `a`/`always` handling in prompt response switch
7. Add empty input -> deny with message
8. Add non-interactive mode degradation logic

### AgentFactory.swift changes:
1. Add `isInteractive` detection (check `args.prompt == nil && args.skillName == nil`)
2. Pass `isInteractive` to `PermissionHandler.createCanUseTool`

## Test Files Modified

1. `Tests/OpenAgentCLITests/PermissionHandlerTests.swift` (27 new test methods added for Story 5.2)
