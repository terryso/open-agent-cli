---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: 2026-04-20
storyId: 2-3
inputDocuments:
  - _bmad-output/implementation-artifacts/2-3-skills-loading-and-invocation.md
  - Sources/OpenAgentCLI/AgentFactory.swift
  - Sources/OpenAgentCLI/CLI.swift
  - Sources/OpenAgentCLI/REPLLoop.swift
  - Sources/OpenAgentCLI/ArgumentParser.swift
  - Tests/OpenAgentCLITests/AgentFactoryTests.swift
  - Tests/OpenAgentCLITests/REPLLoopTests.swift
  - Tests/OpenAgentCLITests/ToolLoadingTests.swift
  - Tests/OpenAgentCLITests/OutputRendererTests.swift
  - Tests/OpenAgentCLITests/CLISingleShotTests.swift
tddPhase: RED
detectedStack: backend
testFramework: XCTest
---

# ATDD Checklist - Story 2.3: Skills Loading and Invocation

## Story Summary

**As a user**, I want to load skill definitions from a directory and invoke specific skills, so I can use pre-defined prompt templates for common tasks without restarting.

## Preflight Verification

| Prerequisite | Status |
|---|---|
| Story approved with clear acceptance criteria | PASS |
| Test framework configured (XCTest) | PASS |
| Development environment available | PASS |
| Existing 221 tests passing | PASS |
| Stack detected: backend (Swift CLI) | PASS |

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
| AC#1 | `--skill-dir` loads skills into SkillRegistry | Unit | P0 |
| AC#2 | `--skill <name>` auto-invokes specified skill | Integration | P0 |
| AC#3 | `/skills` command lists loaded skills | Unit | P0 |
| AC#4 | `--skill nonexistent` shows "Skill not found" + available skills | Unit | P0 |

### Test Priority Matrix

| Priority | Risk | Business Impact | Test Count |
|---|---|---|---|
| P0 | High - Core feature | High - User-facing | 22 |
| P1 | Medium - Regression | Medium - Existing features | 5 |
| Total | | | 27 |

## Test File

**File:** `Tests/OpenAgentCLITests/SkillLoadingTests.swift`

### Test Methods and AC Coverage

| # | Test Method | AC | Priority | Description |
|---|---|---|---|---|
| 1 | `testCreateSkillRegistry_withSkillDir_returnsRegistry` | #1 | P0 | skillDir provided -> registry returned |
| 2 | `testCreateSkillRegistry_withSkillDir_discoversSkill` | #1 | P0 | Skills from directory discovered |
| 3 | `testCreateSkillRegistry_noSkillArgs_returnsNil` | #1 | P0 | No skill args -> nil registry |
| 4 | `testCreateSkillRegistry_onlySkillName_noSkillDir_usesDefaultDirs` | #1 | P0 | skillName alone doesn't crash |
| 5 | `testCreateAgent_withSkillDir_agentCreatedSuccessfully` | #1 | P0 | Agent creation with skillDir succeeds |
| 6 | `testCreateAgent_withSkillDir_skillToolInPool` | #1 | P0 | SkillTool in tool pool when skillDir set |
| 7 | `testCreateAgent_withoutSkillDir_noSkillToolInPool` | #1 | P1 | No SkillTool without skillDir (regression) |
| 8 | `testSkillInvocation_validSkill_sendsPromptTemplate` | #2 | P0 | Valid skill found, promptTemplate accessible |
| 9 | `testSkillInvocation_skillRegistry_findReturnsCorrectSkill` | #2 | P0 | Registry.find() returns correct skill |
| 10 | `testSkillInvocation_skillRegistry_findReturnsNilForUnknown` | #2 | P0 | Registry.find() returns nil for unknown |
| 11 | `testSkillInvocation_invalidSkill_registryReportsNotFound` | #4 | P0 | Invalid skill -> registry reports not found + lists available |
| 12 | `testREPLSkillsCommand_listsSkills` | #3 | P0 | /skills lists name and description |
| 13 | `testREPLSkillsCommand_multipleSkills_showsAll` | #3 | P0 | All skills listed |
| 14 | `testREPLSkillsCommand_sortedByName` | #3 | P0 | Skills sorted alphabetically |
| 15 | `testREPLSkillsCommand_noSkills_showsMessage` | #3 | P0 | "No skills loaded" message |
| 16 | `testREPLSkillsCommand_nilRegistry_showsMessage` | #3 | P0 | nil registry -> "No skills loaded" |
| 17 | `testREPLHelp_includesSkillsCommand` | #3 | P0 | /help includes /skills |
| 18 | `testCreateAgent_withoutSkillArgs_behaviorUnchanged` | #1 | P1 | Agent creation unchanged without skill args |
| 19 | `testComputeToolPool_withoutSkillArgs_returnsCoreTools` | #1 | P1 | Tool pool unchanged without skill args |
| 20 | `testArgumentParser_skillDir_parsesCorrectly` | #1 | P1 | ArgumentParser handles --skill-dir |
| 21 | `testArgumentParser_skillName_parsesCorrectly` | #1 | P1 | ArgumentParser handles --skill |
| 22 | `testArgumentParser_skillDirAndSkillName_bothParsed` | #1 | P1 | Both flags parsed together |
| 23 | `testSkillInvocation_invalidSkill_availableSkillsListedInError` | #4 | P0 | Available skills listable for error message |
| 24 | `testREPLSkillsCommand_format_nameAndDescription` | #3 | P0 | Format "{name}: {description}" |
| 25 | `testREPLSkillsCommand_showsSkillCount` | #3 | P0 | Skill count displayed |
| 26 | `testFullPipeline_skillDirArgs_registryCreated` | #1 | P0 | Full pipeline: parser -> registry |
| 27 | `testFullPipeline_skillNameOnly_noCrash` | #1 | P0 | --skill without --skill-dir no crash |

## TDD Red Phase Status

### APIs Not Yet Implemented (Expected Compilation Errors)

| Missing API | Source File | Task | Error Count |
|---|---|---|---|
| `AgentFactory.createSkillRegistry(from:)` | AgentFactory.swift | Task 1 | 11 |
| `REPLLoop.init(..., skillRegistry:)` | REPLLoop.swift | Task 3 | 7 |
| **Total** | | | **18** |

### Error Categories

1. **`type 'AgentFactory' has no member 'createSkillRegistry'`** -- New static method needed on AgentFactory
2. **`extra argument 'skillRegistry' in call`** -- New init parameter needed on REPLLoop
3. **`'nil' requires a contextual type`** -- Related to nil skillRegistry parameter (same root cause as #2)

### Regression Verification

| Check | Status |
|---|---|
| All 221 existing tests pass | PASS |
| No changes to existing source files | PASS |
| No changes to existing test files | PASS |
| Build succeeds (source only, no tests) | PASS |

## Implementation Requirements (Green Phase Guide)

### Task 1: AgentFactory Enhancement

Add to `AgentFactory.swift`:

```swift
static func createSkillRegistry(from args: ParsedArgs) -> SkillRegistry? {
    guard args.skillDir != nil || args.skillName != nil else { return nil }
    let registry = SkillRegistry()
    let dirs = args.skillDir.map { [$0] }
    let names = args.skillName.map { [$0] }
    registry.registerDiscoveredSkills(from: dirs, skillNames: names)
    return registry
}
```

Update `computeToolPool` to include SkillTool when skills are loaded.

### Task 2: CLI Skill Auto-Invocation

Add skill invocation logic to `CLI.swift`:
- After Agent creation, check `args.skillName`
- Look up skill in registry
- Send promptTemplate to agent or show "Skill not found" error

### Task 3: REPLLoop /skills Command

Add to `REPLLoop.swift`:
- New `skillRegistry: SkillRegistry?` property
- `/skills` case in `handleSlashCommand`
- Update `/help` output to include `/skills`

## Key Risks and Assumptions

| Risk | Mitigation |
|---|---|
| SDK SkillRegistry/SkillLoader API may differ from story spec | Tests use documented SDK public API; adjust if needed in green phase |
| Temp directory cleanup in tests | tearDown removes temp dirs |
| Skill discovery depends on filesystem | Tests create temp SKILL.md fixtures |
| REPLLoop init signature change may affect other tests | Existing REPLLoopTests use positional params, which remain compatible |

## Next Steps

1. **Green Phase**: Implement Tasks 1-3 per story specification
2. **Verify**: All 27 new tests pass + all 221 existing tests pass
3. **Refactor**: Clean up any duplication between new and existing test helpers
