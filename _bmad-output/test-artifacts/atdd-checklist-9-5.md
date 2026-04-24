---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-24'
workflowType: 'testarch-atdd'
inputDocuments:
  - _bmad-output/implementation-artifacts/9-5-multiline-input.md
  - _bmad-output/planning-artifacts/epics.md
  - Sources/OpenAgentCLI/REPLLoop.swift
  - Sources/OpenAgentCLI/ANSI.swift
  - Sources/OpenAgentCLI/LinenoiseInputReader.swift
  - Tests/OpenAgentCLITests/REPLLoopTests.swift
  - Tests/OpenAgentCLITests/ColoredPromptTests.swift
  - Tests/OpenAgentCLITests/REPLLoopInterruptTests.swift
---

# ATDD Checklist - Epic 9, Story 9.5: Multiline Input

**Date:** 2026-04-24
**Author:** TEA Agent
**Primary Test Level:** Unit (Swift/XCTest)
**Stack:** Backend (Swift)
**TDD Phase:** RED (tests will fail until multiline state machine is implemented)

---

## Story Summary

**As a** user
**I want** to use `\` continuation or `"""` delimiters to enter multiline text
**So that** I can conveniently paste code or multi-paragraph prompts

---

## Acceptance Criteria

1. **AC#1:** Backslash continuation — `\` at end of line enters continuation mode with `...>` prompt; lines merged with `\n`
2. **AC#2:** Triple-quote mode — `"""` enters multiline mode; content between delimiters sent as one input with preserved newlines
3. **AC#3:** Ctrl+C cancel — in multiline mode (`...>` prompt), Ctrl+C clears buffer and returns to `>` prompt
4. **AC#4:** Trailing whitespace tolerance — `\` followed by trailing whitespace is still recognized as continuation

---

## Tests Created (25 tests)

### Unit Tests: MultilineInputTests (25 tests)

**File:** `Tests/OpenAgentCLITests/MultilineInputTests.swift`

#### AC#1: Backslash continuation (3 tests)

| Test | Status | Description |
|------|--------|-------------|
| testBackslashContinuation_twoLines_mergedAndSent | FAIL | `hello \` + `world` → merged and sent as one query |
| testBackslashContinuation_threeSegments_mergedCorrectly | FAIL | 3 continuation segments merged with correct prompts |
| testBackslashContinuation_stripsTrailingBackslash | FAIL | Trailing `\` is stripped from merged content |

#### AC#2: Triple-quote multiline mode (5 tests)

| Test | Status | Description |
|------|--------|-------------|
| testTripleQuote_capturesMultilineContent | FAIL | `"""` delimiters capture content between them |
| testTripleQuote_preservesNewlines | FAIL | Newlines in triple-quote content are preserved |
| testTripleQuote_preservesIndentation | FAIL | Original indentation is preserved |
| testTripleQuote_emptyContent_filtered | FAIL | Empty `"""` immediately followed by `"""` is filtered |

#### AC#3: Ctrl+C cancel multiline (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testCtrlC_cancelsBackslashContinuation | FAIL | Ctrl+C during `\` continuation clears buffer |
| testCtrlC_cancelsTripleQuoteMode | FAIL | Ctrl+C during triple-quote mode clears buffer |

#### AC#4: Trailing whitespace tolerance (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testTrailingWhitespace_treatedAsContinuation | FAIL | `hello \  ` (spaces after `\`) triggers continuation |
| testTrailingWhitespace_mixedTabsAndSpaces | FAIL | Mixed whitespace after `\` triggers continuation |

#### Edge cases (3 tests)

| Test | Status | Description |
|------|--------|-------------|
| testBareBackslash_notTreatedAsContinuation | FAIL | Lone `\` on a line is normal input, not continuation |
| testBackslashContinuation_emptyLineContinues | FAIL | Empty line in continuation continues accumulating |
| testTripleQuote_emptyLinesInContent | FAIL | Empty lines within `"""` are preserved as content |

#### Continuation prompt colors (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testContinuationPrompt_defaultMode_isGreen | FAIL | `...>` prompt uses green in default mode |
| testContinuationPrompt_planMode_isYellow | FAIL | `...>` prompt uses yellow in plan mode |

#### ANSI.coloredContinuationPrompt unit tests (6 tests)

| Test | Status | Description |
|------|--------|-------------|
| testANSI_coloredContinuationPrompt_defaultMode_green | COMPILE ERROR | Green `...>` in default mode |
| testANSI_coloredContinuationPrompt_planMode_yellow | COMPILE ERROR | Yellow `...>` in plan mode |
| testANSI_coloredContinuationPrompt_bypassPermissions_red | COMPILE ERROR | Red `...>` in bypassPermissions mode |
| testANSI_coloredContinuationPrompt_acceptEdits_blue | COMPILE ERROR | Blue `...>` in acceptEdits mode |
| testANSI_coloredContinuationPrompt_autoMode_noColor | COMPILE ERROR | Plain `...>` in auto mode (no ANSI) |
| testANSI_coloredContinuationPrompt_noTty_returnsPlain | COMPILE ERROR | No-tty fallback returns plain `...>` |

#### Regression (3 tests)

| Test | Status | Description |
|------|--------|-------------|
| testRegression_exitStillWorksWithMultilineStateMachine | FAIL | `/exit` still works |
| testRegression_normalInputStillWorks | FAIL | Single-line input unchanged |
| testRegression_emptyInputAtMainPromptIgnored | FAIL | Empty input at main prompt still ignored |

---

## Test Execution Plan

### RED Phase Verification

**Command:** `swift test --filter MultilineInputTests`

Tests will fail because:
- `ANSI.coloredContinuationPrompt(forMode:forceColor:)` does not exist (6 compile errors)
- `REPLLoop.start()` has no multiline state machine (19 runtime failures)

**Expected result:** 25/25 FAIL (6 compilation errors + 19 runtime failures) -- RED phase confirmed.

### GREEN Phase (After Implementation)

1. Add `coloredContinuationPrompt(forMode:forceColor:)` to `ANSI.swift` (~15 lines)
2. Add multiline state machine to `REPLLoop.start()` (~60 lines)
3. Extract `processInput()` helper from `start()` (~50 lines)
4. Run: `swift test --filter MultilineInputTests`
5. Verify all 25 tests pass
6. Run: `swift test` (full regression -- 800+ tests)

---

## Implementation Checklist

### Task 1: Add multiline state machine to REPLLoop.start()

**Source:** `Sources/OpenAgentCLI/REPLLoop.swift`

- [ ] Add `var multilineBuffer: [String] = []` in `start()`
- [ ] Add `var inMultiline = false` in `start()`
- [ ] Add `var inTripleQuote = false` in `start()`
- [ ] Replace single-line input logic with multiline state machine
- [ ] Implement `\` continuation detection: `rstripped.hasSuffix("\\")` but `trimmed != "\\"`
- [ ] Implement `"""` mode: `trimmed == "\"\"\""` toggles triple-quote state
- [ ] Implement Ctrl+C handling: empty input in multiline mode clears buffer
- [ ] Implement line merging: strip trailing `\`, join with `\n`
- [ ] Implement triple-quote merging: join all lines with `\n`
- [ ] Extract `processInput()` helper method

### Task 2: Add continuation prompt support

**Source:** `Sources/OpenAgentCLI/ANSI.swift`

- [ ] Add `coloredContinuationPrompt(forMode:forceColor:)` static method
- [ ] Use same color mapping as `coloredPrompt` but display `...>` instead of `> `

### Task 3: Wire up continuation prompt in start()

**Source:** `Sources/OpenAgentCLI/REPLLoop.swift`

- [ ] Add helper method `promptForState(inMultiline:inTripleQuote:)` or inline logic
- [ ] Pass continuation prompt to `reader.readLine(prompt:)` when in multiline mode

---

## Key Findings

1. **Two independent multiline modes** -- `inMultiline` (backslash) and `inTripleQuote` (triple-quote) are mutually exclusive. The state machine must handle both independently.

2. **Ctrl+C vs empty line distinction** -- `LinenoiseInputReader.readLine` returns `""` for both Ctrl+C and an empty Enter. The story recommends using `SignalHandler.check()` to distinguish, but also notes this may not work if linenoise intercepts the signal. A `lastWasInterrupt` flag on the reader may be needed as a fallback.

3. **Bare backslash guard** -- A line containing only `\` should NOT trigger continuation. The guard `trimmed != "\\"` prevents this.

4. **Empty lines in continuation** -- In backslash continuation mode, empty lines should continue accumulating (be part of the merged content). In triple-quote mode, empty lines are preserved literally.

5. **Slash commands only processed after merging** -- Multiline content is merged first, then checked for `/` prefix. This prevents mid-continuation lines from being misinterpreted as commands.

6. **Continuation prompt colors match mode** -- The `...>` prompt uses the same color as the `>` prompt for the current permission mode, implemented via `coloredContinuationPrompt`.

7. **No new dependencies** -- The multiline state machine is pure logic within `start()`. No changes to `Package.swift`, `LinenoiseInputReader`, or `TabCompletionProvider`.

---

**Generated by BMad TEA Agent** - 2026-04-24
