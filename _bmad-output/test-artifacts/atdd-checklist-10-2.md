---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-25'
workflowType: 'testarch-atdd'
inputDocuments:
  - _bmad-output/implementation-artifacts/10-2-markdown-table-and-block-element-rendering.md
  - Sources/OpenAgentCLI/MarkdownRenderer.swift
  - Sources/OpenAgentCLI/ANSI.swift
  - Tests/OpenAgentCLITests/MarkdownRendererTests.swift
---

# ATDD Checklist - Epic 10, Story 10.2: Markdown Table & Block Element Rendering

**Date:** 2026-04-25
**Author:** TEA Agent
**Primary Test Level:** Unit (Swift/XCTest)
**Stack:** Backend (Swift CLI)
**TDD Phase:** RED (14 tests fail as expected -- feature not yet implemented)
**Generation Mode:** AI Generation (yolo)
**Execution Mode:** Sequential

---

## Story Summary

**As a** user
**I want** tables, blockquotes, horizontal rules, and links rendered in the terminal
**So that** AI output with structured content is immediately readable

---

## Acceptance Criteria

1. **AC#1:** Tables render with box-drawing characters, bold header, and column alignment
2. **AC#2:** Blockquotes render with grey │ prefix
3. **AC#3:** Horizontal rules (`---`, `***`, `___`) render as ─ characters at terminal width
4. **AC#4:** Inline links `[text](url)` render as underlined text with URL hidden
5. **AC#5:** H1 gets ═ decoration line; H2 gets ─ decoration line; H3-H6 stay bold-only

---

## Tests Created (16 new tests, 39 total in MarkdownRendererTests)

### Unit Tests: MarkdownRendererTests (16 new ATDD tests)

**File:** `Tests/OpenAgentCLITests/MarkdownRendererTests.swift`

#### AC#1: Table Rendering (6 tests)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testTable_simpleTable_boxDrawingBorders` | P0 | FAIL (RED) | Verifies ┌┐└┘├┤ box-drawing characters present |
| `testTable_simpleTable_columnAlignment` | P0 | FAIL (RED) | Verifies │ ┼ separators and cell content preservation |
| `testTable_headerBold` | P0 | FAIL (RED) | Header row uses ANSI bold styling |
| `testTable_unevenColumns_noCrash` | P1 | PASS | Uneven column count does not crash |
| `testTable_wideCell_truncation` | P1 | PASS | Wide cells handled (truncation or preserved) |
| `testTable_headerOnly_noDataRows` | P2 | FAIL (RED) | Header-only table still renders borders |

#### AC#2: Blockquote Rendering (2 tests)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testBlockquote_singleLine` | P0 | FAIL (RED) | Single-line blockquote gets │ prefix |
| `testBlockquote_multiLine` | P0 | FAIL (RED) | Each line of multi-line blockquote gets │ prefix |

#### AC#3: Horizontal Rule Rendering (3 tests)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testHorizontalRule_dash` | P0 | FAIL (RED) | `---` renders as ─ characters |
| `testHorizontalRule_asterisks` | P0 | FAIL (RED) | `***` renders as ─ characters |
| `testHorizontalRule_underscores` | P0 | FAIL (RED) | `___` renders as ─ characters |

#### AC#4: Link Rendering (2 tests)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testLink_inline_rendersAsUnderlinedText` | P0 | FAIL (RED) | `[text](url)` renders as underlined text, URL hidden |
| `testLink_multipleLinks` | P1 | FAIL (RED) | Multiple links each get underline styling |

#### AC#5: Heading Decoration (3 tests)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testHeading_h1_hasDoubleLineDecoration` | P0 | FAIL (RED) | H1 gets ═ decoration line |
| `testHeading_h2_hasSingleLineDecoration` | P0 | FAIL (RED) | H2 gets ─ decoration line |
| `testHeading_h3_through_h6_noDecoration` | P1 | FAIL (RED) | H3-H6 stay bold-only, no decoration |

---

## TDD Red Phase Results

```
Executed 16 tests: 14 FAIL (26 assertion failures), 2 PASS
All 23 existing tests: PASS (no regressions)
Total MarkdownRendererTests: 39 tests
```

### Red Phase Validation

- [x] All new tests assert EXPECTED behavior (not placeholders)
- [x] 14/16 tests fail because feature is not implemented
- [x] 2/16 tests pass (robustness tests for edge cases -- expected in red phase)
- [x] Zero regressions in existing test suite
- [x] No placeholder assertions (no `expect(true).toBe(true)`)

---

## Acceptance Criteria Coverage Matrix

| AC# | Criterion | Tests | Coverage |
|-----|-----------|-------|----------|
| AC#1 | Table box-drawing borders | `testTable_simpleTable_boxDrawingBorders` | Full |
| AC#1 | Column alignment │ ┼ | `testTable_simpleTable_columnAlignment` | Full |
| AC#1 | Header bold | `testTable_headerBold` | Full |
| AC#1 | Uneven columns no crash | `testTable_unevenColumns_noCrash` | Full |
| AC#1 | Wide cell truncation | `testTable_wideCell_truncation` | Full |
| AC#1 | Header-only table | `testTable_headerOnly_noDataRows` | Full |
| AC#2 | Single-line blockquote │ prefix | `testBlockquote_singleLine` | Full |
| AC#2 | Multi-line blockquote │ prefix | `testBlockquote_multiLine` | Full |
| AC#3 | `---` → ─ | `testHorizontalRule_dash` | Full |
| AC#3 | `***` → ─ | `testHorizontalRule_asterisks` | Full |
| AC#3 | `___` → ─ | `testHorizontalRule_underscores` | Full |
| AC#4 | `[text](url)` → underlined text | `testLink_inline_rendersAsUnderlinedText` | Full |
| AC#4 | Multiple links | `testLink_multipleLinks` | Full |
| AC#5 | H1 ═ decoration | `testHeading_h1_hasDoubleLineDecoration` | Full |
| AC#5 | H2 ─ decoration | `testHeading_h2_hasSingleLineDecoration` | Full |
| AC#5 | H3-H6 bold only | `testHeading_h3_through_h6_noDecoration` | Full |

---

## Implementation Guidance

### Files to Modify

| File | Change |
|------|--------|
| `Sources/OpenAgentCLI/MarkdownRenderer.swift` | Add `renderTable`, `renderBlockquote`, `renderHorizontalRule`; enhance `renderBlock` detection order; enhance `renderHeading` for H1/H2 decoration; enhance `renderInline` for link syntax |
| `Sources/OpenAgentCLI/ANSI.swift` | Add `underline()` method |

### renderBlock Detection Order (Updated)

1. Code block (``` wrapped)
2. Table block (all lines match `|...|` pattern)
3. Blockquote block (all lines start with `>`)
4. Horizontal rule (single line of `-`/`*`/`_` only)
5. List block
6. Heading
7. Paragraph (fallback)

---

## Next Steps (TDD Green Phase)

1. Implement `ANSI.underline()` in `ANSI.swift`
2. Add table detection in `renderBlock` and implement `renderTable`
3. Add blockquote detection and `renderBlockquote`
4. Add horizontal rule detection and `renderHorizontalRule`
5. Add link rendering in `renderInline`
6. Enhance `renderHeading` for H1/H2 decoration lines
7. Run tests: `swift test --filter MarkdownRendererTests`
8. Verify all 16 new tests pass (green phase)
9. Run full suite to confirm no regressions
