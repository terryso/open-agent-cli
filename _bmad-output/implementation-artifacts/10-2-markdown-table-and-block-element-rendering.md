# Story 10.2: Markdown 表格与块级元素渲染

Status: done

## Story

作为一个用户，
我想要看到表格、引用块、分割线和链接的终端渲染效果，
以便 AI 输出的结构化内容一目了然。

## Acceptance Criteria

### AC#1: 表格渲染

**Given** AI 输出包含 Markdown 表格
```
| Name | Status | Count |
|------|--------|-------|
| foo  | active | 3     |
| bar  | idle   | 0     |
```
**When** 渲染到终端
**Then** 使用 box-drawing 字符渲染为：
```
┌──────┬──────────┬───────┐
│ Name │ Status   │ Count │
├──────┼──────────┼───────┤
│ foo  │ active   │     3 │
│ bar  │ idle     │     0 │
└──────┴──────────┴───────┘
```
**And** 表头行加粗显示
**And** 列宽按最长内容自动对齐（左右各留 1 空格 padding）

**Given** 表格列数不一致
**When** 渲染到终端
**Then** 缺失列用空格填充，不崩溃

**Given** 单元格内容超过终端宽度
**When** 渲染到终端
**Then** 内容被截断并追加 `...`，表格不超宽

### AC#2: 引用块渲染

**Given** AI 输出包含引用块
```
> This is a quote
> spanning multiple lines
```
**When** 渲染到终端
**Then** 每行前加灰色 `│ ` 前缀：
```
│ This is a quote
│ spanning multiple lines
```

### AC#3: 水平分割线

**Given** AI 输出包含 `---` 或 `***` 或 `___`
**When** 渲染到终端
**Then** 输出一行 `─` 字符，长度为终端宽度

### AC#4: 链接渲染

**Given** AI 输出包含链接 `[text](url)`
**When** 渲染到终端
**Then** 显示为 `text`（下划线样式），URL 不显示

### AC#5: 标题装饰增强

**Given** AI 输出 H1 标题 `# Title`
**When** 渲染到终端
**Then** 加粗 + 下方追加 `═══` 装饰线（与标题等长）

**Given** AI 输出 H2 标题 `## Title`
**When** 渲染到终端
**Then** 加粗 + 下方追加 `───` 装饰线（与标题等长）

**Given** AI 输出 H3-H6 标题
**When** 渲染到终端
**Then** 仅加粗（已有行为，不变）

## Tasks / Subtasks

- [x] Task 1: 在 `renderBlock` 中添加表格块识别 (AC: #1)
  - [x] 检测连续的 `|...|` 行（含分隔行 `|---|---|`）作为一个 table block
  - [x] 表格块需要包含 header 行、separator 行和 data 行
  - [x] 空行或非 `|` 行结束当前表格块

- [x] Task 2: 实现 `renderTable` 方法 (AC: #1)
  - [x] 解析表格行：提取每行的单元格内容（trim 空格）
  - [x] 跳过 separator 行（`|---|---|`），仅用于验证表格结构
  - [x] 计算每列最大宽度（遍历所有行的该列内容）
  - [x] 用 box-drawing 字符绘制：`┌` `┬` `┐` `├` `┼` `┤` `└` `┴` `┘` `│` `─`
  - [x] 表头行使用 `ANSI.bold()` 包裹
  - [x] 数据行正常输出，数字内容右对齐
  - [x] 超宽单元格截断并追加 `...`

- [x] Task 3: 在 `renderBlock` 中添加引用块检测和渲染 (AC: #2)
  - [x] 检测连续以 `> ` 开头的行作为一个 blockquote block
  - [x] 实现 `renderBlockquote` 方法：每行前加 `│ `（灰色前缀）
  - [x] 去掉原始 `> ` 前缀，替换为 `│ `

- [x] Task 4: 在 `renderBlock` 中添加分割线检测和渲染 (AC: #3)
  - [x] 检测仅由 `-`、`*`、`_` 和空格组成的行（至少 3 个非空格字符）
  - [x] 实现 `renderHorizontalRule` 方法：输出 `terminalWidth` 个 `─` 字符
  - [x] 注意区分分割线 `---` 和表格行 `|---|`——分割线不包含 `|` 字符

- [x] Task 5: 在 `renderInline` 中添加链接渲染 (AC: #4)
  - [x] 匹配 `[text](url)` 模式
  - [x] 替换为 `ANSI.underline(text)`（仅显示 text，隐藏 url）
  - [x] 添加 `ANSI.underline()` 方法到 `ANSI.swift`（ANSI code `\u{001B}[4m`）

- [x] Task 6: 增强 `renderHeading` 方法 (AC: #5)
  - [x] H1：加粗 + 下方追加与标题文本等长的 `═` 装饰线
  - [x] H2：加粗 + 下方追加与标题文本等长的 `─` 装饰线
  - [x] H3-H6：保持现有行为（仅加粗）

- [x] Task 7: 编写单元测试 (AC: #1-#5)
  - [x] 测试 AC#1: 简单表格渲染（验证 box-drawing 字符、列对齐、表头加粗）
  - [x] 测试 AC#1: 列数不一致的表格（不崩溃，缺失列填充空格）
  - [x] 测试 AC#1: 超宽单元格截断（追加 `...`）
  - [x] 测试 AC#1: 只有表头没有数据行的表格
  - [x] 测试 AC#2: 单行引用块渲染
  - [x] 测试 AC#2: 多行引用块渲染
  - [x] 测试 AC#3: `---` 渲染为 `─` 行
  - [x] 测试 AC#3: `***` 和 `___` 同样效果
  - [x] 测试 AC#4: `[text](url)` 渲染为下划线 text
  - [x] 测试 AC#5: H1 加粗 + `═` 装饰线
  - [x] 测试 AC#5: H2 加粗 + `─` 装饰线
  - [x] 测试 AC#5: H3-H6 仅加粗，无装饰线

## Dev Notes

### 核心修改区域：MarkdownRenderer.swift

所有改动集中在 `MarkdownRenderer.swift` 和 `ANSI.swift`。不修改 `OutputRenderer.swift`、`OutputRenderer+SDKMessage.swift` 或其他文件。

`MarkdownRenderer` 是一个 `enum`（纯静态方法），所有方法都是 `static func`。修改不影响任何现有接口。

### 现有架构分析

**`splitIntoBlocks` 方法（L137-189）**：
- 当前识别两种 block 类型：code block（``` 包裹）和 non-code（按双换行分割）
- Non-code 行在 `nonCodeBuffer` 中累积，按 `\n\n` 分割为 subBlocks
- 需要在这个方法中增加对表格行的识别——连续的 `|...|` 行应作为一个完整 block

**`renderBlock` 方法（L194-221）**：
- 当前检测顺序：code block → list block → heading → paragraph（fallback）
- 需要在 list block 检测之后、heading 检测之前添加：table → blockquote → horizontal rule
- 检测顺序很重要：table 行也包含 `|` 但不是普通 paragraph；blockquote 行以 `>` 开头但不是 list item

**`renderInline` 方法（L393-407）**：
- 当前处理 `**bold**` 和 `` `code` ``
- 使用 `replaceInlineMarker` 辅助方法处理配对分隔符
- 链接 `[text](url)` 的模式不同于简单配对分隔符（两种不同的分隔符），需要新的匹配逻辑

**`renderHeading` 方法（L297-313）**：
- 当前：H1-H2 都只是 `ANSI.bold(title)`，没有装饰线
- 注释中有 "H1 and H2: bold + underline visual separator for H1" 但实际没有实现装饰线
- 需要为 H1 追加 `═` 线、H2 追加 `─` 线

### ANSI.underline() 方法

`ANSI.swift` 当前没有 `underline()` 方法。需要添加：

```swift
/// Underline text styling.
static func underline(_ text: String) -> String {
    "\u{001B}[4m\(text)\u{001B}[0m"
}
```

这与现有的 `bold()`、`dim()`、`italic()` 方法模式一致。

### 表格解析关键细节

**检测表格行**：trim 后匹配 `^\|.*\|$` 模式（以 `|` 开头和结尾）。

**separator 行**：格式为 `|---|---|---|` 或 `| :---: | ---: | :--- |`（含对齐标记）。需要识别但跳过输出，仅用于确认表格结构。

**单元格提取**：将行按 `|` 分割，去掉首尾空元素（因为行以 `|` 开头和结尾会产生空字符串）。

**列宽计算**：遍历所有行（包括 header），每列取最大 `content.count`，加上 2（左右各 1 空格 padding）。

**box-drawing 字符**：
- 顶部边框：`┌` + `─` * width + `┬` + `─` * width + ... + `┐`
- 表头/数据分隔：`├` + `─` * width + `┼` + `─` * width + ... + `┤`
- 数据行：`│` + ` content ` + `│` + ...
- 底部边框：`└` + `─` * width + `┴` + `─` * width + ... + `┘`

**超宽截断**：如果某列内容宽度超过 `terminalWidth / columnCount`（或类似启发式），截断并追加 `...`。

**数字右对齐**（可选但推荐）：如果单元格内容是纯数字（`Int` 或 `Double`），使用 `String(format: "%*s", width, content)` 右对齐。参考 AC 示例中 `3` 和 `0` 的右对齐效果。

### splitIntoBlocks 修改策略

在 `splitIntoBlocks` 中，需要在 code block 处理和 non-code 处理之间增加表格行的聚合逻辑。策略：

1. 在 non-code 累积循环中，检测连续的 `|...|` 行
2. 当检测到表格开始（连续 2+ 行 `|...|` 行，含 separator），聚合为一个 block
3. 表格结束条件：空行或非 `|` 行
4. 将表格 block 整体作为一个 block 传入 `renderBlock`

或者更简洁的方案：在 `renderBlock` 中检测表格（类似 list block 的检测方式），检查 block 中所有行是否都是 `|...|` 格式。这样不需要修改 `splitIntoBlocks`。

**推荐方案**：不修改 `splitIntoBlocks`，在 `renderBlock` 中增加表格检测——如果 block 的所有非空行都以 `|` 开头，视为表格。这样改动最小。

### 引用块检测策略

在 `renderBlock` 中检测 blockquote：
- 如果 block 的所有非空行都以 `> ` 或 `>` 开头，视为 blockquote
- 注意：在 Markdown 中 `>` 后面不一定有空格（`>text` 也是合法引用）

### 分割线检测策略

在 `renderBlock` 中检测 horizontal rule：
- 单行 block，trim 后仅包含 `-`、`*`、`_` 字符（至少 3 个）
- 不能与 list item 混淆（`- text` 不是分割线，`---` 是）
- 不能与表格行混淆（`|---|` 包含 `|`，不是分割线）

### 链接正则匹配

在 `renderInline` 中添加链接匹配（在 bold 和 code 处理之后）：

```swift
// Inline link: [text](url)
// 使用简单的字符搜索而非正则，与现有的 replaceInlineMarker 模式一致
```

匹配逻辑：找到 `[`，然后找对应的 `](`，再找 `)`。替换为 `ANSI.underline(text)`。

注意：这与 `replaceInlineMarker` 的配对分隔符模式不同（`[` 和 `](` 和 `)` 三种分隔符），需要单独的匹配逻辑。

### 标题装饰线的长度计算

装饰线长度应与**渲染后的文本**等长，而不是原始 Markdown。因为标题文本经过 `ANSI.bold()` 包裹后包含 ANSI escape codes，不可见字符不应计入长度。

```swift
// 正确：用原始文本长度
let lineWidth = title.count  // "Title" → 5
let decoration = String(repeating: "═", count: lineWidth)
```

### 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `MarkdownRenderer.swift` | **修改** | 新增 `renderTable`、`renderBlockquote`、`renderHorizontalRule`、`renderLink` 方法；增强 `renderBlock` 的分支检测；增强 `renderHeading` 添加装饰线；增强 `renderInline` 支持链接语法 |
| `ANSI.swift` | **修改** | 新增 `underline()` 方法 |
| `MarkdownRendererTests.swift` | **扩展** | 添加表格、引用块、分割线、链接、标题装饰的测试用例 |

### 不需要修改的文件

- `OutputRenderer.swift` — MarkdownRenderer 是纯函数，在 MarkdownBuffer.append/flush 中被调用，不需要修改 OutputRenderer
- `OutputRenderer+SDKMessage.swift` — 渲染逻辑不变
- `REPLLoop.swift` — 不涉及输入处理
- `CLI.swift` — 不涉及
- `Package.swift` — 无新依赖
- `MarkdownBuffer`（OutputRenderer.swift 内）— 表格缓冲是 Story 10.3 的范畴，本 story 只处理完整 Markdown 文本的表格渲染

### 实现约束

- **不引入新的 SPM 依赖**——所有渲染基于 ANSI escape codes + Unicode box-drawing characters
- **不修改 `MarkdownBuffer`**——表格流式缓冲是 Story 10.3 的范畴
- **保持 `MarkdownRenderer` 为纯函数**——`render()` 输入 Markdown 字符串，输出格式化字符串，无副作用
- **保持 `renderInline` 的幂等性**——链接渲染应在 bold/code 之后处理，避免嵌套冲突
- **向后兼容**——现有测试（20 个 MarkdownRendererTests + 其他引用 MarkdownRenderer 的测试）不应受影响

### Project Structure Notes

```
Sources/OpenAgentCLI/
  MarkdownRenderer.swift  -- 修改：添加 5 个新 render 方法，增强 renderBlock/renderHeading/renderInline
  ANSI.swift              -- 修改：添加 underline() 方法

Tests/OpenAgentCLITests/
  MarkdownRendererTests.swift  -- 扩展：添加 ~12 个新测试用例
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md -- Epic 10, Story 10.2 L1362-1447]
- [Source: Sources/OpenAgentCLI/MarkdownRenderer.swift -- 全部：splitIntoBlocks, renderBlock, renderHeading, renderInline]
- [Source: Sources/OpenAgentCLI/ANSI.swift -- ANSI 颜色方法]
- [Source: Sources/OpenAgentCLI/OutputRenderer.swift -- MarkdownBuffer append/flush 调用 MarkdownRenderer]
- [Source: Tests/OpenAgentCLITests/MarkdownRendererTests.swift -- 现有 20 个测试模式]
- [Source: _bmad-output/implementation-artifacts/10-1-turn-labels-and-visual-separation.md -- 前一个 story 的实现模式]

### Previous Story Learnings (Story 10.1)

- `MarkdownBuffer` 是 `final class` + `@unchecked Sendable` + NSLock，可安全扩展状态
- `OutputRenderer` 是 `struct`，可变状态使用 class wrapper（`MarkdownBuffer`、`AnyTextOutputStream`）实现
- 822 全量测试通过，Epic 10.1 无回归
- Turn 标签在 `renderPartialMessage` 中通过 `turnHeaderPrinted` 状态管理
- Story 10.1 修改了 `OutputRenderer.swift`（MarkdownBuffer 扩展）和 `OutputRenderer+SDKMessage.swift`
- **本 Story (10.2) 不修改 OutputRenderer 系列**——只修改 MarkdownRenderer（纯函数）和 ANSI

### Git Intelligence (Recent Commits)

```
ffaf0ab feat: add turn labels and visual separation for multi-turn conversations — Story 10.1
e9c906d feat: enhance REPL skill invocation, tab completion and display
80105ef fix: replace linenoise-swift with CommandLineKit for CJK input support
681f0b2 fix: restore colored REPL prompt by setting terminal color before linenoise
15c31c3 feat: auto-discover skills from global dirs and fix terminal display issues
```

- Story 10.1 添加了 turn 标签和视觉分隔，修改了 OutputRenderer+SDKMessage.swift 和 OutputRenderer.swift
- Story 10.1 未修改 MarkdownRenderer.swift——Markdown 渲染保持稳定
- 所有 Epic 9 改动集中在 REPL 输入层，MarkdownRenderer 保持不变

### 关键实现细节

**1. 表格 block 检测在 `renderBlock` 中（不修改 `splitIntoBlocks`）**

`splitIntoBlocks` 按 `\n\n` 分割 block。Markdown 表格通常紧挨在一起（无空行），所以一个表格的 header + separator + data 行会在同一个 block 中。在 `renderBlock` 中检测：

```swift
// 检查是否是表格 block
let lines = trimmed.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
let tableLines = lines.filter { isTableLine($0) }
if tableLines.count >= 2 && tableLines.count == lines.count {
    return renderTable(tableLines)
}
```

其中 `isTableLine` 检查 trim 后以 `|` 开头且以 `|` 结尾。

**2. separator 行检测**

```swift
private static func isTableSeparator(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("|") && trimmed.hasSuffix("|") else { return false }
    let cells = trimmed.split(separator: "|", omittingEmptySubsequences: false)
    return cells.allSatisfy { cell in
        let content = cell.trimmingCharacters(in: .whitespaces)
        return content.allSatisfy { $0 == "-" || $0 == ":" }
    }
}
```

**3. 表格渲染的边框构建**

使用 Unicode box-drawing characters（项目已有使用：code block 用 `┌` `│` `└` `─`）。表格需要额外的 `┬` `┼` `┤` `├` `┴` `┐` 字符。

**4. 列数不一致处理**

以 header 行的列数为基准。数据行列数少于 header 的，用空字符串填充；多于 header 的，忽略多余的列。

**5. 分割线 vs 表格行的区分**

分割线 `---` 不包含 `|` 字符。表格行一定包含至少一个 `|`。在 `renderBlock` 中先检测表格（包含 `|`），再检测分割线（不包含 `|` 的纯 `-`/`*`/`_` 行）。

**6. 装饰线中 ANSI 长度问题**

标题文本经 `ANSI.bold()` 后包含 escape codes（如 `\u{001B}[1m...\u{001B}[0m`）。装饰线长度应基于原始文本的 visible 长度，不含 ANSI codes。用 `title.count`（原始文本长度）计算装饰线长度。

**7. `renderBlock` 检测顺序**

更新后的检测顺序：
1. Code block（``` 包裹）
2. Table block（所有行是 `|...|` 格式）
3. Blockquote block（所有行以 `> ` 开头）
4. Horizontal rule（单行，仅含 `-`/`*`/`_`）
5. List block（所有行是 list item）
6. Heading（单行 `#` 开头）
7. Paragraph（fallback）

**注意**：horizontal rule 必须在 list block 之后检测，因为 `---` 可能被误认为 list item（`-` 开头）。实际上 `---` 没有 `- ` 后面跟内容，所以 `isListLine` 不会匹配。但安全起见，检测顺序保持合理。

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- All 39 MarkdownRenderer tests pass (0 failures)
- Full regression suite: 838 tests pass (0 failures, 2 skipped)

### Completion Notes List

- Implemented table rendering with Unicode box-drawing characters (┌┬┐├┼┤└┴┘│─)
- Table header row rendered with ANSI.bold(); numeric cells right-aligned
- Wide cell truncation with "..." marker; column widths auto-calculated with terminal width constraints
- Blockquote rendering replaces "> " prefix with "│ " for each line
- Horizontal rule renders terminal-width "─" characters; detects ---, ***, ___
- Link rendering: [text](url) → ANSI.underline(text), URL hidden; supports multiple links per line
- H1 gets "═" decoration line, H2 gets "─" decoration line; H3-H6 unchanged
- Added ANSI.underline() method to ANSI.swift
- No changes to splitIntoBlocks; all new block types detected in renderBlock
- No changes to OutputRenderer, OutputRenderer+SDKMessage, or other files outside MarkdownRenderer + ANSI

### File List

| File | Operation | Description |
|------|-----------|-------------|
| `Sources/OpenAgentCLI/MarkdownRenderer.swift` | Modified | Added renderTable, renderBlockquote, renderHorizontalRule, replaceInlineLinks methods; added isTableLine, isTableSeparator, extractCells, isBlockquoteLine, isHorizontalRule helpers; updated renderBlock detection order; enhanced renderHeading with decoration lines; updated renderInline with link support |
| `Sources/OpenAgentCLI/ANSI.swift` | Modified | Added underline() method |
| `Tests/OpenAgentCLITests/MarkdownRendererTests.swift` | Existing | 16 new ATDD tests for Story 10.2 (already present as red-phase tests, now passing) |

### Change Log

- 2026-04-25: Story 10.2 implementation complete — all ACs satisfied, all tests passing, no regressions
