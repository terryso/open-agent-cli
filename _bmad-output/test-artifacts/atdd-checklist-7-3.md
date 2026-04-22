---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-22'
workflowType: 'testarch-atdd'
inputDocuments:
  - _bmad-output/implementation-artifacts/7-3-persistent-configuration-file.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - Sources/OpenAgentCLI/ConfigLoader.swift
  - Sources/OpenAgentCLI/ArgumentParser.swift
  - Sources/OpenAgentCLI/CLI.swift
  - Tests/OpenAgentCLITests/ConfigLoaderTests.swift
  - Tests/OpenAgentCLITests/ArgumentParserTests.swift
---

# ATDD Checklist - Epic 7, Story 7.3: Persistent Configuration File

**Date:** 2026-04-22
**Author:** TEA Agent
**Primary Test Level:** Unit (Swift/XCTest)
**Stack:** Backend (Swift)
**TDD Phase:** RED (tests fail as expected -- feature not yet implemented)

---

## Story Summary

**As a** user
**I want to** save CLI configuration in a file
**So that** I don't have to pass arguments every time.

## Acceptance Criteria

| AC# | Description | Test Coverage |
|-----|-------------|---------------|
| #1 | Config file at ~/.openagent/config.json applies settings as defaults | testApply_newFields_filledFromConfig |
| #2 | CLI args override config file values (including explicit defaults like --mode default) | testApply_explicitlySet_preventsOverride, testApply_cliArgOverridesConfig_newFields |
| #3 | mcpConfigPath, hooksConfigPath, skillDir load from config file | testLoad_configWithMcpPath, testLoad_configWithHooksPath, testLoad_configWithSkillDir |
| #4 | toolAllow/toolDeny load from config file | testLoad_configWithToolAllow, testLoad_configWithToolDeny |
| #5 | ~/.openagent/ directory auto-created on first run | testEnsureConfigDirectory_createsDir, testEnsureConfigDirectory_existingDir |
| #6 | Missing path fields produce clear warning but CLI continues | testApply_pathValidation_warnsOnMissingFile |
| #7 | Unknown fields in config file are ignored (forward compat) | testLoad_unknownFieldsIgnored |

---

## Generation Mode: AI Generation (Backend)

This is a Swift backend project. No browser recording needed. All tests are XCTest unit tests.

---

## Test Strategy

### Test Level: Unit

All tests are unit tests targeting `ConfigLoader` and `ArgumentParser` directly.

### Priority Assignment

| Priority | Test | Rationale |
|----------|------|-----------|
| P0 | testApply_explicitlySet_preventsOverride | Critical bug fix -- sentinel-value comparison is broken |
| P0 | testApply_newFields_filledFromConfig | Core feature -- new config fields must load |
| P0 | testApply_cliArgOverridesConfig_newFields | Core feature -- priority layering must work |
| P1 | testLoad_configWithMcpPath | AC#3 -- path config loading |
| P1 | testLoad_configWithHooksPath | AC#3 -- path config loading |
| P1 | testLoad_configWithSkillDir | AC#3 -- path config loading |
| P1 | testLoad_configWithToolAllow | AC#4 -- tool whitelist loading |
| P1 | testLoad_configWithToolDeny | AC#4 -- tool blacklist loading |
| P1 | testExplicitlySet_tracksFlaggedValues | AC#2 -- explicitlySet tracking correctness |
| P1 | testExplicitlySet_doesNotTrackDefaults | AC#2 -- defaults should not be in explicitlySet |
| P2 | testApply_pathValidation_warnsOnMissingFile | AC#6 -- graceful degradation |
| P2 | testEnsureConfigDirectory_createsDir | AC#5 -- first-run experience |
| P2 | testEnsureConfigDirectory_existingDir | AC#5 -- idempotent directory creation |
| P2 | testLoad_unknownFieldsIgnored | AC#7 -- forward compatibility |

---

## TDD Red Phase (Current)

All tests are designed to **fail** until the feature is implemented:

1. `explicitlySet` does not exist on `ParsedArgs` -- tests referencing it will not compile
2. `CLIConfig` is missing fields `mcpConfigPath`, `hooksConfigPath`, `skillDir`, `toolAllow`, `toolDeny`, `output` -- tests referencing these will not compile
3. `ConfigLoader.ensureConfigDirectory()` does not exist -- tests calling it will not compile
4. `ConfigLoader.apply()` does not handle path validation warnings -- assertions will fail

### Test Files

1. **ConfigLoaderTests.swift** (extended) -- 12 new test methods
2. **ArgumentParserTests.swift** (extended) -- 2 new test methods for explicitlySet

---

## Acceptance Criteria Coverage Matrix

| AC# | Test Methods | Status |
|-----|-------------|--------|
| #1 | testApply_newFields_filledFromConfig | RED |
| #2 | testApply_explicitlySet_preventsOverride, testApply_cliArgOverridesConfig_newFields, testExplicitlySet_tracksFlaggedValues, testExplicitlySet_doesNotTrackDefaults | RED |
| #3 | testLoad_configWithMcpPath, testLoad_configWithHooksPath, testLoad_configWithSkillDir, testApply_pathFields_filledWhenNil | RED |
| #4 | testLoad_configWithToolAllow, testLoad_configWithToolDeny, testApply_toolAllow_filledWhenNil | RED |
| #5 | testEnsureConfigDirectory_createsDir, testEnsureConfigDirectory_existingDir | RED |
| #6 | testApply_pathValidation_warnsOnMissingFile | RED |
| #7 | testLoad_unknownFieldsIgnored | RED |

---

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Add `explicitlySet: Set<String>` to `ParsedArgs` struct
2. Add 6 missing fields to `CLIConfig` struct
3. Update `ArgumentParser.parse()` to populate `explicitlySet`
4. Refactor `ConfigLoader.apply()` to use `explicitlySet` and handle new fields
5. Add `ConfigLoader.ensureConfigDirectory()` static method
6. Add path validation warnings in `ConfigLoader.apply()`
7. Run tests: `swift test --filter ConfigLoaderTests --filter ArgumentParserTests`
8. Verify all tests PASS (green phase)
9. Commit passing tests

---

## Implementation Guidance

### Source files to modify:

1. **`Sources/OpenAgentCLI/ArgumentParser.swift`**
   - Add `var explicitlySet: Set<String> = []` to `ParsedArgs`
   - Add `result.explicitlySet.insert(...)` in each value-flag branch of `parse()`

2. **`Sources/OpenAgentCLI/ConfigLoader.swift`**
   - Add 6 fields to `CLIConfig`: `mcpConfigPath`, `hooksConfigPath`, `skillDir`, `toolAllow`, `toolDeny`, `output`
   - Refactor `apply()` to use `explicitlySet` instead of sentinel-value comparison
   - Add `ensureConfigDirectory()` static method
   - Add path validation warnings for `mcpConfigPath`, `hooksConfigPath`, `skillDir`

3. **`Sources/OpenAgentCLI/CLI.swift`** (possibly)
   - Call `ConfigLoader.ensureConfigDirectory()` at startup if needed

### Test files to modify:

1. **`Tests/OpenAgentCLITests/ConfigLoaderTests.swift`** -- add 12 new test methods
2. **`Tests/OpenAgentCLITests/ArgumentParserTests.swift`** -- add 2 new test methods

---

## Summary Statistics

- **Total new tests:** 14
- **ConfigLoader tests:** 12
- **ArgumentParser tests:** 2
- **All tests RED (failing):** Yes
- **TDD Phase:** RED
- **Acceptance criteria covered:** 7/7 (100%)
