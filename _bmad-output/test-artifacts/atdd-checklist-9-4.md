---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-24'
workflowType: 'testarch-atdd'
inputDocuments:
  - _bmad-output/implementation-artifacts/9-4-tab-completion.md
  - _bmad-output/planning-artifacts/epics.md
  - Sources/OpenAgentCLI/REPLLoop.swift
  - Sources/OpenAgentCLI/CLI.swift
  - Sources/OpenAgentCLI/LinenoiseInputReader.swift
  - Tests/OpenAgentCLITests/ColoredPromptTests.swift
  - Tests/OpenAgentCLITests/CommandHistoryTests.swift
---

# ATDD Checklist - Epic 9, Story 9.4: Tab Command Completion

**Date:** 2026-04-24
**Author:** TEA Agent
**Primary Test Level:** Unit (Swift/XCTest)
**Stack:** Backend (Swift)
**TDD Phase:** RED (tests will fail until TabCompletionProvider is implemented)

---

## Story Summary

**As a** user
**I want** to press Tab to auto-complete `/` commands in the REPL
**So that** I don't need to memorize exact command spellings

---

## Acceptance Criteria

1. **AC#1:** Given I'm in REPL mode, When I type `/m` and press Tab, Then auto-complete shows `/mode` and `/model` matches; `/mod` uniquely matches `/mode`
2. **AC#2:** Given I'm in REPL mode, When I type `/` and press Tab, Then all 13 slash commands are listed
3. **AC#3:** Given I'm in REPL mode, When I type `/mcp ` and press Tab, Then MCP subcommands (`status`, `reconnect`) are shown
4. **AC#4:** Given I'm in REPL mode, When I type `/mode ` and press Tab, Then all valid PermissionMode values are shown
5. **AC#5:** Given I'm in REPL mode, When I type non-`/` text and press Tab, Then no completion is triggered
6. **AC#6:** Given I'm in REPL mode, When I type `/s` and press Tab, Then `/sessions` and `/skills` are listed

---

## Tests Created (27 tests)

### Unit Tests: TabCompletionTests (27 tests)

**File:** `Tests/OpenAgentCLITests/TabCompletionTests.swift`

#### AC#1: Unique prefix match (3 tests)

| Test | Status | Description |
|------|--------|-------------|
| testCompletions_inputM_returnsModeAndModel | FAIL | `/m` matches both /mode and /model |
| testCompletions_inputMo_returnsModeAndModel | FAIL | `/mo` matches both /mode and /model |
| testCompletions_inputMod_returnsMode | FAIL | `/mod` uniquely matches /mode |

#### AC#2: List all commands (1 test)

| Test | Status | Description |
|------|--------|-------------|
| testCompletions_bareSlash_returnsAllCommands | FAIL | `/` returns all 13 commands |

#### AC#3: MCP subcommand completion (4 tests)

| Test | Status | Description |
|------|--------|-------------|
| testCompletions_mcpSpace_returnsMcpSubcommands | FAIL | `/mcp ` lists status and reconnect |
| testCompletions_mcpSpaceS_returnsStatus | FAIL | `/mcp s` matches status |
| testCompletions_mcpSpaceR_returnsReconnect | FAIL | `/mcp r` matches reconnect |
| testCompletions_mcpSpaceUnknown_returnsEmpty | FAIL | `/mcp z` returns empty |

#### AC#4: Mode subcommand completion (5 tests)

| Test | Status | Description |
|------|--------|-------------|
| testCompletions_modeSpace_returnsAllPermissionModes | FAIL | `/mode ` lists all PermissionMode values |
| testCompletions_modeSpacePl_returnsPlan | FAIL | `/mode pl` matches plan |
| testCompletions_modeSpaceD_returnsDefaultAndDontAsk | FAIL | `/mode d` matches default and dontAsk |
| testCompletions_modeSpaceAuto_returnsAuto | FAIL | `/mode a` matches auto and acceptEdits |
| testCompletions_modeSpaceUnknown_returnsEmpty | FAIL | `/mode xyz` returns empty |

#### AC#5: Non-/ input returns no completions (4 tests)

| Test | Status | Description |
|------|--------|-------------|
| testCompletions_plainText_returnsEmpty | FAIL | `hello` returns empty |
| testCompletions_emptyString_returnsEmpty | FAIL | empty string returns empty |
| testCompletions_whitespaceOnly_returnsEmpty | FAIL | whitespace returns empty |
| testCompletions_commandWithoutSlash_returnsEmpty | FAIL | `help` (no /) returns empty |

#### AC#6: Multiple prefix matches (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testCompletions_inputS_returnsSessionsAndSkills | FAIL | `/s` matches /sessions and /skills |
| testCompletions_inputC_returnsCostAndClear | FAIL | `/c` matches /cost and /clear |

#### Edge cases (5 tests)

| Test | Status | Description |
|------|--------|-------------|
| testCompletions_exactMatch_returnsSingleMatch | FAIL | `/help` exact match returns ["/help"] |
| testCompletions_modelSpace_returnsEmpty | FAIL | `/model ` returns empty (no subcommands) |
| testCompletions_inputMc_returnsMcp | FAIL | `/mc` matches /mcp |
| testCompletions_unknownCommandPrefix_returnsEmpty | FAIL | `/xyz` returns empty |
| testCompletions_caseInsensitive_uppercaseInput | FAIL | `/M` matches /mode and /model |
| testCompletions_caseInsensitive_mixedCaseInput | FAIL | `/HeL` matches /help |

#### Integration (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testLinenoiseInputReader_hasSetCompletionCallbackMethod | FAIL | LinenoiseInputReader exposes setCompletionCallback |
| testTabCompletionProvider_isIndependentStruct | FAIL | Two instances produce identical results |

---

## Test Execution Plan

### RED Phase Verification

**Command:** `swift test --filter TabCompletionTests`

Tests will fail because:
- `TabCompletionProvider` struct does not exist yet
- `LinenoiseInputReader.setCompletionCallback` method does not exist yet

**Expected result:** 27/27 FAIL (compilation errors) -- RED phase confirmed.

### GREEN Phase (After Implementation)

1. Create `TabCompletionProvider.swift` in Sources/OpenAgentCLI/
2. Add `setCompletionCallback` to `LinenoiseInputReader.swift`
3. Register completion in CLI.swift (2 REPL branches)
4. Run: `swift test --filter TabCompletionTests`
5. Verify all 27 tests pass
6. Run: `swift test` (full regression)

---

## Implementation Checklist

### Task 1: Create TabCompletionProvider.swift

**Source:** `Sources/OpenAgentCLI/TabCompletionProvider.swift`

- [ ] Define `TabCompletionProvider` struct
- [ ] Add `commands` array with all 13 slash commands
- [ ] Add `mcpSubcommands` array: `["status", "reconnect"]`
- [ ] Add `modes` from `PermissionMode.allCases.map(\.rawValue)`
- [ ] Implement `completions(for input:) -> [String]`:
  - Non-`/` prefix returns `[]` (AC#5)
  - Has space + known command → subcommand matching (AC#3, AC#4)
  - Otherwise → main command prefix matching (AC#1, AC#2, AC#6)
- [ ] Case-insensitive comparison (lowercased input)

### Task 2: Add setCompletionCallback to LinenoiseInputReader

**Source:** `Sources/OpenAgentCLI/LinenoiseInputReader.swift`

- [ ] Add public method `setCompletionCallback(_ callback: @escaping (String) -> [String])`
- [ ] Internally calls `linenoise.setCompletionCallback(callback)`

### Task 3: Register completion in CLI.swift

**Source:** `Sources/OpenAgentCLI/CLI.swift`

- [ ] At L127 (skill REPL): create TabCompletionProvider, register callback
- [ ] At L179 (main REPL): create TabCompletionProvider, register callback
- [ ] Register BEFORE `repl.start()`

---

## Key Findings

1. **Pure logic component** -- TabCompletionProvider is a stateless struct with a single `completions(for:)` method. Ideal for unit testing -- no TTY or mock infrastructure needed.

2. **PermissionMode.allCases is the source of truth** -- Mode subcommands come from the SDK enum, not hardcoded. This ensures new modes automatically appear in tab completion.

3. **linenoise handles Tab UI** -- linenoise-swift's `completeLine` method handles the Tab key interception, cycling through matches, and ESC cancellation. We only provide the candidate list.

4. **Two CLI.swift integration points** -- Both REPL branches (skill REPL at ~L127, main REPL at ~L179) need the completion provider registered.

5. **Case-insensitive matching required** -- Users may type `/M` or `/Help`. The completion logic should match regardless of case but return the canonical lowercase command names.

6. **Subcommand pattern is extensible** -- The `/mcp` and `/mode` subcommand pattern can be extended to other commands in the future (e.g., `/model gpt-4`).

---

**Generated by BMad TEA Agent** - 2026-04-24
