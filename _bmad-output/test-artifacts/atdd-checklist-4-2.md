---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-20'
inputDocuments:
  - '_bmad-output/implementation-artifacts/4-2-sub-agent-delegation.md'
  - 'Sources/OpenAgentCLI/AgentFactory.swift'
  - 'Sources/OpenAgentCLI/OutputRenderer.swift'
  - 'Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift'
  - 'Sources/OpenAgentCLI/ANSI.swift'
  - 'Tests/OpenAgentCLITests/ToolLoadingTests.swift'
  - 'Tests/OpenAgentCLITests/OutputRendererTests.swift'
  - 'open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift'
  - 'open-agent-sdk-swift/Sources/OpenAgentSDK/Types/SDKMessage.swift'
---

# ATDD Checklist: Story 4.2 - Sub-Agent Delegation

## TDD Red Phase (Current)

Failing tests generated -- all tests reference behavior not yet implemented.

- **Unit Tests**: 7 tests in `Tests/OpenAgentCLITests/SubAgentTests.swift` (4 will fail until createAgentTool injected)
- **Rendering Tests**: 9 tests in `Tests/OpenAgentCLITests/OutputRendererTests.swift` (all will fail until taskStarted/taskProgress rendering implemented)
- **Total RED**: 13 failing tests, 3 passing (negative/edge cases)

## Acceptance Criteria Coverage

| AC # | Criterion | Test Coverage | Priority |
|------|-----------|---------------|----------|
| #1 | --tools advanced includes Agent tool in tool pool | `testToolPool_advanced_includesAgentTool`, `testToolPool_core_excludesAgentTool`, `testToolPool_all_includesAgentTool`, `testToolPool_specialist_includesAgentTool`, `testToolPool_advancedWithSkill_includesBoth`, `testToolPool_defaultTools_excludesAgentTool`, `testCreateAgent_advancedTools_createsSuccessfully` | P0 |
| #2 | Sub-agent output visible with indented prefix | `testRenderTaskStarted_showsSubAgentPrefix`, `testRenderTaskStarted_usesYellowANSI`, `testRenderTaskStarted_indentedWithTwoSpaces`, `testRenderTaskStarted_producesOutput_notSilent` | P0 |
| #3 | Parent agent continues with sub-agent output after completion | Covered by existing `testRenderToolResult_success_underLimit_noTruncation` (sub-agent results use toolResult message via AgentTool) | P1 |
| #4 | Sub-agent inherits parent's permission mode and API config | SDK内置行为, validated by `testCreateAgent_advancedTools_createsSuccessfully` (AgentTool inherits via SubAgentSpawner) | P1 |
| #5 | Sub-agent progress shown with indented [sub-agent] prefix | `testRenderTaskProgress_showsSubAgentPrefix`, `testRenderTaskProgress_usesGreyANSI`, `testRenderTaskProgress_indentedWithTwoSpaces`, `testRenderTaskProgress_withoutUsage_stillRenders`, `testRenderTaskProgress_producesOutput_notSilent` | P0 |

## Test Inventory

### SubAgentTests.swift (7 tests)

| # | Test Method | AC | Priority | Status | Description |
|---|-------------|-----|----------|--------|-------------|
| 1 | `testToolPool_advanced_includesAgentTool` | #1 | P0 | RED | --tools advanced tool pool contains "Agent" tool |
| 2 | `testToolPool_core_excludesAgentTool` | #1 | P0 | GREEN | --tools core tool pool does NOT contain "Agent" tool |
| 3 | `testToolPool_all_includesAgentTool` | #1 | P0 | RED | --tools all tool pool contains "Agent" tool |
| 4 | `testToolPool_specialist_includesAgentTool` | #1 | P0 | RED | --tools specialist tool pool contains "Agent" tool |
| 5 | `testToolPool_advancedWithSkill_includesBoth` | #1 | P0 | RED | --tools advanced + skill includes both Agent and Skill |
| 6 | `testToolPool_defaultTools_excludesAgentTool` | #1 | P1 | GREEN | Default ParsedArgs (tools="core") excludes Agent |
| 7 | `testCreateAgent_advancedTools_createsSuccessfully` | #1,#4 | P0 | GREEN | Agent creation with advanced tools succeeds |

### OutputRendererTests.swift -- Story 4.2 additions (9 tests)

| # | Test Method | AC | Priority | Status | Description |
|---|-------------|-----|----------|--------|-------------|
| 1 | `testRenderTaskStarted_showsSubAgentPrefix` | #2 | P0 | RED | taskStarted renders [sub-agent] prefix + description |
| 2 | `testRenderTaskStarted_usesYellowANSI` | #2 | P0 | RED | taskStarted uses yellow ANSI color |
| 3 | `testRenderTaskStarted_indentedWithTwoSpaces` | #2 | P0 | RED | taskStarted output has 2-space indent |
| 4 | `testRenderTaskStarted_producesOutput_notSilent` | #2 | P0 | RED | taskStarted not silently ignored |
| 5 | `testRenderTaskProgress_showsSubAgentPrefix` | #5 | P0 | RED | taskProgress renders [sub-agent] prefix + task ID |
| 6 | `testRenderTaskProgress_usesGreyANSI` | #5 | P0 | RED | taskProgress uses grey/dim ANSI color |
| 7 | `testRenderTaskProgress_indentedWithTwoSpaces` | #5 | P0 | RED | taskProgress output has 2-space indent |
| 8 | `testRenderTaskProgress_withoutUsage_stillRenders` | #5 | P1 | RED | taskProgress renders even without usage data |
| 9 | `testRenderTaskProgress_producesOutput_notSilent` | #5 | P0 | RED | taskProgress not silently ignored |

## Test Strategy

- **Stack**: Backend (Swift, XCTest)
- **Test Levels**: Unit (tool pool composition), Rendering (OutputRenderer message formatting)
- **Mode**: AI Generation (backend project)
- **Approach**: Call `AgentFactory.computeToolPool(from:)` with different tool tier values and assert tool presence; construct SDKMessage instances, render them, assert output strings

## Implementation Guidance

### Files to Modify

1. **`Sources/OpenAgentCLI/AgentFactory.swift`** -- In `computeToolPool(from:skillRegistry:)`, when `args.tools` is "advanced", "all", or "specialist", add `createAgentTool()` to the `customTools` array alongside any existing SkillTool. Must coexist with SkillTool via customTools array.

2. **`Sources/OpenAgentCLI/OutputRenderer.swift`** -- Move `.taskStarted` and `.taskProgress` from the silent `break` branch to dedicated rendering branches in the `render(_:)` switch statement.

3. **`Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift`** -- Add `renderTaskStarted(_:)` and `renderTaskProgress(_:)` methods:
   - `renderTaskStarted`: `  [sub-agent] <description>` with yellow ANSI (`\u{001B}[33m`)
   - `renderTaskProgress`: `  [sub-agent] <taskId> - <usage info>` with grey/dim ANSI (`\u{001B}[2m`)

4. **`Sources/OpenAgentCLI/ANSI.swift`** -- Add a `yellow(_:)` helper method for yellow ANSI foreground (`\u{001B}[33m`).

### Key Implementation Notes

- `createAgentTool()` is a zero-argument SDK factory function -- no config needed, SDK injects `SubAgentSpawner` at runtime
- Agent tool should be added to `customTools` array (same path as `createSkillTool`), NOT to `baseTools`
- `--tools core` (default) must NOT include Agent tool -- only advanced/all/specialist
- taskStarted/taskProgress are currently in the silent `break` branch of `render(_:)` -- need to route to new rendering methods
- Sub-agent results come through regular `toolResult` messages (toolName="Agent") -- no special rendering needed
- AC#3 (continuation) and AC#4 (config inheritance) are SDK internal behaviors, not directly testable from CLI side

### Files NOT to Modify

- `ArgumentParser.swift` (--tools parameter already exists)
- `CLI.swift` (no startup flow changes)
- `REPLLoop.swift` (messages flow through existing AsyncStream)
- `CLISingleShot.swift` (no changes needed)

## Regression Status

- **Existing tests**: 319 tests from Story 4.1 baseline all PASS
- **New passing tests**: 3 (negative cases: core excludes, default excludes, advanced creates successfully)
- **New failing tests**: 13 (intentional RED phase)
- **Total test count**: 335 (319 existing + 16 new)
- **Zero regressions**: All pre-existing tests continue to pass

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Modify `AgentFactory.computeToolPool` to include `createAgentTool()` when tools tier is advanced/all/specialist
2. Add `ANSI.yellow(_:)` helper method
3. Add `renderTaskStarted` and `renderTaskProgress` to `OutputRenderer+SDKMessage.swift`
4. Route `.taskStarted` and `.taskProgress` to new renderers in `OutputRenderer.swift`
5. Run tests: `swift test --filter SubAgentTests`
6. Run rendering tests: `swift test --filter OutputRendererTests`
7. Verify all 16 new tests PASS (green phase)
8. Run full regression: `swift test` (verify 335 tests all pass)
9. Commit passing tests
