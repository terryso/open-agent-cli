---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-22'
inputDocuments:
  - _bmad-output/implementation-artifacts/7-7-skills-listing-and-custom-tool-registration.md
  - Sources/OpenAgentCLI/ConfigLoader.swift
  - Sources/OpenAgentCLI/AgentFactory.swift
  - Sources/OpenAgentCLI/ArgumentParser.swift
  - Sources/OpenAgentCLI/HookConfigLoader.swift
  - Tests/OpenAgentCLITests/ConfigLoaderTests.swift
  - Tests/OpenAgentCLITests/AgentFactoryTests.swift
  - Tests/OpenAgentCLITests/ToolLoadingTests.swift
  - .build/index-build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/ToolBuilder.swift
---

# ATDD Checklist: Story 7-7 Skills Listing & Custom Tool Registration

## TDD Red Phase (Current)

- [x] Failing tests generated
- [x] All tests assert EXPECTED behavior (not placeholders)
- [x] All tests designed to fail until feature implemented
- [x] Main source compiles cleanly (no regression)
- [x] Test file fails compilation due to missing types only (intentional)
- [x] No orphaned processes or temp files
- [x] All temp artifacts stored in `_bmad-output/test-artifacts/`

### Compilation Errors (Expected - Red Phase)

All errors are exclusively about missing implementation:
- `cannot find 'CustomToolConfig' in scope` -- struct not yet defined
- `type 'AgentFactory' has no member 'createCustomTools'` -- method not yet implemented
- `value of type 'ParsedArgs' has no member 'customTools'` -- field not yet added
- `value of type 'CLIConfig' has no member 'customTools'` -- field not yet added
- `type of expression is ambiguous without a type annotation` -- cascading from missing CustomToolConfig

### Verification

- Main target: `swift build` succeeds (no source changes)
- Test target: `swift build --build-tests` fails (expected: red phase)

## Acceptance Criteria Coverage

### AC#1: /skills lists available skills with name and description
- **Status**: Already implemented (Story 2.3)
- **Coverage**: Existing `REPLLoopTests` and `SkillLoadingTests`
- **Action**: No new tests needed

### AC#2: Custom tools registered via config file
- **Status**: NEW - requires implementation
- **Test Coverage**:
  - `testCustomToolConfig_decoding_validJSON` (P0 Unit)
  - `testCustomToolConfig_decoding_allFields` (P0 Unit)
  - `testCustomToolConfig_decoding_optionalIsReadOnly_defaultsFalse` (P1 Unit)
  - `testConfigLoad_customToolsParsed` (P0 Unit)
  - `testConfigApply_customTools_filledFromConfig` (P0 Unit)
  - `testCreateCustomTools_validConfig_returnsTools` (P0 Unit)
  - `testCreateCustomTools_toolsAddedToPool` (P0 Integration)
  - `testCreateCustomTools_toolExecution_succeeds` (P1 Integration)
  - `testCreateCustomTools_toolExecution_failure_returnsError` (P1 Integration)
  - `testCreateAgent_withCustomTools_agentCreated` (P1 Integration)

### AC#3: No skills loaded shows "No skills loaded."
- **Status**: Already implemented (Story 2.3)
- **Coverage**: Existing `REPLLoopTests`
- **Action**: No new tests needed

### AC#4: Invalid JSON Schema shows warning, skips tool, CLI continues
- **Status**: NEW - requires implementation
- **Test Coverage**:
  - `testCreateCustomTools_emptySchema_skipped` (P0 Unit)
  - `testCreateCustomTools_emptySchema_printsWarning` (P1 Unit)
  - `testCustomToolConfig_decoding_missingName_throws` (P1 Unit)
  - `testCustomToolConfig_decoding_missingDescription_throws` (P1 Unit)

### AC#5: Invalid execute script path shows warning, skips tool, CLI continues
- **Status**: NEW - requires implementation
- **Test Coverage**:
  - `testCreateCustomTools_missingExecutePath_skipped` (P0 Unit)
  - `testCreateCustomTools_missingExecutePath_printsWarning` (P1 Unit)
  - `testCreateCustomTools_mixedValidAndInvalid_onlyValidRegistered` (P0 Unit)

## Test Strategy Summary

| Level | Count | Priority Range |
|-------|-------|---------------|
| Unit  | 11    | P0-P1         |
| Integration | 3    | P0-P1         |
| **Total** | **14** | |

## Generated Files

- `Tests/OpenAgentCLITests/CustomToolRegistrationTests.swift` - 14 test methods

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Implement `CustomToolConfig` struct in `ConfigLoader.swift`
2. Add `customTools` field to `CLIConfig`
3. Add `customTools` field to `ParsedArgs`
4. Implement `ConfigLoader.apply()` customTools pass-through
5. Implement `AgentFactory.createCustomTools(from:)` method
6. Integrate custom tools into `computeToolPool()`
7. Run tests: `swift test --filter CustomToolRegistrationTests`
8. Verify all tests PASS (green phase)
