---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-21'
workflowType: 'testarch-atdd'
inputDocuments:
  - _bmad-output/implementation-artifacts/6-2-specialist-tools-and-tool-filtering.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - Sources/OpenAgentCLI/AgentFactory.swift
  - Sources/OpenAgentCLI/ArgumentParser.swift
---

# ATDD Checklist - Epic 6, Story 6.2: Specialist Tools & Tool Filtering

**Date:** 2026-04-21
**Author:** TEA Agent
**Primary Test Level:** Unit (Swift/XCTest)
**Stack:** Backend (Swift)
**TDD Phase:** GREEN (all tests pass — feature already implemented)

---

## Story Summary

**As a** CLI user
**I want** to load specialist tools and control which tools are available
**So that** I can tailor the Agent's capabilities to the task at hand

---

## Acceptance Criteria

1. **AC#1:** Given `--tools specialist`, when Agent is created, then specialist tools are loaded (Worktree, Plan, Cron, TodoWrite, LSP, Config, RemoteTrigger, MCP Resource tools)
2. **AC#2:** Given `--tool-deny "Bash,Write"`, when Agent creates tool pool, then Bash and Write are excluded
3. **AC#3:** Given `--tool-allow "Read,Grep,Glob"`, when Agent creates tool pool, then only Read, Grep, and Glob are available

---

## Tests Created (26 tests)

### Unit Tests: SpecialistToolFilterTests (26 tests)

**File:** `Tests/OpenAgentCLITests/SpecialistToolFilterTests.swift` (349 lines)

#### AC#1: Specialist Tool Loading (8 tests)

- **testSpecialistTier_loadsAllSpecialistTools** - Verifies all 13 specialist tools are loaded (EnterWorktree, ExitWorktree, EnterPlanMode, ExitPlanMode, CronCreate, CronDelete, CronList, TodoWrite, LSP, Config, RemoteTrigger, ListMcpResources, ReadMcpResource)
- **testSpecialistTier_hasExpectedCount** - Verifies specialist tier has >= 13 tools
- **testSpecialistTier_doesNotIncludeCoreTools** - Verifies specialist tier does not overlap with core tools
- **testSpecialistTier_includesAgentTool** - Verifies computeToolPool with specialist includes Agent tool for sub-agent delegation
- **testAllTier_loadsCoreAndSpecialistTools** - Verifies `--tools all` loads core + specialist combined
- **testCreateAgent_specialistTools_createsAgent** - Integration: Agent creation with specialist tools succeeds

#### AC#2: Tool Deny Filtering (4 tests)

- **testToolDeny_excludesSpecifiedTools** - Verifies `--tool-deny "Bash,Write"` excludes both from core pool
- **testToolDeny_singleTool** - Verifies single tool deny works
- **testToolDeny_withSpecialistTools** - Verifies deny filtering with specialist tier
- **testToolDeny_withAllTier** - Verifies deny filtering with `--tools all`

#### AC#3: Tool Allow Filtering (4 tests)

- **testToolAllow_restrictsToSpecifiedTools** - Verifies `--tool-allow "Read,Grep,Glob"` restricts to those 3
- **testToolAllow_singleTool** - Verifies single tool allow works
- **testToolAllow_withSpecialistTools** - Verifies allow filtering with specialist tier
- **testToolAllow_nonExistentTools_resultsInEmptyOrFilteredPool** - Verifies allow with non-existent tools results in empty pool

#### AC#2 + AC#3: Combined Allow/Deny (2 tests)

- **testToolAllowAndDeny_denyTakesPrecedence** - Verifies deny wins when a tool is in both allow and deny
- **testToolAllowAndDeny_denyTakesPrecedence_withSpecialistTools** - Verifies deny precedence with specialist tier

#### Edge Cases: Empty Lists (2 tests)

- **testEmptyToolAllow_noFiltering** - Verifies empty allow array does not filter
- **testEmptyToolDeny_noFiltering** - Verifies empty deny array does not filter

#### ArgumentParser Integration (4 tests)

- **testArgumentParser_toolAllow_parsesCommaSeparated** - Verifies `--tool-allow Read,Grep,Glob` parsing
- **testArgumentParser_toolDeny_parsesCommaSeparated** - Verifies `--tool-deny Bash,Write` parsing
- **testArgumentParser_toolsSpecialist_accepted** - Verifies `--tools specialist` is accepted
- **testArgumentParser_invalidToolTier_rejected** - Verifies invalid tool tier is rejected with exit code 1

#### Full Pipeline Integration (4 tests)

- **testFullPipeline_specialistTools_argsToAgent** - Full pipeline: ArgumentParser -> AgentFactory with specialist
- **testFullPipeline_toolAllow_argsToPool** - Full pipeline with tool-allow
- **testFullPipeline_toolDeny_argsToPool** - Full pipeline with tool-deny
- **testFullPipeline_specialistWithAllowAndDeny** - Full pipeline with combined specialist + allow + deny

---

## Existing Test Coverage (Overlapping)

The following tests in existing files also cover aspects of Story 6.2:

**ToolLoadingTests.swift** (already passing):
- `testMapToolTier_specialist_returnsSpecialistTools` - Verifies specialist tier returns tools
- `testMapToolTier_all_returnsCoreAndSpecialist` - Verifies all tier = core + specialist
- `testComputeToolPool_toolAllow_filtersToAllowedOnly` - Allow filtering
- `testComputeToolPool_toolDeny_excludesDenied` - Deny filtering
- `testComputeToolPool_toolAllowAndDeny_denyTakesPrecedence` - Deny precedence

**AgentFactoryTests.swift** (already passing):
- `testCreateAgent_toolAllowPassed_createsAgent` - Allow pass-through
- `testCreateAgent_toolDenyPassed_createsAgent` - Deny pass-through
- `testCreateAgent_toolAllowAndDeny_createsAgent` - Combined pass-through

---

## Test Execution Evidence

### Full Test Suite Run

**Command:** `swift test`

**Results:**

```
Test Suite 'All tests' passed at 2026-04-21 13:09:55.
  Executed 439 tests, with 0 failures (0 unexpected) in 23.764 seconds
```

**Summary:**

- Total tests: 439 (413 existing + 26 new)
- Passing: 439 (100%)
- Failing: 0
- Status: GREEN phase verified

### New Tests Only

**Command:** `swift test --filter SpecialistToolFilterTests`

```
Test Suite 'SpecialistToolFilterTests' passed.
  Executed 26 tests, with 0 failures (0 unexpected) in 0.014 seconds
```

---

## Implementation Checklist

### Test: testSpecialistTier_loadsAllSpecialistTools

**File:** `Tests/OpenAgentCLITests/SpecialistToolFilterTests.swift`

**Implementation already exists in:**
- [x] `AgentFactory.mapToolTier("specialist")` returns `getAllBaseTools(tier: .specialist)`
- [x] SDK provides 13 specialist tools via `.specialist` tier
- [x] Test passes (GREEN)

### Test: testToolDeny_excludesSpecifiedTools

**File:** `Tests/OpenAgentCLITests/SpecialistToolFilterTests.swift`

**Implementation already exists in:**
- [x] `AgentFactory.computeToolPool` passes `args.toolDeny` to `assembleToolPool`
- [x] SDK `filterTools` correctly excludes denied tools
- [x] Test passes (GREEN)

### Test: testToolAllow_restrictsToSpecifiedTools

**File:** `Tests/OpenAgentCLITests/SpecialistToolFilterTests.swift`

**Implementation already exists in:**
- [x] `AgentFactory.computeToolPool` passes `args.toolAllow` to `assembleToolPool`
- [x] SDK `filterTools` correctly restricts to allowed tools
- [x] Test passes (GREEN)

---

## Running Tests

```bash
# Run all tests for this story (new tests)
swift test --filter SpecialistToolFilterTests

# Run existing overlapping tests
swift test --filter ToolLoadingTests

# Run full test suite (regression check)
swift test

# Run specific test
swift test --filter SpecialistToolFilterTests/testSpecialistTier_loadsAllSpecialistTools
```

---

## Key Findings

1. **All functionality was already implemented** in prior stories (1.2, 2.1, 6.1). Story 6.2 is primarily a verification and testing story.

2. **Specialist tier contains exactly 13 tools** (not 14 as the story spec mentioned). The discrepancy is noted in the implementation artifact.

3. **Specialist tier does NOT include core tools** - this is correct per PRD FR3.3. Users who need both should use `--tools all`.

4. **Dual filtering is intentional and safe** - `assembleToolPool` filters at pool assembly time, while `AgentOptions.allowedTools/disallowedTools` filters at runtime (before sending to LLM).

5. **Deny takes precedence over allow** - confirmed by SDK `filterTools` implementation.

---

## Knowledge Base References Applied

- **component-tdd.md** - Component test strategies adapted for Swift XCTest
- **test-quality.md** - Test design principles (Given-When-Then, one assertion per test, determinism)
- **data-factories.md** - Helper pattern for ParsedArgs construction

See `tea-index.csv` for complete knowledge fragment mapping.

---

**Generated by BMad TEA Agent** - 2026-04-21
