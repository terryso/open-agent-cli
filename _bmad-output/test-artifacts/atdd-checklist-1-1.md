---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-19'
workflowType: testarch-atdd
inputDocuments:
  - _bmad-output/implementation-artifacts/1-1-cli-entry-point-and-argument-parser.md
  - _bmad/core/config.yaml
  - Package.swift
  - .claude/skills/bmad-testarch-atdd/resources/knowledge/component-tdd.md
  - .claude/skills/bmad-testarch-atdd/resources/knowledge/test-quality.md
  - .claude/skills/bmad-testarch-atdd/resources/knowledge/test-levels-framework.md
---

# ATDD Checklist - Epic 1, Story 1.1: CLI Entry Point and Argument Parser

**Date:** 2026-04-19
**Author:** Nick (TEA Agent)
**Primary Test Level:** Unit (XCTest)

---

## Story Summary

As a developer, I want a CLI that parses command-line flags and launches the appropriate mode, so that I can configure the agent without editing config files.

**As a** developer
**I want** a CLI that parses command-line flags and launches the appropriate mode
**So that** I can configure the agent without editing config files

---

## Acceptance Criteria

1. **AC#1:** `openagent --help` displays help message showing all flags, exits code 0
2. **AC#2:** `openagent` (no args) enters REPL mode with default settings
3. **AC#3:** `openagent "what is 2+2?"` runs single-shot mode and exits after responding
4. **AC#4:** `openagent --invalid-flag` shows error explaining the flag, exits code 1

---

## Test Strategy

### Stack Detection

- **Detected stack:** `backend` (Swift Package Manager, no frontend dependencies)
- **Test framework:** XCTest (Swift built-in)
- **Test runner:** `swift test`

### Test Level Selection

| Level | Usage | Justification |
|-------|-------|---------------|
| Unit | Primary | `ArgumentParser.parse()` is a pure function: `[String] -> ParsedArgs` |
| Integration | Deferred | CLI.run() integration deferred to Story 1.2 (agent creation) |
| E2E | N/A | No browser-based testing needed for CLI arg parser |

### Priority Assignments

- **P0 (Critical):** Core AC coverage -- help flag, no-args default, single-shot, invalid flag
- **P1 (High):** All individual flag parsing (model, mode, tools, provider, etc.)
- **P2 (Medium):** Validation errors for invalid flag values
- **P3 (Low):** Edge cases (empty args, multiple positional args, flag at end of array)

---

## Failing Tests Created (RED Phase)

### Unit Tests (50 tests)

**File:** `Tests/OpenAgentCLITests/ArgumentParserTests.swift` (473 lines)

#### AC#1: --help flag (3 tests)

- **[P0]** `testHelpFlag_setsHelpRequested` -- Verifies --help sets helpRequested, shouldExit, exitCode=0
  - **Status:** RED - `cannot find 'ArgumentParser' in scope`
  - **Verifies:** AC#1 (help flag behavior)

- **[P0]** `testHelpShortFlag_setsHelpRequested` -- Verifies -h short flag works identically
  - **Status:** RED - `cannot find 'ArgumentParser' in scope`
  - **Verifies:** AC#1 (short flag alias)

- **[P0]** `testHelpFlag_outputContainsUsageLine` -- Verifies help message contains usage, flags
  - **Status:** RED - `cannot find 'ArgumentParser' in scope`
  - **Verifies:** AC#1 (help message content)

#### AC#2: No arguments / REPL mode (2 tests)

- **[P0]** `testNoArgs_defaultsToREPLMode` -- No args = nil prompt, no exit signal
  - **Status:** RED - `cannot find 'ArgumentParser' in scope`
  - **Verifies:** AC#2 (REPL mode detection)

- **[P0]** `testNoArgs_defaultValues` -- Verifies all defaults: model, mode, tools, maxTurns, output, quiet, noRestore
  - **Status:** RED - `cannot find 'ArgumentParser' in scope`
  - **Verifies:** AC#2 (default settings)

#### AC#3: Single-shot mode (2 tests)

- **[P0]** `testPositionalArg_setsSingleShotMode` -- Positional arg = prompt set, no exit signal
  - **Status:** RED - `cannot find 'ArgumentParser' in scope`
  - **Verifies:** AC#3 (single-shot detection)

- **[P1]** `testPositionalArgWithFlags_singleShotMode` -- Positional arg + flags both parsed
  - **Status:** RED - `cannot find 'ArgumentParser' in scope`
  - **Verifies:** AC#3 (single-shot with flags)

#### AC#4: Invalid flags (2 tests)

- **[P0]** `testInvalidFlag_setsError` -- Unknown flag = shouldExit, exitCode=1, error message
  - **Status:** RED - `cannot find 'ArgumentParser' in scope`
  - **Verifies:** AC#4 (error on invalid flag)

- **[P1]** `testInvalidFlag_errorIsActionable` -- Error mentions flag name and suggests --help
  - **Status:** RED - `cannot find 'ArgumentParser' in scope`
  - **Verifies:** AC#4 (actionable error messages)

#### Version flag (2 tests)

- **[P0]** `testVersionFlag_setsVersionRequested` -- --version sets versionRequested, exit 0
- **[P0]** `testVersionShortFlag_setsVersionRequested` -- -v short flag

#### --model flag (2 tests)

- **[P1]** `testModelFlag_parsesValue` -- Model string parsed
- **[P2]** `testModelFlag_missingValue_setsError` -- Missing value = error

#### --mode flag (2 tests)

- **[P1]** `testModeFlag_validValues` -- All 6 valid PermissionMode values accepted
- **[P2]** `testModeFlag_invalidValue_setsError` -- Invalid mode = error

#### --tools flag (2 tests)

- **[P1]** `testToolsFlag_validValues` -- core/advanced/specialist/all accepted
- **[P2]** `testToolsFlag_invalidValue_setsError` -- Invalid tier = error

#### --provider flag (2 tests)

- **[P1]** `testProviderFlag_validValues` -- anthropic/openai accepted
- **[P2]** `testProviderFlag_invalidValue_setsError` -- Invalid provider = error

#### --output flag (2 tests)

- **[P1]** `testOutputFlag_validValues` -- text/json accepted
- **[P2]** `testOutputFlag_invalidValue_setsError` -- Invalid format = error

#### --log-level flag (2 tests)

- **[P1]** `testLogLevelFlag_validValues` -- debug/info/warn/error accepted
- **[P2]** `testLogLevelFlag_invalidValue_setsError` -- Invalid level = error

#### --max-turns flag (3 tests)

- **[P1]** `testMaxTurnsFlag_parsesInt` -- Integer parsed
- **[P2]** `testMaxTurnsFlag_nonPositive_setsError` -- Zero = error
- **[P2]** `testMaxTurnsFlag_nonNumeric_setsError` -- Non-numeric = error

#### --max-budget flag (2 tests)

- **[P1]** `testMaxBudgetFlag_parsesDouble` -- Double parsed
- **[P2]** `testMaxBudgetFlag_nonPositive_setsError` -- Negative = error

#### --thinking flag (2 tests)

- **[P1]** `testThinkingFlag_parsesInt` -- Token budget integer parsed
- **[P2]** `testThinkingFlag_nonPositive_setsError` -- Zero = error

#### Boolean flags (2 tests)

- **[P1]** `testQuietFlag_setsQuiet`
- **[P1]** `testNoRestoreFlag_setsNoRestore`

#### Path/string flags (5 tests)

- **[P1]** `testMcpConfigPathFlag`
- **[P1]** `testHooksConfigPathFlag`
- **[P1]** `testSkillDirFlag`
- **[P1]** `testSkillFlag`
- **[P1]** `testSessionFlag`

#### --system-prompt flag (1 test)

- **[P1]** `testSystemPromptFlag`

#### --api-key resolution (3 tests)

- **[P1]** `testApiKeyFlag_setsApiKey` -- Direct flag value
- **[P1]** `testApiKeyFlag_overridesEnvVar` -- Flag > env var precedence
- **[P1]** `testApiKeyResolution_fromEnvVar` -- Env var fallback
- **[P1]** `testApiKeyResolution_noSource_returnsNil` -- No key anywhere

#### --base-url flag (1 test)

- **[P1]** `testBaseURLFlag`

#### --tool-allow / --tool-deny (3 tests)

- **[P1]** `testToolAllowFlag_parsesCommaSeparated` -- Multiple values
- **[P1]** `testToolDenyFlag_parsesCommaSeparated` -- Multiple values
- **[P1]** `testToolAllowFlag_singleValue` -- Single value

#### Combined flags (1 test)

- **[P1]** `testMultipleFlags_allParsed` -- Multiple flags + positional all parsed correctly

#### Edge cases (3 tests)

- **[P3]** `testEmptyArgsArray_defaultsToREPL` -- Empty array edge case
- **[P3]** `testMultiplePositionalArgs_usesFirstAsPrompt` -- Only first positional used
- **[P3]** `testFlagValueMissingAtEnd_setsError` -- Trailing flag with no value

---

## Acceptance Criteria Coverage Matrix

| AC | Tests | Priority | Status |
|----|-------|----------|--------|
| AC#1: --help shows help, exit 0 | 3 tests | P0 | RED |
| AC#2: No args = REPL defaults | 2 tests | P0 | RED |
| AC#3: Quoted string = single-shot | 2 tests | P0 | RED |
| AC#4: Invalid flag = error, exit 1 | 2 tests | P0 | RED |
| (Extended: version flag) | 2 tests | P0 | RED |
| (Extended: all flag parsing) | 37 tests | P1-P3 | RED |

---

## Implementation Checklist

### Test: All 50 tests in ArgumentParserTests.swift

**File:** `Tests/OpenAgentCLITests/ArgumentParserTests.swift`

**Tasks to make these tests pass:**

- [ ] Create `Sources/OpenAgentCLI/Version.swift` with `CLI_VERSION` constant
- [ ] Create `Sources/OpenAgentCLI/ANSI.swift` with terminal escape helpers
- [ ] Create `Sources/OpenAgentCLI/ArgumentParser.swift` with:
  - [ ] Define `ParsedArgs` struct with all fields from story design
  - [ ] Implement `static func parse(_ args: [String]) -> ParsedArgs`
  - [ ] Handle `--help` / `-h`: set helpRequested, shouldExit, exitCode=0, helpMessage
  - [ ] Handle `--version` / `-v`: set versionRequested, shouldExit, exitCode=0
  - [ ] Handle positional args (single-shot detection): set prompt
  - [ ] Handle `--model <value>` (default: "glm-5.1")
  - [ ] Handle `--mode <value>` with validation against PermissionMode cases
  - [ ] Handle `--tools <value>` with validation against known tiers
  - [ ] Handle `--provider <value>` with validation (anthropic/openai)
  - [ ] Handle `--output <value>` with validation (text/json)
  - [ ] Handle `--log-level <value>` with validation (debug/info/warn/error)
  - [ ] Handle `--max-turns <n>` with positive integer validation
  - [ ] Handle `--max-budget <usd>` with positive double validation
  - [ ] Handle `--thinking <budget>` with positive integer validation
  - [ ] Handle `--mcp <path>`, `--hooks <path>`, `--skill-dir <path>`
  - [ ] Handle `--skill <name>`, `--session <id>`, `--system-prompt <text>`
  - [ ] Handle `--api-key <key>` with env var fallback (OPENAGENT_API_KEY)
  - [ ] Handle `--base-url <url>`
  - [ ] Handle `--tool-allow <names>` and `--tool-deny <names>` (comma-separated)
  - [ ] Handle `--quiet` and `--no-restore` (boolean flags)
  - [ ] Handle unknown flags: set error with flag name, suggest --help, exit 1
  - [ ] Handle missing values for value-requiring flags: error, exit 1
- [ ] Create `Sources/OpenAgentCLI/CLI.swift` with orchestrator (may not be needed for these tests)
- [ ] Update `Sources/OpenAgentCLI/main.swift` to use CLI.run()
- [ ] Run tests: `swift test --filter ArgumentParserTests`
- [ ] All 50 tests pass (green phase)

---

## Running Tests

```bash
# Build tests only (faster, shows compilation errors)
swift build --build-tests

# Run all tests
swift test

# Run specific test file
swift test --filter ArgumentParserTests

# Run a single test by name
swift test --filter ArgumentParserTests/testHelpFlag_setsHelpRequested
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**

- 50 failing tests written in `ArgumentParserTests.swift`
- All tests exercise `ArgumentParser.parse()` with `[String]` input arrays
- No subprocess spawning -- pure unit tests
- All 4 acceptance criteria covered with dedicated test cases
- Extended flag parsing coverage for all ~20 flags defined in the story

**Verification:**

```
Build errors: 100 (all "cannot find 'ArgumentParser' in scope")
Test count: 50 test methods
Line count: 473 lines
Failure reason: ArgumentParser type does not exist yet (intentional)
```

---

### GREEN Phase (DEV Team - Next Steps)

1. Pick tests in priority order: P0 first (AC coverage), then P1 (flag parsing), then P2 (validation), then P3 (edge cases)
2. Create `ArgumentParser.swift` with `ParsedArgs` struct and `parse()` method
3. Run `swift test --filter ArgumentParserTests` after each incremental implementation
4. Watch tests turn green one by one

---

### REFACTOR Phase (After All Tests Pass)

1. Review `ArgumentParser.parse()` for readability
2. Extract validation helpers if needed
3. Ensure tests still pass after each refactor

---

## Test Execution Evidence

### Initial Build Attempt (RED Phase Verification)

**Command:** `swift build --build-tests`

**Results:**

```
error: cannot find 'ArgumentParser' in scope (100 occurrences across 50 test methods)
```

**Summary:**

- Total test methods: 50
- Passing: 0 (expected -- tests cannot compile)
- Failing: 50 (expected -- ArgumentParser type not yet implemented)
- Build errors: 100 (all identical: type not found)
- Status: RED phase verified

**Expected Failure Reason:**
All tests reference `ArgumentParser.parse()` which is a type that will be created in `Sources/OpenAgentCLI/ArgumentParser.swift` as part of the implementation. The `ParsedArgs` struct return type is also not yet defined. This is the correct TDD red phase state.

---

## Notes

- **No third-party CLI libraries**: The story constrains against using `swift-argument-parser` or similar. All parsing must use Foundation only.
- **Testability pattern**: `ArgumentParser.parse()` accepts `[String]` parameter instead of reading `CommandLine.arguments` directly, making it fully unit-testable without subprocess spawning.
- **API key resolution**: Tests use `setenv`/`unsetenv` for env var testing. The resolution order is: `--api-key` flag > `OPENAGENT_API_KEY` env var > nil.
- **Validation rules**: The story specifies exact valid values for --mode, --tools, --provider, --output, and --log-level flags. Tests validate both valid and invalid values.

---

**Generated by BMad TEA Agent** - 2026-04-19
