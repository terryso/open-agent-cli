---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
lastStep: step-04-generate-tests
lastSaved: '2026-04-21'
inputDocuments:
  - _bmad-output/implementation-artifacts/6-1-hook-system-integration.md
  - Sources/OpenAgentCLI/MCPConfigLoader.swift
  - Sources/OpenAgentCLI/AgentFactory.swift
  - Sources/OpenAgentCLI/CLI.swift
  - Sources/OpenAgentCLI/ArgumentParser.swift
  - Tests/OpenAgentCLITests/MCPConfigLoaderTests.swift
  - Tests/OpenAgentCLITests/AgentFactoryTests.swift
story_id: '6-1'
detected_stack: backend
generation_mode: ai-generation
tdd_phase: RED
---

# ATDD Checklist: Story 6-1 Hook System Integration

## Preflight Summary

| Item | Status | Details |
|------|--------|---------|
| Stack | backend | Swift Package Manager project, no frontend |
| Test Framework | XCTest | Swift testing via `swift test` |
| Story Status | ready-for-dev | Clear acceptance criteria defined |
| Generation Mode | AI Generation | Backend project, no browser recording needed |
| TEA Config | defaults | No .tea config file found, using defaults |

## Acceptance Criteria Coverage

### AC#1: Hooks config JSON -> hooks registered via createHookRegistry()

| Test | Level | Priority | File | Status |
|------|-------|----------|------|--------|
| testLoadHooks_validConfig | Unit | P0 | HookConfigLoaderTests.swift | RED |
| testLoadHooks_withMatcherAndTimeout | Unit | P0 | HookConfigLoaderTests.swift | RED |
| testLoadHooks_emptyHooks | Unit | P1 | HookConfigLoaderTests.swift | RED |
| testLoadHooks_fileNotFound | Unit | P0 | HookConfigLoaderTests.swift | RED |
| testLoadHooks_invalidJSON | Unit | P0 | HookConfigLoaderTests.swift | RED |
| testLoadHooks_missingHooksKey | Unit | P0 | HookConfigLoaderTests.swift | RED |
| testLoadHooks_missingCommand | Unit | P0 | HookConfigLoaderTests.swift | RED |
| testLoadHooks_emptyCommand | Unit | P1 | HookConfigLoaderTests.swift | RED |
| testLoadHooks_allValidEventNames | Unit | P1 | HookConfigLoaderTests.swift | RED |
| testLoadHooks_invalidEventName_behavesAsExpected | Unit | P1 | HookConfigLoaderTests.swift | RED |
| testCreateAgent_noHooks_hookRegistryNotConfigured | Integration | P0 | AgentFactoryTests.swift | RED |
| testCreateAgent_withHooks_agentCreated | Integration | P0 | AgentFactoryTests.swift | RED |
| testCreateAgent_withInvalidHooksPath_throwsError | Integration | P0 | AgentFactoryTests.swift | RED |
| testCreateAgent_withInvalidHooksJSON_throwsError | Integration | P1 | AgentFactoryTests.swift | RED |

### AC#2: preToolUse hook -> hook script executes before tool runs

| Test | Level | Priority | File | Status |
|------|-------|----------|------|--------|
| testLoadHooks_multipleEvents | Unit | P0 | HookConfigLoaderTests.swift | RED |
| testLoadHooks_multipleHooksPerEvent | Unit | P1 | HookConfigLoaderTests.swift | RED |

Note: Actual hook execution timing (before tool runs) is verified by SDK internals (HookRegistry + ShellHookExecutor). The CLI layer tests verify that hooks are loaded and passed to the SDK correctly.

### AC#3: Hook timeout/error -> warning logged, agent operation continues

| Test | Level | Priority | File | Status |
|------|-------|----------|------|--------|
| testLoadHooks_shortTimeout_stillLoads | Unit | P1 | HookConfigLoaderTests.swift | RED |

Note: Actual timeout/error resilience at runtime is handled by SDK's ShellHookExecutor (cancellation + error logging). The CLI layer verifies config loading succeeds even with short timeouts configured.

## Test Strategy

### Test Levels (Backend)

- **Unit** (12 tests): HookConfigLoader parsing logic, validation, edge cases
- **Integration** (4 tests): AgentFactory hook config pass-through

### Priority Distribution

- **P0** (9 tests): Core functionality -- valid config, error cases, integration
- **P1** (5 tests): Edge cases -- empty hooks, all event names, invalid events
- **P2** (0 tests): Deferred
- **P3** (0 tests): Deferred

## Test Files Created

| File | Tests | Status |
|------|-------|--------|
| Tests/OpenAgentCLITests/HookConfigLoaderTests.swift | 12 | RED (TDD) |
| Tests/OpenAgentCLITests/AgentFactoryTests.swift (modified) | +4 | RED (TDD) |

## TDD Red Phase Notes

These tests define EXPECTED behavior. They will:

1. **Fail to compile** until `HookConfigLoader.swift` is created (new type)
2. **Fail to compile** for async tests until `createAgent(from:)` becomes `async throws`
3. **Fail at runtime** once compilation succeeds but implementation is incomplete

This is intentional -- TDD red phase requires tests to fail before implementation.

### Implementation Required to Turn Tests Green

1. **Create `Sources/OpenAgentCLI/HookConfigLoader.swift`**
   - `HookConfigLoader` enum with `loadHooksConfig(from:)` static method
   - `HookConfigLoaderError` enum with error cases: fileNotFound, invalidJSON, missingHooksKey, missingCommand, emptyCommand, invalidEventName

2. **Modify `Sources/OpenAgentCLI/AgentFactory.swift`**
   - Change `createAgent(from:)` signature to `async throws`
   - Add hooks config loading after MCP loading (step 6c)
   - Pass `hookRegistry` to `AgentOptions`

3. **Modify `Sources/OpenAgentCLI/CLI.swift`**
   - Add `await` to `createAgentOrExit(from:)` calls
   - Display `[Hooks configured]` when hooks path is provided
   - Update `createAgentOrExit` to handle async

### Existing Tests Impact

- `AgentFactoryTests.swift`: Existing tests use `try AgentFactory.createAgent(from:)` which needs to become `try await AgentFactory.createAgent(from:)`
- `MCPConfigLoaderTests.swift`: Uses `AgentFactory.createAgent(from:)` in 2 integration tests -- needs `await`
- All existing callers of `createAgent` must add `await`

## Regression Check

- **Expected existing test count:** 396 tests (from Story 5.3 completion)
- **New tests added:** 16 (12 HookConfigLoader + 4 AgentFactory hooks integration)
- **Tests requiring modification:** All tests calling `AgentFactory.createAgent(from:)` need `await` added
