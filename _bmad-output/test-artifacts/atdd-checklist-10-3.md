---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-26'
workflowType: 'testarch-atdd'
inputDocuments:
  - _bmad-output/implementation-artifacts/10-3-streaming-table-buffer-and-rendering.md
  - Sources/OpenAgentCLI/OutputRenderer.swift
  - Sources/OpenAgentCLI/MarkdownRenderer.swift
  - Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift
  - Tests/OpenAgentCLITests/OutputRendererTests.swift
---

# ATDD Checklist - Epic 10, Story 10.3: Streaming Table Buffer and Rendering

**Date:** 2026-04-26
**Author:** TEA Agent
**Primary Test Level:** Unit (Swift/XCTest)
**Stack:** Backend (Swift CLI)
**TDD Phase:** GREEN (all 23 tests pass -- feature implemented)
**Generation Mode:** AI Generation (yolo)
**Execution Mode:** Sequential

---

## Story Summary

**As a** user
**I want** to see complete table rendering during AI streaming output instead of fragments
**So that** tables do not warp or flicker during streaming

---

## Acceptance Criteria

1. **AC#1:** Table row detection triggers buffering mode (no output during table)
2. **AC#2:** Complete table rendered atomically via `MarkdownRenderer.render()` on table end
3. **AC#3:** Multiple independent tables buffered and rendered separately
4. **AC#4:** Chunk boundary splicing handled correctly (mid-cell splits reassembled)
5. **AC#5:** Flush renders incomplete table with best-effort (no crash)
6. **AC#6:** Normal text after table resumes immediate `renderInline` output

---

## Tests Created (23 tests)

### Unit Tests: StreamingTableBufferTests (23 ATDD tests)

**File:** `Tests/OpenAgentCLITests/StreamingTableBufferTests.swift`

#### AC#1: Table row detection and buffering (3 tests)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testAppend_singleTableLineStarts_bufferingActivated` | P0 | PASS | Table header + separator triggers buffering, no output |
| `testAppend_tableLineDetection_requiresMultipleTableLines` | P0 | PASS | Single pipe in text does NOT trigger buffering |
| `testAppend_tableChunksAreBuffered_noOutputDuringTable` | P0 | PASS | All table chunks buffered until table ends |

#### AC#2: Atomic table rendering (3 tests)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testAppend_tableComplete_rendersAtomically` | P0 | PASS | Complete table renders with box-drawing borders |
| `testAppend_tableComplete_renderMatchesMarkdownRendererOutput` | P0 | PASS | Rendered output contains │ vertical bar characters |
| `testAppend_tableEndDetectedByNonTableLine` | P0 | PASS | Non-table line after table triggers render |

#### AC#3: Multiple independent tables (2 tests)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testAppend_twoIndependentTables_bothRenderedCorrectly` | P0 | PASS | Two tables with inter-table text both render |
| `testAppend_tablesDoNotInterfere` | P0 | PASS | Tables do not interfere with each other |

#### AC#4: Chunk boundary splicing (3 tests)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testAppend_chunkSplitMidCell_correctlySplices` | P0 | PASS | Mid-cell split reassembles and renders as table |
| `testAppend_chunkSplitAtLineBoundary_correctlySplices` | P0 | PASS | Line-boundary split table renders all content |
| `testAppend_singleChunkCompleteTable_rendersCorrectly` | P0 | PASS | Single-chunk complete table renders correctly |

#### AC#5: Flush best-effort rendering (3 tests)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testFlush_incompleteTable_bestEffortNoCrash` | P0 | PASS | Flush with incomplete table produces output, no crash |
| `testFlush_incompleteTable_singleRow_noCrash` | P0 | PASS | Flush with single row falls back gracefully |
| `testFlush_emptyBuffer_noOutput` | P1 | PASS | Empty flush produces no output |

#### AC#6: Normal text after table (2 tests)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testAppend_textAfterTable_immediateOutput` | P0 | PASS | Text after table renders immediately |
| `testAppend_textBeforeTable_normalThenTableBuffering` | P0 | PASS | Text before table renders, then table buffers |

#### Regression: Code block buffering (2 tests)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testAppend_codeBlockStillWorks_afterTableBufferingAdded` | P1 | PASS | Code blocks still render with borders |
| `testAppend_codeBlockNotConfusedWithTable` | P1 | PASS | Code block with pipes renders as code, not table |

#### Regression: Normal text output (2 tests)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testAppend_normalText_stillImmediate` | P1 | PASS | Normal text renders immediately |
| `testAppend_normalTextMultipleChunks_concatenates` | P1 | PASS | Multiple text chunks concatenate |

#### Edge Cases (3 tests)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testAppend_tableWithSeparatorOnly_noDataRows_noCrash` | P2 | PASS | Header-only table does not crash |
| `testAppend_emptyChunk_noEffect` | P2 | PASS | Empty chunk produces no output |
| `testAppend_tableFollowedByImmediateAnotherTable` | P2 | PASS | Two tables with no text between render both |

---

## TDD Green Phase Results

```
Executed 23 tests: 23 PASS, 0 FAIL
All acceptance tests pass -- table buffering feature fully implemented
```

### Green Phase Validation

- [x] All 23 tests pass (feature is implemented)
- [x] All new tests assert EXPECTED behavior (not placeholders)
- [x] No placeholder assertions (no `expect(true).toBe(true)`)
- [x] Zero regressions in existing test suite
- [x] Implementation complete in `Sources/OpenAgentCLI/OutputRenderer.swift`

---

## Acceptance Criteria Coverage Matrix

| AC# | Criterion | Tests | Coverage |
|-----|-----------|-------|----------|
| AC#1 | Table row detection + buffering | `testAppend_singleTableLineStarts_bufferingActivated`, `testAppend_tableLineDetection_requiresMultipleTableLines`, `testAppend_tableChunksAreBuffered_noOutputDuringTable` | Full |
| AC#2 | Atomic rendering on table end | `testAppend_tableComplete_rendersAtomically`, `testAppend_tableComplete_renderMatchesMarkdownRendererOutput`, `testAppend_tableEndDetectedByNonTableLine` | Full |
| AC#3 | Multiple independent tables | `testAppend_twoIndependentTables_bothRenderedCorrectly`, `testAppend_tablesDoNotInterfere` | Full |
| AC#4 | Chunk boundary splicing | `testAppend_chunkSplitMidCell_correctlySplices`, `testAppend_chunkSplitAtLineBoundary_correctlySplices`, `testAppend_singleChunkCompleteTable_rendersCorrectly` | Full |
| AC#5 | Flush best-effort | `testFlush_incompleteTable_bestEffortNoCrash`, `testFlush_incompleteTable_singleRow_noCrash`, `testFlush_emptyBuffer_noOutput` | Full |
| AC#6 | Text after table | `testAppend_textAfterTable_immediateOutput`, `testAppend_textBeforeTable_normalThenTableBuffering` | Full |

---

## Implementation Guidance

### File to Modify

| File | Change |
|------|--------|
| `Sources/OpenAgentCLI/OutputRenderer.swift` | Add `insideTableBlock` state, `detectTableStart()`, `tryFlushTableBlock()` to MarkdownBuffer; modify `append()` to handle table buffering; modify `flush()` for best-effort table rendering |

### State Machine Design

Current MarkdownBuffer has two states: `insideCodeBlock` and normal. Add:

1. **insideCodeBlock** (highest priority) -- existing
2. **insideTableBlock** (new) -- table buffering
3. **Normal mode** -- renderInline immediate output

### Key Implementation Points

- `append()` else branch: accumulate chunk, detect table start (>= 2 consecutive `|...|` lines)
- `tryFlushTableBlock()`: scan buffer for table end (empty line or non-`|` line)
- On table end: call `MarkdownRenderer.render()` for buffered content, output result
- `flush()`: if `insideTableBlock`, render buffered content via `MarkdownRenderer.render()`
- Do NOT modify MarkdownRenderer.swift -- table rendering is already complete from Story 10.2

---

## Next Steps (TDD Green Phase)

1. Add `private var _insideTableBlock = false` state to MarkdownBuffer
2. Implement `isTableLine()` detection in MarkdownBuffer (simpler than MarkdownRenderer's -- just `|...|` check)
3. Modify `append()` to enter table buffering mode when table lines detected
4. Implement `tryFlushTableBlock()` for table end detection and atomic rendering
5. Modify `flush()` for best-effort incomplete table rendering
6. Run tests: `swift test --filter StreamingTableBufferTests`
7. Verify all 23 tests pass (green phase)
8. Run full suite to confirm no regressions
