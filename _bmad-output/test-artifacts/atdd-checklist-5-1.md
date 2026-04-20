---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests']
lastStep: 'step-04-generate-tests'
lastSaved: '2026-04-20'
storyId: '5-1'
storyTitle: 'Permission Mode Configuration'
inputDocuments:
  - '_bmad-output/implementation-artifacts/5-1-permission-mode-configuration.md'
  - 'Sources/OpenAgentCLI/AgentFactory.swift'
  - 'Sources/OpenAgentCLI/REPLLoop.swift'
  - 'Sources/OpenAgentCLI/OutputRenderer.swift'
  - 'Sources/OpenAgentCLI/ArgumentParser.swift'
  - 'Tests/OpenAgentCLITests/AgentFactoryTests.swift'
  - 'Tests/OpenAgentCLITests/REPLLoopTests.swift'
  - 'Tests/OpenAgentCLITests/OutputRendererTests.swift'
  - 'open-agent-sdk-swift/Sources/OpenAgentSDK/Types/PermissionTypes.swift'
  - 'open-agent-sdk-swift/Sources/OpenAgentSDK/Types/ToolTypes.swift'
---

# ATDD Checklist: Story 5.1 - Permission Mode Configuration

## Preflight Summary

- **Stack:** Backend (Swift)
- **Test Framework:** XCTest
- **Story Status:** ready-for-dev
- **Test Dir:** Tests/OpenAgentCLITests/
- **Generation Mode:** AI Generation (backend project, no browser recording)

## Acceptance Criteria Mapping

### AC#1: bypassPermissions mode - all tools execute without approval
| Test | Level | Priority | File |
|------|-------|----------|------|
| testBypassPermissions_alwaysAllows | Unit | P0 | PermissionHandlerTests.swift |
| testDontAsk_alwaysAllows | Unit | P0 | PermissionHandlerTests.swift |
| testAuto_alwaysAllows | Unit | P0 | PermissionHandlerTests.swift |

### AC#2: default mode - dangerous tools prompt for approval
| Test | Level | Priority | File |
|------|-------|----------|------|
| testDefault_allowsReadOnlyTool | Unit | P0 | PermissionHandlerTests.swift |
| testDefault_promptsForWriteTool_yes | Unit | P0 | PermissionHandlerTests.swift |
| testDefault_promptsForWriteTool_no | Unit | P0 | PermissionHandlerTests.swift |
| testAcceptEdits_allowsEditTool | Unit | P1 | PermissionHandlerTests.swift |
| testAcceptEdits_promptsForOtherWrite | Unit | P1 | PermissionHandlerTests.swift |

### AC#3: plan mode - user must approve before execution starts
| Test | Level | Priority | File |
|------|-------|----------|------|
| testPlan_promptsForAllTools | Unit | P0 | PermissionHandlerTests.swift |
| testPlan_promptsForReadOnlyTool | Unit | P1 | PermissionHandlerTests.swift |

### AC#4: invalid mode string - error lists valid modes and exits
| Test | Level | Priority | File |
|------|-------|----------|------|
| testInvalidMode_throwsError | Unit | P0 | AgentFactoryTests.swift (existing) |
| testInvalidMode_errorListsValidModes | Unit | P1 | PermissionHandlerTests.swift |

### Additional Coverage
| Test | Level | Priority | File |
|------|-------|----------|------|
| testBypassPermissions_noOutputProduced | Unit | P1 | PermissionHandlerTests.swift |
| testDefault_userInputYes_returnsAllow | Unit | P1 | PermissionHandlerTests.swift |
| testDefault_userInputNo_returnsDeny | Unit | P1 | PermissionHandlerTests.swift |
| testDefault_promptDisplaysToolInfo | Unit | P2 | PermissionHandlerTests.swift |
| testPermissionHandler_allModes_nonNilResult | Unit | P1 | PermissionHandlerTests.swift |

## Test Strategy

- **Unit tests only** - PermissionHandler is a pure function component producing CanUseToolFn closures
- **No E2E tests** - Backend project, no browser-based testing needed
- **No integration tests with real Agent** - Story explicitly forbids this; only test closure behavior
- **Mock patterns:** MockInputReader (reuses pattern from REPLLoopTests), MockTool (implements ToolProtocol)

## TDD Red Phase Status

All tests are designed to FAIL until `PermissionHandler.swift` is implemented and `AgentFactory.swift` is updated. Tests reference `PermissionHandler` type which does not exist yet.

## Test Files Generated

1. `Tests/OpenAgentCLITests/PermissionHandlerTests.swift` (NEW - 18 test methods)
