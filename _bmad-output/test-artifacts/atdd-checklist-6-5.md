---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-21'
workflowType: 'testarch-atdd'
inputDocuments:
  - _bmad-output/implementation-artifacts/6-5-markdown-terminal-rendering.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - Sources/OpenAgentCLI/OutputRenderer.swift
  - Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift
  - Sources/OpenAgentCLI/ANSI.swift
---

# ATDD Checklist - Epic 6, Story 6.5: Markdown Terminal Rendering

**Date:** 2026-04-21
**Author:** TEA Agent
**Primary Test Level:** Unit (Swift/XCTest)
**Stack:** Backend (Swift)
**TDD Phase:** RED (tests fail as expected -- feature not yet implemented)

---

## Story Summary

**As a** user
**I want** Agent responses rendered with basic Markdown formatting in the terminal
**So that** code blocks, headings, and lists are clearly readable

---

## Acceptance Criteria

1. **AC#1:** Given the Agent responds with Markdown-formatted text, When rendered in the terminal, Then code blocks display with visual borders, headings are bold, and lists are correctly indented
2. **AC#2:** Given terminal width is detected, When rendering long lines, Then text wraps at the terminal width boundary

---

## Tests Created (23 tests)

### Unit Tests: MarkdownRendererTests (23 tests)

**File:** `Tests/OpenAgentCLITests/MarkdownRendererTests.swift`

#### AC#1: Code Block Rendering (3 tests)

| Test | Status | Description |
|------|--------|-------------|
| testCodeBlock_rendersWithBorders | FAIL | Fenced code block renders with top/bottom borders and left margin |
| testCodeBlock_preservesIndentation | FAIL | Code block content preserves original indentation |
| testCodeBlock_withLanguageTag_rendersContent | FAIL | Code block with language tag renders code content |

#### AC#1: Heading Rendering (3 tests)

| Test | Status | Description |
|------|--------|-------------|
| testHeading_h1_boldRendering | FAIL | H1 heading uses ANSI bold escape code |
| testHeading_allLevels_boldRendering | FAIL | All heading levels (H1-H6) use ANSI bold |
| testHeading_differentLevels_visualHierarchy | FAIL | All heading levels render bold with text preserved |

#### AC#1: List Rendering (4 tests)

| Test | Status | Description |
|------|--------|-------------|
| testUnorderedList_bulletAndIndent | FAIL | Unordered list renders with bullet character and indent |
| testUnorderedList_asteriskMarker_rendersAsBullet | FAIL | Asterisk markers render as bullet points |
| testOrderedList_preservesNumbering | FAIL | Ordered list preserves numbering |
| testNestedList_correctIndentation | FAIL | Nested lists have increasing indentation per level |

#### AC#1: Inline Formatting (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testInlineBold_ansiWrapped | FAIL | **bold** text wrapped with ANSI bold codes |
| testInlineCode_cyanOrHighlighted | FAIL | `code` text wrapped with ANSI cyan/highlight |

#### AC#1: Plain Text & Paragraphs (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testPlainText_noModification | FAIL | Plain text passes through unchanged |
| testParagraphSeparation_blankLines | FAIL | Paragraphs separated by blank lines |

#### AC#1: Mixed Markdown (1 test)

| Test | Status | Description |
|------|--------|-------------|
| testMixedMarkdown_listWithInlineCode_correctRendering | FAIL | List items with inline code render both formats |

#### AC#2: Word Wrap (2 tests)

| Test | Status | Description |
|------|--------|-------------|
| testWordWrap_wrapsAtBoundary | FAIL | Long lines wrap near specified width |
| testWordWrap_preservesIndent | FAIL | Wrapped lines preserve leading indentation |

#### AC#2: Terminal Width (1 test)

| Test | Status | Description |
|------|--------|-------------|
| testTerminalWidth_fallbackTo80 | FAIL | Returns >=80 when terminal width undetectable |

#### Regression & Edge Cases (5 tests)

| Test | Status | Description |
|------|--------|-------------|
| testCodeBlock_noWordWrapping | FAIL | Code block content is NOT word-wrapped |
| testEmptyInput_returnsEmpty | FAIL | Empty input returns empty output |
| testIncompleteCodeBlock_rendersAsText | FAIL | Unclosed code block handled gracefully |
| testThinkingPrefix_notModifiedByMarkdown | FAIL | [thinking] prefix preserved for dim styling |
| testMarkdownRenders_independentOfQuietMode | FAIL | MarkdownRenderer is a pure function |

---

## Test Strategy

### Level Selection (Backend Stack)

- **Unit tests** for MarkdownRenderer (pure function: input string -> ANSI-formatted string)
- **Unit tests** for wordWrap utility (pure function)
- **Unit tests** for terminalWidth (returns Int with fallback)
- No E2E or integration tests needed -- MarkdownRenderer is a stateless transform

### Priority Matrix

| Priority | Tests | Rationale |
|----------|-------|-----------|
| P0 | Code blocks, headings, inline bold/code | Core Markdown elements users see most |
| P1 | Lists (ordered, unordered, nested) | Common in Agent responses |
| P2 | Word wrap, terminal width | Nice-to-have for long lines |
| P3 | Edge cases, regression | Empty input, unclosed blocks, thinking prefix |

---

## Implementation Checklist

### Task 1: Create MarkdownRenderer module (AC: #1)

**Source:** `Sources/OpenAgentCLI/MarkdownRenderer.swift` (NEW)

- [ ] Create `enum MarkdownRenderer` with `static func render(_ markdown: String, terminalWidth: Int = 80) -> String`
- [ ] Implement block-level parsing: split input by double-newlines into blocks
- [ ] Detect block types: code blocks (``` fences), headings (#), lists (- / * / 1.), paragraphs
- [ ] Code block rendering: top border, left margin bar, bottom border; content preserved as-is
- [ ] Heading rendering: wrap with `ANSI.bold()`, strip # markers
- [ ] Unordered list: replace `- ` / `* ` with `  bullet_char `, keep text
- [ ] Ordered list: preserve numbering, add indent
- [ ] Nested list: each level adds 2-space indent
- [ ] Tests covered: testCodeBlock_*, testHeading_*, testUnorderedList_*, testOrderedList_*, testNestedList_*

### Task 2: Implement inline rendering (AC: #1)

**Source:** `Sources/OpenAgentCLI/MarkdownRenderer.swift`

- [ ] `**bold**` -> `ANSI.bold("bold")`, strip ** markers
- [ ] `` `code` `` -> `ANSI.cyan("code")`, strip backtick markers
- [ ] Plain text: no modification
- [ ] Paragraphs: blank-line separation preserved
- [ ] Tests covered: testInlineBold_ansiWrapped, testInlineCode_cyanOrHighlighted, testPlainText_noModification, testParagraphSeparation_blankLines

### Task 3: Terminal width detection and word wrap (AC: #2)

**Source:** `Sources/OpenAgentCLI/MarkdownRenderer.swift`

- [ ] `static func terminalWidth() -> Int` using stty/COLUMNS env with fallback to 80
- [ ] `static func wordWrap(_ text: String, width: Int) -> String` wraps at word boundaries
- [ ] Wrapped lines preserve leading indentation
- [ ] Code block content is NOT wrapped (rendered as-is)
- [ ] Tests covered: testWordWrap_*, testTerminalWidth_*, testCodeBlock_noWordWrapping

### Task 4: Integrate into OutputRenderer streaming pipeline (AC: #1)

**Source:** `Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift`

- [ ] Modify `renderPartialMessage()` to implement block-level buffering strategy
- [ ] Accumulate chunks until paragraph boundary (double newline) or code block close (```)
- [ ] Apply MarkdownRenderer.render() to complete blocks before writing
- [ ] Thinking content ([thinking] prefix) continues to use ANSI.dim(), not modified by Markdown rendering
- [ ] Quiet mode: Markdown rendering still applies (quiet filters message types, not formatting)
- [ ] Tests covered: testThinkingPrefix_notModifiedByMarkdown, testMarkdownRenders_independentOfQuietMode

### Task 5: Update ANSI.swift if needed (AC: #1)

**Source:** `Sources/OpenAgentCLI/ANSI.swift`

- [ ] Add `ANSI.green(_:)` if needed for code highlighting (optional, existing cyan may suffice)
- [ ] Verify existing bold, dim, cyan, red, yellow methods are reusable
- [ ] Minimal changes expected

---

## Red-Green-Refactor Workflow

### RED Phase (Current)

- [x] 23 failing tests generated
- [x] All tests will FAIL -- MarkdownRenderer module does not exist yet
- [x] Tests follow established patterns (XCTest, @testable import)
- [x] Tests assert EXPECTED behavior (not placeholders)
- [ ] No regression in existing tests (full suite run pending)

### GREEN Phase (After Implementation)

1. Create `Sources/OpenAgentCLI/MarkdownRenderer.swift` with render(), wordWrap(), terminalWidth()
2. Run: `swift test --filter MarkdownRendererTests`
3. Verify all 23 tests pass
4. Integrate into OutputRenderer+SDKMessage.swift (block buffering)
5. Run: `swift test` (full regression)
6. If any fail: fix implementation (feature bug) or fix test (test bug)

### REFACTOR Phase

- Consider extracting block-type detection into separate methods
- Consider adding markdown element enum for type-safe block handling
- Verify no performance regression in streaming output

---

## Running Tests

```bash
# Run new tests only (Story 6.5)
swift test --filter MarkdownRendererTests

# Run existing OutputRenderer tests (regression)
swift test --filter OutputRendererTests

# Run thinking/quiet mode tests (regression -- Story 6.4)
swift test --filter ThinkingAndQuietModeTests

# Run full test suite (all stories)
swift test

# Run specific test
swift test --filter MarkdownRendererTests/testCodeBlock_rendersWithBorders
```

---

## Key Findings

1. **MarkdownRenderer is a pure function** -- `render()` takes a string and returns a string. No state, no side effects. This makes it highly testable with straightforward unit tests.

2. **Three public API methods needed** -- `render(_:terminalWidth:)`, `wordWrap(_:width:)`, and `terminalWidth()`. All are static methods on an enum namespace, consistent with the project's `ANSI` pattern.

3. **Block-level buffering is the integration challenge** -- The current `renderPartialMessage()` writes chunks immediately. Markdown rendering requires complete blocks. The story recommends accumulating chunks until block boundaries (double newlines or code block closes).

4. **Thinking content must be preserved** -- The `[thinking]` prefix handling from Story 6.4 uses `ANSI.dim()`. Markdown rendering must not interfere with this. The test `testThinkingPrefix_notModifiedByMarkdown` guards this boundary.

5. **Zero third-party dependencies** -- The story explicitly requires hand-written Markdown parsing. Only code blocks, headings, lists, and inline bold/code need support. No tables, links, images, or footnotes.

6. **Existing ANSI methods are sufficient** -- `ANSI.bold()`, `ANSI.cyan()`, `ANSI.dim()` cover all needed styling. New methods (green, italic) are optional per the story.

7. **XCTest unavailable in Command Line Tools environment** -- Tests are structurally verified by review; full execution requires Xcode.app developer tools.

---

## Knowledge Base References Applied

- **component-tdd.md** - Component test strategies adapted for Swift XCTest
- **test-quality.md** - Test design principles (Given-When-Then, one assertion per test, determinism)
- **data-factories.md** - Helper patterns for test data construction

See `tea-index.csv` for complete knowledge fragment mapping.

---

**Generated by BMad TEA Agent** - 2026-04-21
