---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-24'
workflowType: 'testarch-atdd'
inputDocuments:
  - _bmad-output/implementation-artifacts/9-3-command-history.md
  - _bmad-output/planning-artifacts/epics.md
  - Sources/OpenAgentCLI/REPLLoop.swift
  - Sources/OpenAgentCLI/CLI.swift
  - Package.swift
  - Tests/OpenAgentCLITests/REPLLoopTests.swift
  - Tests/OpenAgentCLITests/ColoredPromptTests.swift
---

# ATDD Checklist - Epic 9, Story 9.3: Command History

**Date:** 2026-04-24
**Author:** TEA Agent
**Primary Test Level:** Unit (Swift/XCTest)
**Stack:** Backend (Swift)
**TDD Phase:** RED (tests will fail until LinenoiseInputReader is implemented)

---

## Story Summary

**As a** user
**I want** to navigate previously entered commands with up/down arrows
**So that** I can quickly repeat or modify previous inputs

---

## Acceptance Criteria

1. **AC#1:** Given I entered 3 messages in current session, When I press up arrow, Then prompt shows last command; up/down navigates history
2. **AC#2:** Given I modify a recalled command and submit, Then the modified text is sent but original history entry is preserved
3. **AC#3:** Given I exit and restart CLI, When I press up arrow, Then previous session's commands are available
4. **AC#4:** Given history file `~/.openagent/history` does not exist, When CLI starts, Then file is auto-created with empty history
5. **AC#5:** Given history file exceeds 1000 entries, When new input is recorded, Then oldest entry is removed (FIFO)
6. **AC#6:** Given history file is corrupted or unreadable, When CLI starts, Then warning is shown but CLI starts normally with empty history

### Additional derived criteria (from Dev Notes)

7. **AC#7 (Ctrl+C):** Given user presses Ctrl+C at input prompt, Then current input is cleared and prompt re-displays (returns empty string "")
8. **AC#8 (Ctrl+D/EOF):** Given user presses Ctrl+D at input prompt, Then REPL exits gracefully (readLine returns nil)
9. **AC#9 (Empty commands):** Given user submits empty input, Then it is NOT added to history

---

## Tests Created (15 tests)

### Unit Tests: CommandHistoryTests (15 tests)

**File:** `Tests/OpenAgentCLITests/CommandHistoryTests.swift`

#### AC#1: Session history navigation (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testLinenoiseInputReader_conformsToInputReadingProtocol | FAIL | LinenoiseInputReader implements InputReading protocol |
| testLinenoiseInputReader_readLineReturnsUserInput | FAIL | readLine(prompt:) returns the line entered by user |

#### AC#3: Cross-session persistence (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testLinenoiseInputReader_savesHistoryAfterSuccessfulRead | FAIL | History is saved to file after each successful read |
| testLinenoiseInputReader_loadsHistoryFromPreviousSession | FAIL | History from file is loaded on init, available for navigation |

#### AC#4: History file auto-creation (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testLinenoiseInputReader_createsDirectoryIfMissing | FAIL | ~/.openagent directory is created if it doesn't exist |
| testLinenoiseInputReader_startsEmptyWhenNoHistoryFile | FAIL | New history file starts empty, no errors thrown |

#### AC#5: History FIFO limit (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testLinenoiseInputReader_historyMaxLengthSetTo1000 | FAIL | History max length is configured to 1000 |
| testLinenoiseInputReader_oldestEntriesRemovedWhenOverLimit | FAIL | When >1000 entries, oldest entries are removed first |

#### AC#6: Corrupted file tolerance (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testLinenoiseInputReader_handlesCorruptedHistoryFile | FAIL | Corrupted history file does not crash, starts with empty history |
| testLinenoiseInputReader_handlesUnreadableHistoryFile | FAIL | Unreadable history file does not crash, starts with empty history |

#### AC#7: Ctrl+C clears input (1 test)

| Test | Status | Description |
|------|--------|-------------|
| testLinenoiseInputReader_ctrlC_returnsEmptyString | FAIL | Ctrl+C returns empty string "" (not nil), REPL re-shows prompt |

#### AC#8: EOF exits gracefully (1 test)

| Test | Status | Description |
|------|--------|-------------|
| testLinenoiseInputReader_eof_returnsNil | FAIL | Ctrl+D/EOF returns nil, REPL exits gracefully |

#### AC#9: Empty commands not added (1 test)

| Test | Status | Description |
|------|--------|-------------|
| testLinenoiseInputReader_emptyLinesNotAddedToHistory | FAIL | Empty strings are not recorded in history |

#### Integration: REPLLoop compatibility (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testREPLLoop_withLinenoiseInputReader_exitsOnNil | FAIL | REPLLoop exits cleanly when LinenoiseInputReader returns nil |
| testREPLLoop_ctrlC_clearsInputAndRedisplaysPrompt | FAIL | Ctrl+C (empty string) is ignored by REPLLoop, prompt reappears |

---

## Test Execution Plan

### RED Phase Verification

**Command:** `swift test --filter CommandHistoryTests`

Tests will fail because:
- `LinenoiseInputReader` class does not exist yet
- `Package.swift` does not include linenoise-swift dependency

**Expected result:** 15/15 FAIL (compilation errors) -- RED phase confirmed.

### GREEN Phase (After Implementation)

1. Add linenoise-swift dependency to Package.swift
2. Create `LinenoiseInputReader.swift` in Sources/OpenAgentCLI/
3. Replace `FileHandleInputReader()` in CLI.swift (2 locations)
4. Run: `swift test --filter CommandHistoryTests`
5. Verify all 15 tests pass
6. Run: `swift test` (full regression)

---

## Implementation Checklist

### Task 1: Add linenoise-swift SPM dependency

**Source:** `Package.swift`

- [ ] Add `.package(url: "https://github.com/andybest/linenoise-swift", branch: "master")` to dependencies
- [ ] Add `.product(name: "LineNoise", package: "linenoise-swift")` to OpenAgentCLI target dependencies
- [ ] Run `swift package resolve` to confirm dependency resolution

### Task 2: Create LinenoiseInputReader.swift

**Source:** `Sources/OpenAgentCLI/LinenoiseInputReader.swift`

- [ ] Implement `InputReading` protocol
- [ ] Initialize `LineNoise` instance with history max length 1000
- [ ] Set history file path to `~/.openagent/history`
- [ ] Create directory `~/.openagent` if missing
- [ ] Load history on init (silently handle failure)
- [ ] Save history after each successful non-empty read
- [ ] Catch `LinenoiseError.CTRL_C` -> return empty string ""
- [ ] Catch `LinenoiseError.EOF` -> return nil
- [ ] Skip empty lines from history

### Task 3: Replace FileHandleInputReader in CLI.swift

**Source:** `Sources/OpenAgentCLI/CLI.swift`

- [ ] Replace at line 127 (skill REPL branch)
- [ ] Replace at line 179 (main REPL branch)

---

## Key Findings

1. **InputReading protocol is stable** -- Only one method: `readLine(prompt:) -> String?`. LinenoiseInputReader just needs to conform.

2. **MockInputReader pattern is established** -- Existing REPLLoop tests use MockInputReader. New tests for LinenoiseInputReader focus on its specific behavior (Ctrl+C, EOF, history). REPLLoop integration tests verify compatibility.

3. **Two Ctrl+C scenarios** -- linenoise handles Ctrl+C at input prompt (returns "" for REPLLoop to ignore). SignalHandler handles Ctrl+C during streaming. These are separate concerns that should not conflict.

4. **History persistence is testable** -- Use temp directories to create/destroy history files, testing load/save cycles without affecting real ~/.openagent/history.

5. **linenoise-swift uses swift-tools-version:4.0** -- Compatible with this project's swift-tools-version:6.1 via SPM backward compatibility.

6. **FileHandleInputReader stays** -- It remains in codebase for non-interactive modes. Only REPL branches are swapped.

---

**Generated by BMad TEA Agent** - 2026-04-24
