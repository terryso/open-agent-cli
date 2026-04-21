---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-21'
workflowType: 'testarch-atdd'
inputDocuments:
  - _bmad-output/implementation-artifacts/7-1-pipe-stdin-input-mode.md
  - _bmad-output/planning-artifacts/epics.md
---

# ATDD Checklist - Epic 7, Story 7.1: Pipe/Stdin Input Mode

**Date:** 2026-04-21
**Author:** Nick
**Primary Test Level:** Unit + Integration (backend Swift project)

---

## Story Summary

Story 7.1 adds pipe/stdin input mode to the CLI. Users can pipe input to the CLI via `echo "explain this" | openagent --stdin`, enabling shell script integration and pipeline composition.

**As a** user
**I want** to pipe input to the CLI via stdin
**So that** I can integrate it into shell scripts and pipelines

---

## Acceptance Criteria

1. **AC#1:** Given stdin piped input, when running `echo "explain this" | openagent --stdin`, then CLI reads and processes stdin input
2. **AC#2:** Given both stdin and positional argument, when CLI starts, then positional argument takes priority
3. **AC#3:** Given `--stdin` flag with empty stdin, when CLI starts, then CLI prints error to stderr and exits with non-zero code
4. **AC#4:** Given `--stdin` flag with multiline stdin content, when CLI starts, then all lines are joined as a single prompt (newline-joined)

---

## Generation Mode

**Mode:** AI Generation (backend Swift project, no browser recording needed)

**Rationale:** The story modifies ArgumentParser (adds --stdin flag) and CLI.swift (adds stdin reading logic). All testing is at the unit and integration level using XCTest. No UI/E2E browser testing is applicable.

---

## Test Strategy

### Test Level Selection

This is a **backend** Swift CLI project. The appropriate test levels are:

- **Unit tests** for ArgumentParser flag parsing (fast, isolated)
- **Integration tests** for CLI stdin reading behavior (requires FileHandle interaction)
- **No E2E/browser tests** (no web UI)

### Acceptance Criteria to Test Mapping

| AC | Test Level | Test Scenarios |
|----|-----------|---------------|
| AC#1 | Unit | `--stdin` flag parsed correctly; help message includes `--stdin` |
| AC#1 | Unit | `--stdin` coexists with other flags |
| AC#2 | Unit | Positional arg + `--stdin`: positional takes priority |
| AC#3 | Unit | `--stdin` with no positional arg: prompt is nil (stdin fills it at CLI level) |
| AC#4 | Integration | Multiline stdin content joined (CLI-level, requires process testing) |
| Regression | Unit | `--stdin` absent: existing behavior unchanged |

### Priority Assignment

- **P0:** AC#1 (--stdin flag parsing), AC#2 (positional priority)
- **P1:** AC#3 (empty stdin error), AC#4 (multiline join)
- **P2:** Flag combinations (`--stdin --quiet`, `--stdin --output json`)
- **P3:** Regression tests (no --stdin = no change)

---

## Failing Tests Created (RED Phase)

### Unit Tests (14 tests)

**File:** `Tests/OpenAgentCLITests/StdinInputTests.swift` (~180 lines)

- **Test:** `testStdinFlag_setsStdinProperty`
  - **Status:** RED - `ParsedArgs` does not have `stdin` property yet
  - **Verifies:** AC#1 -- `--stdin` sets `ParsedArgs.stdin = true`

- **Test:** `testStdinFlag_inHelpMessage`
  - **Status:** RED - `generateHelpMessage()` does not include `--stdin`
  - **Verifies:** AC#1 -- help message lists `--stdin`

- **Test:** `testStdinFlag_defaultIsFalse`
  - **Status:** RED - `ParsedArgs` does not have `stdin` property yet
  - **Verifies:** AC#1 -- default `stdin = false`

- **Test:** `testStdinFlag_withOtherFlags`
  - **Status:** RED - `ParsedArgs.stdin` does not exist
  - **Verifies:** AC#1 -- `--stdin` coexists with `--model`, `--quiet`

- **Test:** `testPositionalArg_prioritizedOverStdinFlag`
  - **Status:** RED - `ParsedArgs.stdin` does not exist
  - **Verifies:** AC#2 -- positional arg takes priority over stdin

- **Test:** `testPositionalArg_beforeStdinFlag`
  - **Status:** RED - `ParsedArgs.stdin` does not exist
  - **Verifies:** AC#2 -- priority works regardless of argument order

- **Test:** `testStdinFlag_withNoPromptAndNoPositionalArg_promptIsNil`
  - **Status:** RED - `ParsedArgs.stdin` does not exist
  - **Verifies:** AC#3 pre-condition -- prompt nil when only `--stdin`

- **Test:** `testStdinWithQuietMode_flagParsing`
  - **Status:** RED - `ParsedArgs.stdin` does not exist
  - **Verifies:** AC#1 -- `--stdin --quiet` combination

- **Test:** `testStdinWithJsonOutput_flagParsing`
  - **Status:** RED - `ParsedArgs.stdin` does not exist
  - **Verifies:** AC#1 -- `--stdin --output json` combination

- **Test:** `testStdinWithModelAndMode_flagParsing`
  - **Status:** RED - `ParsedArgs.stdin` does not exist
  - **Verifies:** AC#1 -- `--stdin` with `--model`, `--mode`, `--max-turns`

- **Test:** `testNoStdinFlag_noStdinRead_promptUnaffected`
  - **Status:** RED - `ParsedArgs.stdin` does not exist
  - **Verifies:** Regression -- no `--stdin` = existing behavior

- **Test:** `testNoStdinFlag_replMode_promptNil`
  - **Status:** RED - `ParsedArgs.stdin` does not exist
  - **Verifies:** Regression -- REPL mode unchanged

- **Test:** `testStdinFlag_notInBooleanFlagsCausesError`
  - **Status:** RED - `ParsedArgs.stdin` does not exist
  - **Verifies:** Edge case -- `--stdin` recognized as valid flag

- **Test:** `testCLI_hasReadStdinMethod`
  - **Status:** RED - `ParsedArgs.stdin` does not exist
  - **Verifies:** Infrastructure -- ParsedArgs has mutable stdin property

---

## Data Factories Created

N/A -- This story uses `ParsedArgs` directly (no complex data factories needed).

---

## Fixtures Created

N/A -- Tests use inline `ArgumentParser.parse()` calls with no shared fixtures needed.

---

## Mock Requirements

N/A -- ArgumentParser tests are pure unit tests. CLI-level stdin tests would require process piping, which is outside the scope of unit tests.

---

## Required data-testid Attributes

N/A -- This is a CLI project with no browser UI.

---

## Implementation Checklist

### Test: testStdinFlag_setsStdinProperty

**File:** `Tests/OpenAgentCLITests/StdinInputTests.swift`

**Tasks to make this test pass:**

- [ ] Add `var stdin: Bool = false` property to `ParsedArgs` struct in `ArgumentParser.swift`
- [ ] Add `"--stdin"` to the `booleanFlags` set in `ArgumentParser.swift`
- [ ] Add `--stdin` case to the `parse()` method's boolean flag handling block
- [ ] Run test: `swift test --filter StdinInputTests/testStdinFlag_setsStdinProperty`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.25 hours

---

### Test: testStdinFlag_inHelpMessage

**File:** `Tests/OpenAgentCLITests/StdinInputTests.swift`

**Tasks to make this test pass:**

- [ ] Add `--stdin` description line to `generateHelpMessage()` in the "Interaction Options" section
- [ ] Example: `  --stdin                  Read prompt from standard input (pipe mode)`
- [ ] Run test: `swift test --filter StdinInputTests/testStdinFlag_inHelpMessage`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.1 hours

---

### Test: testPositionalArg_prioritizedOverStdinFlag (and AC#2 tests)

**File:** `Tests/OpenAgentCLITests/StdinInputTests.swift`

**Tasks to make this test pass:**

- [ ] Same as testStdinFlag_setsStdinProperty (ParsedArgs.stdin + booleanFlags + parse)
- [ ] Verify positional arg parsing still works when --stdin is present
- [ ] Run test: `swift test --filter StdinInputTests/testPositionalArg_prioritizedOverStdinFlag`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.1 hours (covered by base implementation)

---

### Test: testCLI_hasReadStdinMethod (and AC#3, AC#4 CLI-level tests)

**File:** `Tests/OpenAgentCLITests/StdinInputTests.swift`

**Tasks to make this test pass:**

- [ ] In `CLI.swift`, add stdin reading logic after `ConfigLoader.apply()` and before dispatch
- [ ] Add `readStdin()` private static method using `FileHandle.standardInput.readDataToEndOfFile()`
- [ ] Add stdin dispatch logic: if `args.stdin && args.prompt == nil`, read stdin into `args.prompt`
- [ ] Handle empty stdin: write error to stderr, `Foundation.exit(1)` (AC#3)
- [ ] Multiline content is automatically handled (readDataToEndOfFile reads all)
- [ ] Run test: `swift test --filter StdinInputTests/testCLI_hasReadStdinMethod`
- [ ] Test passes (green phase)

**Estimated Effort:** 0.5 hours

---

### All remaining tests (flag combinations, regression)

**File:** `Tests/OpenAgentCLITests/StdinInputTests.swift`

**Tasks to make these tests pass:**

- [ ] All covered by the base --stdin flag implementation in ArgumentParser
- [ ] Run test: `swift test --filter StdinInputTests`
- [ ] All tests pass (green phase)

**Estimated Effort:** 0.1 hours (covered by base implementation)

---

## Running Tests

```bash
# Run all failing tests for this story
swift test --filter StdinInputTests

# Run specific test
swift test --filter StdinInputTests/testStdinFlag_setsStdinProperty

# Run with verbose output
swift test --filter StdinInputTests 2>&1 | tee test-output.txt

# Run all tests (regression check)
swift test
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**

- All tests written and failing
- No fixtures or factories needed (pure ArgumentParser unit tests)
- Mock requirements documented (N/A for this story)
- Implementation checklist created

**Verification:**

- Tests fail due to missing `ParsedArgs.stdin` property
- Failure messages are clear: "value of type 'ParsedArgs' has no member 'stdin'"
- Tests fail due to missing implementation, not test bugs

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. **Add `stdin` property to ParsedArgs** (makes ~13 tests pass)
2. **Add `--stdin` to booleanFlags and parse()** (same change)
3. **Add `--stdin` to help message** (makes 1 test pass)
4. **Add stdin reading logic in CLI.swift** (makes 1 test pass, covers AC#3, AC#4)
5. **Run `swift test --filter StdinInputTests`** to verify all pass
6. **Run `swift test`** for full regression

**Key Principles:**

- Start with ArgumentParser changes (quick wins, 13 tests)
- Then add help message update (1 test)
- Then add CLI.swift stdin reading (covers AC#3, AC#4)
- Run tests after each change

---

### REFACTOR Phase (DEV Team - After All Tests Pass)

1. Verify all tests pass
2. Review stdin reading logic for edge cases (encoding, very large input)
3. Ensure no code duplication with existing single-shot dispatch
4. Run full test suite for regression

---

## Next Steps

1. **Review this checklist** with team
2. **Run failing tests** to confirm RED phase: `swift test --filter StdinInputTests`
3. **Begin implementation** using implementation checklist as guide
4. **Start with ArgumentParser changes** (P0, covers most tests)
5. **Then add CLI.swift stdin reading** (covers AC#3, AC#4)
6. **When all tests pass**, refactor code for quality
7. **When refactoring complete**, update story status to 'done' in sprint-status.yaml

---

## Knowledge Base References Applied

- **test-quality.md** - Test design principles (one assertion per test group, determinism, isolation)
- **test-levels-framework.md** - Test level selection (backend = unit + integration, no E2E)
- **component-tdd.md** - TDD red phase: tests must fail for the right reason (missing implementation)

---

## Notes

- **Swift/XCTest** testing framework (not Playwright/Jest)
- **FileHandle.standardInput** cannot be easily mocked in unit tests; AC#3 and AC#4 (empty stdin, multiline) are primarily verified through the CLI implementation logic, with integration testing done via process execution
- The story specifies `--stdin` flag as explicit opt-in (no auto-detection via `isatty()`)
- Stdin content goes through the existing single-shot path via `args.prompt` -- no new execution path needed
- Total estimated implementation effort: ~1 hour

---

**Generated by BMad TEA Agent** - 2026-04-21
