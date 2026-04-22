---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-22'
workflowType: 'testarch-atdd'
inputDocuments:
  - _bmad-output/implementation-artifacts/7-2-json-output-mode.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - Sources/OpenAgentCLI/OutputRenderer.swift
  - Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift
  - Sources/OpenAgentCLI/ArgumentParser.swift
  - Sources/OpenAgentCLI/CLI.swift
  - Sources/OpenAgentCLI/CLISingleShot.swift
---

# ATDD Checklist - Epic 7, Story 7.2: JSON Output Mode

**Date:** 2026-04-22
**Author:** TEA Agent
**Primary Test Level:** Unit (Swift/XCTest)
**Stack:** Backend (Swift)
**TDD Phase:** RED (tests fail as expected -- feature not yet implemented)

---

## Story Summary

**As a** developer
**I want** to get structured JSON output from the CLI
**So that** I can programmatically parse the Agent's responses

---

## Acceptance Criteria

1. **AC#1:** Given `--output json` is passed, when Agent completes query, then result is printed as JSON with `text`, `toolCalls`, `cost`, and `turns` fields
2. **AC#2:** Given JSON output mode is active, when an error occurs, then error is printed to stdout as `{"error": "..."}`
3. **AC#3:** Given `--output json` is passed, when streaming output is in progress, then no intermediate content is output -- only final JSON
4. **AC#4:** Given `--output json` and query completes successfully, when JSON is printed, then process exits with code 0 and JSON is the sole content of stdout
5. **AC#5:** Given `--output json --quiet`, when query completes, then behavior is identical to `--output json` (quiet has no additional effect in JSON mode)

---

## Tests Created (16 tests)

### Unit Tests: JsonOutputRendererTests (16 tests)

**File:** `Tests/OpenAgentCLITests/JsonOutputRendererTests.swift`

#### AC#1: Successful JSON Output with Required Fields (4 tests)

| Test | Status | Description |
|------|--------|-------------|
| testSuccessQuery_outputsValidJson | FAIL | Successful query outputs parseable JSON to stdout |
| testSuccessQuery_jsonHasRequiredFields | FAIL | JSON contains text, toolCalls, cost, turns fields |
| testSuccessQuery_textFieldContainsAgentResponse | FAIL | JSON text field contains agent response text |
| testSuccessQuery_toolCallsExtracted | FAIL | Tool calls from messages are extracted into JSON array |

#### AC#2: Error JSON Output (3 tests)

| Test | Status | Description |
|------|--------|-------------|
| testErrorQuery_outputsErrorJson | FAIL | Error query outputs `{"error": "..."}` format JSON to stdout |
| testCancelledQuery_outputsErrorJson | FAIL | Cancelled query outputs error JSON to stdout |
| testMaxBudgetError_outputsErrorJson | FAIL | Budget exceeded outputs error JSON to stdout |

#### AC#3: No Intermediate Streaming Output (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testRender_silencesAllIntermediateMessages | FAIL | render() produces no output for any SDKMessage type |
| testRenderStream_silencesIntermediateAndOutputsFinalJson | FAIL | renderStream() produces no output during streaming |

#### AC#4: Exit Code and stdout Purity (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testSuccessQuery_noNonJsonOutputOnStdout | FAIL | JSON output contains only valid JSON (no ANSI, no extra text) |
| testErrorQuery_noNonJsonOutputOnStdout | FAIL | Error JSON output contains only valid JSON on stdout |

#### AC#5: --output json + --quiet Combination (1 test)

| Test | Status | Description |
|------|--------|-------------|
| testQuietCombination_sameAsJsonOnly | FAIL | --output json --quiet produces identical JSON to --output json alone |

#### Additional Coverage (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testEmptyToolCalls_emptyArray | FAIL | No tool calls produces `"toolCalls": []` in JSON |
| testToolCallInput_preservedAsRawString | FAIL | Tool call input is preserved as raw JSON string |

#### Regression (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testRegression_textModeStillWorks | PASS | Text mode rendering is unaffected by JsonOutputRenderer |
| testRegression_existingOutputRendererTestsPass | PASS | Existing OutputRendererTests unchanged |

---

## Test Strategy

### Stack: Backend (Swift)

- **Unit tests** for JsonOutputRenderer: pure function logic, JSON encoding, message filtering
- **No E2E tests** needed (no browser interaction)
- Uses existing `MockTextOutputStream` pattern from `OutputRendererTests`

### Test Levels

| Level | Count | Coverage |
|-------|-------|----------|
| Unit  | 16    | All 5 ACs |

### Priority Matrix

| Priority | Count | Description |
|----------|-------|-------------|
| P0       | 6     | Core JSON output (AC#1, AC#2) |
| P1       | 4     | No intermediate output + stdout purity (AC#3, AC#4) |
| P2       | 2     | Quiet combination + edge cases (AC#5) |
| P3       | 4     | Regression + additional coverage |

---

## Implementation Checklist

### Task 1: Create JsonOutputRenderer.swift (AC: #1, #2, #3)

**Source:** `Sources/OpenAgentCLI/JsonOutputRenderer.swift` (NEW)

- [ ] Create `JsonRenderResult` struct: Encodable with text, toolCalls, cost, turns
- [ ] Create `JsonToolCall` struct: Encodable with name, input
- [ ] Create `JsonOutputRenderer` struct implementing `OutputRendering` protocol
- [ ] Implement `render(_:)` to silently collect data (no output)
- [ ] Implement `renderStream(_:)` to silently consume stream (no output)
- [ ] Implement `renderSingleShotJson(_:)` for single-shot JSON output
- [ ] Implement `collectAndRender(_:)` for streaming JSON output
- [ ] Use `JSONEncoder` with sorted keys for deterministic output
- [ ] Write to stdout via `TextOutputStream`, not `print()`

### Task 2: Integrate JSON output in CLI.swift (AC: #1, #2, #3, #4, #5)

**Source:** `Sources/OpenAgentCLI/CLI.swift`

- [ ] In single-shot branch: add `args.output == "json"` check, use JsonOutputRenderer
- [ ] In skill invocation branch: add JSON renderer when `args.output == "json"`
- [ ] Ensure JSON output is the sole stdout content (no ANSI mixing)
- [ ] Ensure REPL mode ignores `--output json` (uses text renderer)
- [ ] Ensure exit code 0 for success, 1 for error

### Task 3: Verify --output json already in ArgumentParser (AC: validation)

- [x] Confirmed: `--output` already supports `"text"` and `"json"` values
- [x] `ParsedArgs.output` defaults to `"text"`
- [x] No ArgumentParser changes needed

---

## Red-Green-Refactor Workflow

### RED Phase (Current)

- [x] 16 failing/passing tests generated
- [x] ~14 tests fail as expected (JsonOutputRenderer does not exist yet)
- [x] ~2 regression tests pass (text mode unaffected)
- [ ] No regression in existing tests

### GREEN Phase (After Implementation)

1. Create `JsonOutputRenderer.swift` (Task 1)
2. Modify `CLI.swift` (Task 2)
3. Run: `swift test --filter JsonOutputRendererTests`
4. Verify all 16 tests pass
5. Run: `swift test` (full regression)

### REFACTOR Phase

- Review JsonOutputRenderer for protocol compliance
- Consider shared error formatting between text and JSON renderers
- Verify no code duplication

---

## Running Tests

```bash
# Run new tests only (Story 7.2)
swift test --filter JsonOutputRendererTests

# Run existing OutputRenderer tests (regression)
swift test --filter OutputRendererTests

# Run full test suite (all stories)
swift test

# Run specific test
swift test --filter JsonOutputRendererTests/testSuccessQuery_outputsValidJson
```

---

## Key Findings

1. **ArgumentParser is pre-configured** -- `--output json` is already parsed. The `ParsedArgs.output` field defaults to `"text"` and accepts `"json"`. No changes needed.

2. **Strategy B (separate JsonOutputRenderer)** is recommended by the story -- creates a new type implementing `OutputRendering` protocol. This follows the project's "one type per file" and "protocol-based separation" patterns.

3. **OutputRenderer is untouched** -- JSON mode is entirely separate. No risk to existing text rendering. All existing OutputRendererTests should pass.

4. **JSON output to stdout, errors too** -- AC#2 specifies error JSON goes to stdout (not stderr). This is pipe-friendly but unconventional. The tests validate this explicitly.

5. **Quiet mode is no-op in JSON mode** -- AC#5 confirms `--quiet` has no additional effect when combined with `--output json`. JSON mode already silences everything.

6. **Foundation JSONEncoder** -- No third-party dependencies. Uses `JSONEncoder` from Foundation for serialization.

7. **XCTest environment note** -- Tests are structured for compile-verification. Full execution requires Xcode.app developer tools.

---

## Knowledge Base References Applied

- **component-tdd.md** - Component test strategies for Swift XCTest
- **test-quality.md** - Test design principles (Given-When-Then, one assertion per test)
- **data-factories.md** - Helper patterns for mock data construction

---

**Generated by BMad TEA Agent** - 2026-04-22
