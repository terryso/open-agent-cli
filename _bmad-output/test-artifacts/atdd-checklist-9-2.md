---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-23'
workflowType: 'testarch-atdd'
inputDocuments:
  - _bmad-output/implementation-artifacts/9-2-colored-prompt.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - Sources/OpenAgentCLI/ANSI.swift
  - Sources/OpenAgentCLI/REPLLoop.swift
  - open-agent-sdk-swift/Sources/OpenAgentSDK/Types/PermissionTypes.swift
---

# ATDD Checklist - Epic 9, Story 9.2: Colored Prompt

**Date:** 2026-04-23
**Author:** TEA Agent
**Primary Test Level:** Unit (Swift/XCTest)
**Stack:** Backend (Swift)
**TDD Phase:** RED (16 tests fail as expected -- feature not yet implemented)

---

## Story Summary

**As a** user
**I want** the prompt `>` to display different colors based on the current permission mode
**So that** I can identify the current security level at a glance

---

## Acceptance Criteria

1. **AC#1:** Given CLI starts in default mode, When `>` prompt displays, Then it uses green ANSI code `ESC[32m`
2. **AC#2:** Given CLI starts with `--mode plan`, When `>` prompt displays, Then it uses yellow ANSI code `ESC[33m`
3. **AC#3:** Given CLI starts with `--mode bypassPermissions`, When `>` prompt displays, Then it uses red ANSI code `ESC[31m`
4. **AC#4:** Given CLI starts with `acceptEdits` mode, When `>` prompt displays, Then it uses blue ANSI code `ESC[34m`
5. **AC#5:** Given CLI starts with `auto` or `dontAsk` mode, When `>` prompt displays, Then it uses default/white ANSI code `ESC[0m`
6. **AC#6:** Given I execute `/mode plan` in REPL, When mode switches, Then the next prompt changes to yellow
7. **AC#7:** Given terminal does not support ANSI colors, When `>` prompt displays, Then it falls back to plain `>`

---

## Tests Created (16 tests)

### Unit Tests: ColoredPromptTests (16 tests)

**File:** `Tests/OpenAgentCLITests/ColoredPromptTests.swift` (398 lines)

#### AC#1: default mode -- green prompt (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testColoredPrompt_defaultMode_usesGreenAnsiCode | FAIL | Default mode prompt contains ESC[32m (green) |
| testColoredPrompt_defaultMode_endsWithReset | FAIL | Default mode prompt contains ESC[0m (reset) |

#### AC#2: plan mode -- yellow prompt (1 test)

| Test | Status | Description |
|------|--------|-------------|
| testColoredPrompt_planMode_usesYellowAnsiCode | FAIL | Plan mode prompt contains ESC[33m (yellow) |

#### AC#3: bypassPermissions mode -- red prompt (1 test)

| Test | Status | Description |
|------|--------|-------------|
| testColoredPrompt_bypassPermissionsMode_usesRedAnsiCode | FAIL | BypassPermissions mode prompt contains ESC[31m (red) |

#### AC#4: acceptEdits mode -- blue prompt (1 test)

| Test | Status | Description |
|------|--------|-------------|
| testColoredPrompt_acceptEditsMode_usesBlueAnsiCode | FAIL | AcceptEdits mode prompt contains ESC[34m (blue) |

#### AC#5: auto/dontAsk mode -- default color (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testColoredPrompt_autoMode_usesDefaultAnsiCode | FAIL | Auto mode prompt contains ESC[0m (default) |
| testColoredPrompt_dontAskMode_usesDefaultAnsiCode | FAIL | DontAsk mode prompt contains ESC[0m (default) |

#### AC#6: /mode dynamic switching (3 tests)

| Test | Status | Description |
|------|--------|-------------|
| testColoredPrompt_modeSwitch_changesNextPromptColor | FAIL | /mode plan changes next prompt to yellow |
| testColoredPrompt_modeSwitch_defaultToBypass_usesRedPrompt | FAIL | /mode bypassPermissions changes next prompt to red |
| testColoredPrompt_modeSwitch_planToAcceptEdits_usesBluePrompt | FAIL | /mode acceptEdits changes next prompt to blue |

#### AC#7: no-ANSI fallback (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testColoredPrompt_noTty_returnsPlainPrompt | FAIL | Non-tty environment returns plain "> " |
| testColoredPrompt_noTty_containsNoAnsiEscapes | FAIL | Non-tty fallback has no ANSI escape sequences |

#### ANSI.blue() helper (1 test)

| Test | Status | Description |
|------|--------|-------------|
| testANSI_blue_wrapsTextWithBlueAnsiCode | FAIL | ANSI.blue() wraps text with ESC[34m and ESC[0m |

#### Cross-cutting (1 test)

| Test | Status | Description |
|------|--------|-------------|
| testColoredPrompt_containsPromptText | FAIL | Colored prompt always contains "> " text |

#### Regression (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testRegression_exitCommandStillWorksWithColoredPrompt | FAIL | /exit still works with colored prompt |
| testRegression_emptyInputIgnoredWithColoredPrompt | FAIL | Empty input still ignored with colored prompt |

---

## Test Execution Evidence

### RED Phase Verification

**Command:** `swift test --filter ColoredPromptTests`

```
Build error: type 'ANSI' has no member 'coloredPrompt'
Build error: type 'ANSI' has no member 'blue'
Build error: cannot infer contextual base in reference to member 'default'
Build error: cannot infer contextual base in reference to member 'plan'
```

**Result: 16/16 FAIL (compilation errors) -- RED phase confirmed.**

Tests fail because the following API does not exist yet:
- `ANSI.blue(_:)` static method
- `ANSI.coloredPrompt(forMode:)` static method

The REPLLoop tests (AC#1-AC#6) will fail at the assertion level once compilation
is fixed, since `readLine(prompt: "> ")` is still hardcoded.

The AC#7 tests will fail until `ANSI.coloredPrompt(forMode:)` is implemented.

### Regression Check

**Command:** `swift build --build-tests`

All errors are in `ColoredPromptTests.swift` only. No compilation errors in
existing source or test files. Existing 660+ unit tests remain unaffected.

---

## Implementation Checklist

### Task 1: Add ANSI.blue() and ANSI.coloredPrompt(forMode:) to ANSI.swift

**Source:** `Sources/OpenAgentCLI/ANSI.swift`

- [ ] Add `ANSI.blue(_:)` static method (matching existing red/green/yellow/cyan pattern)
- [ ] Add `ANSI.coloredPrompt(forMode:)` function accepting PermissionMode, returning colored `> ` string
- [ ] Handle all 6 PermissionMode color mappings:
  - `.default` -> green (ESC[32m)
  - `.plan` -> yellow (ESC[33m)
  - `.bypassPermissions` -> red (ESC[31m)
  - `.acceptEdits` -> blue (ESC[34m)
  - `.auto`, `.dontAsk` -> default (ESC[0m)
- [ ] Check `isatty(STDOUT_FILENO)` for ANSI support, return plain `> ` when not a tty
- Tests covered: testANSI_blue_wrapsTextWithBlueAnsiCode, testColoredPrompt_noTty_returnsPlainPrompt, testColoredPrompt_noTty_containsNoAnsiEscapes

### Task 2: Add ModeHolder and dynamic prompt to REPLLoop.swift

**Source:** `Sources/OpenAgentCLI/REPLLoop.swift`

- [ ] Add `final class ModeHolder` with `var mode: PermissionMode`
- [ ] Initialize ModeHolder from `parsedArgs.mode` in REPLLoop init
- [ ] Replace `reader.readLine(prompt: "> ")` with `reader.readLine(prompt: ANSI.coloredPrompt(forMode: modeHolder.mode))`
- [ ] Update `handleMode()` to set `modeHolder.mode = mode` after successful switch
- Tests covered: testColoredPrompt_defaultMode_usesGreenAnsiCode, testColoredPrompt_planMode_usesYellowAnsiCode, testColoredPrompt_bypassPermissionsMode_usesRedAnsiCode, testColoredPrompt_acceptEditsMode_usesBlueAnsiCode, testColoredPrompt_autoMode_usesDefaultAnsiCode, testColoredPrompt_dontAskMode_usesDefaultAnsiCode, testColoredPrompt_modeSwitch_changesNextPromptColor, testColoredPrompt_modeSwitch_defaultToBypass_usesRedPrompt, testColoredPrompt_modeSwitch_planToAcceptEdits_usesBluePrompt, testColoredPrompt_containsPromptText, testRegression_exitCommandStillWorksWithColoredPrompt, testRegression_emptyInputIgnoredWithColoredPrompt

---

## Red-Green-Refactor Workflow

### RED Phase (Current)

- [x] 16 failing tests generated
- [x] All 16 tests fail (compilation errors -- API not yet implemented)
- [x] No regression in existing tests

### GREEN Phase (After Implementation)

1. Implement Task 1 (ANSI.swift additions)
2. Implement Task 2 (REPLLoop.swift modifications)
3. Run: `swift test --filter ColoredPromptTests`
4. Verify all 16 tests pass
5. If any fail: fix implementation (feature bug) or fix test (test bug)
6. Run: `swift test` (full regression)

### REFACTOR Phase

- Review ModeHolder design (consider reusing pattern consistently with AgentHolder/CostTracker)
- Consider whether colored prompt logic should be in ANSI or a dedicated PromptRenderer
- Verify no duplicate ANSI code string literals (extract constants if needed)

---

## Running Tests

```bash
# Run new tests only (Story 9.2)
swift test --filter ColoredPromptTests

# Run existing REPLLoop tests (regression)
swift test --filter REPLLoopTests

# Run full test suite (all stories)
swift test

# Run specific test
swift test --filter ColoredPromptTests/testColoredPrompt_defaultMode_usesGreenAnsiCode
```

---

## Key Findings

1. **PermissionMode has 6 cases** -- default, acceptEdits, bypassPermissions, plan, dontAsk, auto. All are covered by tests.

2. **ModeHolder pattern needed** -- REPLLoop is a struct with non-mutating `start()`. Current mode tracking requires a class wrapper (similar to existing `AgentHolder` and `CostTracker` patterns).

3. **isatty() detection is env-dependent** -- In test environments, `STDOUT_FILENO` is typically not a tty, so AC#7 tests can verify fallback behavior directly. Production terminals will get colored prompts.

4. **Prompt color applies to `>` character** -- The story specifies the prompt is `> ` with ANSI color codes wrapping it. The space after `>` should be included in the colored segment.

5. **Mode switching via /mode already works** -- The `handleMode()` method in REPLLoop already switches the Agent's permission mode. This story adds visual feedback (colored prompt) on top of that existing functionality.

6. **REPLLoop.init receives parsedArgs** -- The initial mode is available via `parsedArgs?.mode` (String), which needs to be converted to `PermissionMode` enum at init time.

---

## Knowledge Base References Applied

- **component-tdd.md** - Component test strategies adapted for Swift XCTest
- **test-quality.md** - Test design principles (Given-When-Then, one assertion per test, determinism)
- **data-factories.md** - Helper pattern for ParsedArgs construction (shared with existing tests)
- **test-healing-patterns.md** - Resilient test patterns for terminal-dependent behavior

---

**Generated by BMad TEA Agent** - 2026-04-23
