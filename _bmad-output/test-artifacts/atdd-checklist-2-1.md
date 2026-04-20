---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-20'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/2-1-core-tool-loading-and-display.md'
  - 'Sources/OpenAgentCLI/AgentFactory.swift'
  - 'Sources/OpenAgentCLI/REPLLoop.swift'
  - 'Sources/OpenAgentCLI/CLI.swift'
  - 'Tests/OpenAgentCLITests/AgentFactoryTests.swift'
  - 'Tests/OpenAgentCLITests/REPLLoopTests.swift'
---

# ATDD Checklist - Epic 2, Story 2.1: Core Tool Loading & Display

**Date:** 2026-04-20
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Unit (Swift/XCTest backend)
**Detected Stack:** backend (Swift CLI project)

---

## Story Summary

As a user, I want the Agent to have default file and Shell tool access so it can perform real tasks like reading files and running commands. This story implements tool tier loading via `--tools`, tool filtering via `--tool-allow`/`--tool-deny`, and a `/tools` REPL command.

**As a** CLI user
**I want** tool loading, filtering, and display capabilities
**So that** I can control which tools the Agent has access to and see what is loaded

---

## Acceptance Criteria

1. **AC#1:** CLI starts with default settings (no `--tools`) -> loads Core tier tools (Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, AskUser, ToolSearch)
2. **AC#2:** CLI with `--tools advanced` -> loads Core + Advanced tier tools (Advanced currently empty)
3. **AC#3:** CLI with `--tools all` -> loads Core + Specialist tier tools
4. **AC#4:** CLI with `--tools specialist` -> loads Specialist tier tools only
5. **AC#5:** `/tools` command in REPL displays loaded tool names list
6. **AC#6:** `--tool-allow "Bash,Read"` with `--tools core` -> only Bash and Read loaded
7. **AC#7:** `--tool-deny "Write"` with `--tools core` -> Core tools minus Write

---

## Failing Tests Created (RED Phase)

### Unit Tests: ToolLoadingTests.swift (12 tests)

**File:** `Tests/OpenAgentCLITests/ToolLoadingTests.swift`

- **[P0] testMapToolTier_core_returnsTenTools** - Verifies `mapToolTier("core")` returns 10 tools (AC#1)
  - **Status:** RED - `mapToolTier` static method not yet implemented on AgentFactory
  - **Verifies:** Core tier loads exactly 10 tools

- **[P0] testMapToolTier_core_containsExpectedToolNames** - Verifies core tool names include Bash, Read, Write, Edit, Glob, Grep (AC#1)
  - **Status:** RED - `mapToolTier` not implemented
  - **Verifies:** Core tier contains expected tool names

- **[P0] testMapToolTier_advanced_returnsCoreTools** - Verifies `mapToolTier("advanced")` returns Core tools (since Advanced is empty) (AC#2)
  - **Status:** RED - `mapToolTier` not implemented
  - **Verifies:** Advanced tier falls back to core (SDK advanced is empty)

- **[P0] testMapToolTier_specialist_returnsSpecialistTools** - Verifies `mapToolTier("specialist")` returns specialist tier tools (AC#4)
  - **Status:** RED - `mapToolTier` not implemented
  - **Verifies:** Specialist tier loads correct tools

- **[P0] testMapToolTier_all_returnsCoreAndSpecialist** - Verifies `mapToolTier("all")` returns Core + Specialist combined (AC#3)
  - **Status:** RED - `mapToolTier` not implemented
  - **Verifies:** All tier combines core + specialist

- **[P1] testMapToolTier_unknown_defaultsToCore** - Verifies unknown tier string falls back to core (edge case)
  - **Status:** RED - `mapToolTier` not implemented
  - **Verifies:** Safe fallback for invalid tier input

- **[P0] testCreateAgent_defaultTools_loadsCoreTools** - Verifies `createAgent` with default `tools="core"` loads tools into AgentOptions (AC#1)
  - **Status:** RED - `createAgent` does not use `ParsedArgs.tools` yet
  - **Verifies:** Integration path from ParsedArgs to AgentOptions

- **[P0] testCreateAgent_toolAllow_filtersToAllowedOnly** - Verifies `--tool-allow "Bash,Read"` restricts to those tools only (AC#6)
  - **Status:** RED - `assembleToolPool` not integrated in createAgent
  - **Verifies:** allowedTools filter works with tool pool assembly

- **[P0] testCreateAgent_toolDeny_excludesDenied** - Verifies `--tool-deny "Write"` excludes Write from core tools (AC#7)
  - **Status:** RED - `assembleToolPool` not integrated in createAgent
  - **Verifies:** disallowedTools filter works with tool pool assembly

- **[P1] testCreateAgent_toolAllowAndDeny_denyTakesPrecedence** - Verifies when both are specified, deny wins (AC#6 + AC#7 intersection)
  - **Status:** RED - `assembleToolPool` not integrated in createAgent
  - **Verifies:** Deny overrides allow when tool appears in both lists

- **[P1] testCreateAgent_advancedTools_createsAgent** - Verifies agent creation succeeds with `--tools advanced` (AC#2)
  - **Status:** RED - `createAgent` does not process tools param
  - **Verifies:** Agent creation with advanced tools tier

- **[P1] testCreateAgent_allTools_createsAgent** - Verifies agent creation succeeds with `--tools all` (AC#3)
  - **Status:** RED - `createAgent` does not process tools param
  - **Verifies:** Agent creation with all tools tier

### Unit Tests: REPLLoopTests.swift additions (3 tests)

**File:** `Tests/OpenAgentCLITests/REPLLoopTests.swift` (appended)

- **[P0] testREPLLoop_toolsCommand_displaysLoadedTools** - Verifies `/tools` outputs loaded tool names (AC#5)
  - **Status:** RED - REPLLoop does not accept toolNames parameter, no `/tools` command
  - **Verifies:** `/tools` command displays sorted tool names

- **[P1] testREPLLoop_toolsCommand_sortedAlphabetically** - Verifies `/tools` output is alphabetically sorted (AC#5)
  - **Status:** RED - `/tools` command not implemented
  - **Verifies:** Tool names appear in alphabetical order

- **[P2] testREPLLoop_toolsCommand_emptyList_showsNoToolsMessage** - Verifies `/tools` with no tools shows "No tools loaded" message (AC#5 edge)
  - **Status:** RED - `/tools` command not implemented
  - **Verifies:** Empty tool list handled gracefully

---

## Test Strategy

### Mode: AI Generation (backend Swift project)

- No browser/E2E tests needed (CLI project)
- All tests are unit-level using XCTest
- Tests use existing mock patterns (MockInputReader, MockTextOutputStream)
- Tests call `AgentFactory.mapToolTier()` static method directly
- Tests verify tool pool composition via `assembleToolPool`

### Priority Mapping

| Priority | Count | Coverage |
|----------|-------|----------|
| P0 | 7 | AC#1, AC#2, AC#3, AC#4, AC#5, AC#6, AC#7 core paths |
| P1 | 5 | Edge cases, deny precedence, sorted output |
| P2 | 1 | Empty tools edge case |
| P3 | 0 | (none needed) |
| **Total** | **13** | |

### Acceptance Criteria Coverage Matrix

| AC | Tests | Priority |
|----|-------|----------|
| AC#1: Default core tools | testMapToolTier_core_returnsTenTools, testMapToolTier_core_containsExpectedToolNames, testCreateAgent_defaultTools_loadsCoreTools | P0 |
| AC#2: Advanced tools | testMapToolTier_advanced_returnsCoreTools, testCreateAgent_advancedTools_createsAgent | P0/P1 |
| AC#3: All tools | testMapToolTier_all_returnsCoreAndSpecialist, testCreateAgent_allTools_createsAgent | P0/P1 |
| AC#4: Specialist tools | testMapToolTier_specialist_returnsSpecialistTools | P0 |
| AC#5: /tools command | testREPLLoop_toolsCommand_displaysLoadedTools, testREPLLoop_toolsCommand_sortedAlphabetically, testREPLLoop_toolsCommand_emptyList_showsNoToolsMessage | P0/P1/P2 |
| AC#6: --tool-allow | testCreateAgent_toolAllow_filtersToAllowedOnly | P0 |
| AC#7: --tool-deny | testCreateAgent_toolDeny_excludesDenied, testCreateAgent_toolAllowAndDeny_denyTakesPrecedence | P0/P1 |

---

## Implementation Checklist

### Test: ToolLoadingTests (all 12 tests)

**File:** `Tests/OpenAgentCLITests/ToolLoadingTests.swift`

**Tasks to make these tests pass:**

- [ ] Add `mapToolTier(_:) -> [ToolProtocol]` static method to `AgentFactory.swift`
- [ ] Implement tier mapping: "core" -> `getAllBaseTools(tier: .core)`, etc.
- [ ] Modify `createAgent(from:)` to call `mapToolTier(args.tools)` and `assembleToolPool`
- [ ] Pass assembled `toolPool` to `AgentOptions.tools` parameter
- [ ] Ensure `allowedTools` and `disallowedTools` flow through `assembleToolPool`

**Run test:** `swift test --filter ToolLoadingTests`

### Test: REPLLoop /tools command (3 tests)

**File:** `Tests/OpenAgentCLITests/REPLLoopTests.swift`

**Tasks to make these tests pass:**

- [ ] Add `toolNames: [String]` property to `REPLLoop` struct
- [ ] Update `REPLLoop.init` to accept `toolNames` parameter (default: `[]`)
- [ ] Add `/tools` case in `handleSlashCommand` switch
- [ ] Update `CLI.swift` to extract tool names and pass to `REPLLoop`
- [ ] Display format: sorted alphabetically, one per line, with count header

**Run test:** `swift test --filter REPLLoopTests`

---

## Running Tests

```bash
# Run all failing tests for this story
swift test --filter ToolLoadingTests
swift test --filter REPLLoopTests

# Run all project tests (regression)
swift test

# Run specific test
swift test --filter ToolLoadingTests/testMapToolTier_core_returnsTenTools
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

- [x] All 15 tests written and designed to fail
- [x] Tests use existing mock patterns (MockInputReader, MockTextOutputStream)
- [x] Acceptance criteria fully mapped to test scenarios
- [x] Implementation checklist created
- [x] No browser/E2E fixtures needed (backend Swift project)

### GREEN Phase (Next Steps)

1. Pick highest priority failing test (P0)
2. Read the test to understand expected behavior
3. Implement minimal code to make test pass
4. Run test to verify green
5. Move to next test

### REFACTOR Phase (After All Tests Pass)

1. Verify all 192+ existing tests still pass
2. Review tool loading code for quality
3. Extract common patterns if needed
4. Ensure no duplication

---

## Test Execution Evidence

### Initial Test Run (RED Phase Verification)

**Command:** `swift test --filter ToolLoadingTests`

**Results:**

```
ToolLoadingTests.swift:71:34: error: type 'AgentFactory' has no member 'mapToolTier'
ToolLoadingTests.swift:79:34: error: type 'AgentFactory' has no member 'mapToolTier'
ToolLoadingTests.swift:97:34: error: type 'AgentFactory' has no member 'mapToolTier'
ToolLoadingTests.swift:107:38: error: type 'AgentFactory' has no member 'mapToolTier'
ToolLoadingTests.swift:108:44: error: type 'AgentFactory' has no member 'mapToolTier'
ToolLoadingTests.swift:109:37: error: type 'AgentFactory' has no member 'mapToolTier'
ToolLoadingTests.swift:120:34: error: type 'AgentFactory' has no member 'mapToolTier'
ToolLoadingTests.swift:131:34: error: type 'AgentFactory' has no member 'mapToolTier'
ToolLoadingTests.swift:132:38: error: type 'AgentFactory' has no member 'mapToolTier'
REPLLoopTests.swift:474:24: error: extra argument 'toolNames' in call
REPLLoopTests.swift:499:24: error: extra argument 'toolNames' in call
REPLLoopTests.swift:527:24: error: extra argument 'toolNames' in call
error: fatalError
```

**Summary:**

- Total tests: 15 (12 new + 3 appended)
- Passing: 0 (expected - compilation fails due to missing implementation)
- Failing: 15 (expected - all tests RED)
- Status: RED phase verified

**Expected Failure Reasons:**

- ToolLoadingTests: `AgentFactory.mapToolTier()` static method not implemented yet
- REPLLoopTests: `REPLLoop` does not accept `toolNames` parameter, `/tools` command not implemented

---

## Notes

- **Advanced tier is empty:** SDK's `getAllBaseTools(tier: .advanced)` returns `[]`. Tests must account for this.
- **Backward compatibility:** `ParsedArgs.tools` defaults to `"core"` -- already handled by ArgumentParser.
- **Dual filtering:** Both `AgentOptions.allowedTools`/`disallowedTools` AND `assembleToolPool` filtering must be consistent.
- **REPLLoop constructor change:** Adding `toolNames` parameter with default value `[]` preserves existing call sites.
- **192 existing tests must pass** after implementation (regression requirement from AC).
- **Swift compilation model:** Unlike JavaScript's `test.skip()`, Swift tests that reference non-existent methods fail at compile time. This is the correct RED phase behavior for Swift/XCTest.

---

**Generated by BMad TEA Agent (yolo mode)** - 2026-04-20
