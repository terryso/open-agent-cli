# Story 10.3: 流式场景下的表格缓冲与渲染

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为一个用户，
我想要在 AI 流式输出表格时看到完整的渲染效果而非碎片，
以便表格不会在流式过程中变形或闪烁。

## Acceptance Criteria

### AC#1: 表格行检测与缓冲进入

**Given** AI 流式输出中开始一个表格（首个 chunk 包含 `| Name |`）
**When** `MarkdownBuffer.append()` 检测到表格行开始（非 code-block 状态下匹配 `|...|` 模式）
**Then** 后续 chunk 被缓冲，直到检测到表格结束（非 `|` 行或空行）
**And** 缓冲期间不输出任何表格内容到终端

### AC#2: 表格完成时一次性渲染

**Given** AI 流式输出中一个完整的表格已被缓冲
**When** 检测到表格结束条件（空行、非 `|` 开头的行、或 flush）
**Then** 整个表格一次性通过 `MarkdownRenderer.renderTable()` 渲染输出
**And** 渲染结果与 Story 10.2 的完整表格渲染完全一致（box-drawing 边框、列对齐、表头加粗）

### AC#3: 多个独立表格缓冲

**Given** AI 在流式输出中产生多个表格
**When** 每个表格独立缓冲和渲染
**Then** 每个表格都正确渲染，互不干扰
**And** 表格之间的非表格文本正常即时输出

### AC#4: Chunk 边界拼接

**Given** AI 输出的表格跨越多个 chunk 且 chunk 在单元格中间拆分（如 `| Nam` + `e | Status |`）
**When** 缓冲区累积内容
**Then** 正确拼接后在表格结束时渲染，不因 chunk 边界导致格式错误

### AC#5: 中断时最佳努力渲染

**Given** AI 的回复在表格中间被中断（如用户 Ctrl+C）
**When** `MarkdownBuffer.flush()` 被调用
**Then** 已缓冲的表格内容以最佳努力渲染（可能不完整但不崩溃）
**And** 不完整的表格仍尝试 box-drawing 渲染（有 header + 部分 data 行）

### AC#6: 表格后正常文本恢复

**Given** 表格后紧跟非表格文本
**When** 流式继续
**Then** 非表格文本正常通过 `renderInline` 即时输出

## Tasks / Subtasks

- [x] Task 1: 在 MarkdownBuffer 中添加表格缓冲状态机 (AC: #1, #3)
  - [x] 添加 `private var insideTableBlock = false` 状态标志
  - [x] 添加 `isTableLine()` 检测辅助方法（复用 MarkdownRenderer.isTableLine 逻辑或直接引用）
  - [x] 修改 `append()` 方法：在 non-code-block 路径中检测表格行开始
  - [x] 进入表格缓冲模式时：设置 `insideTableBlock = true`，开始累积 chunk
  - [x] 保持在表格缓冲模式中：持续累积 chunk，不输出

- [x] Task 2: 实现表格结束检测和渲染 (AC: #2, #6)
  - [x] 在 `append()` 中检测表格结束条件：空行或非 `|` 行出现
  - [x] 表格结束时：将缓冲内容通过 `MarkdownRenderer.renderTable()` 一次性渲染
  - [x] 表格结束后的非表格内容：按原逻辑处理（`renderInline` 即时输出或继续缓冲）
  - [x] 重置 `insideTableBlock = false`

- [x] Task 3: 处理多个独立表格 (AC: #3)
  - [x] 确保状态机在表格结束后正确重置
  - [x] 第二个表格的开始应重新进入缓冲模式
  - [x] 表格之间的文本正常通过 `renderInline` 输出

- [x] Task 4: 处理 chunk 边界拼接 (AC: #4)
  - [x] 表格内容可能跨多个 chunk 到达，每次 append 累积到 buffer
  - [x] 在检测表格结束前，不尝试解析不完整的行
  - [x] 表格结束后，对完整 buffer 内容执行渲染

- [x] Task 5: 实现 flush 时最佳努力渲染 (AC: #5)
  - [x] 修改 `flush()` 方法：如果 `insideTableBlock == true`，对已有缓冲内容尝试表格渲染
  - [x] 使用 `MarkdownRenderer.render()` 处理（它会调用 renderBlock → renderTable）
  - [x] 不完整的表格交给 MarkdownRenderer 处理——单行 `|...|` 不会匹配表格条件（需 >= 2 行），此时按 paragraph fallback

- [x] Task 6: 编写单元测试 (AC: #1-#6)
  - [x] 测试 AC#1: 单行 `|` chunk 触发缓冲模式
  - [x] 测试 AC#2: 完整表格缓冲后一次性 box-drawing 渲染
  - [x] 测试 AC#3: 两个独立表格各自正确渲染
  - [x] 测试 AC#4: chunk 在单元格中间拆分的拼接渲染
  - [x] 测试 AC#5: flush 时不完整表格的最佳努力渲染（不崩溃）
  - [x] 测试 AC#6: 表格后文本正常即时输出
  - [x] 测试回归：code block 缓冲不受影响
  - [x] 测试回归：普通文本即时输出不受影响

## Dev Notes

### 核心修改区域：MarkdownBuffer（OutputRenderer.swift）

本 Story 的所有改动集中在 `MarkdownBuffer` 类（位于 `OutputRenderer.swift` L58-192）。**不修改 MarkdownRenderer.swift、ANSI.swift 或 OutputRenderer+SDKMessage.swift。**

### 现有 MarkdownBuffer 架构分析

**MarkdownBuffer 是 `final class` + `@unchecked Sendable`，线程安全通过 `NSLock` 保证。**

当前 `append()` 方法（L92-108）的核心逻辑：

```
if insideCodeBlock:
    buffer += chunk
    tryFlushCodeBlock()
elif chunk.contains("```"):
    buffer += chunk
    insideCodeBlock = true
    tryFlushCodeBlock()
else:
    // 正常流式文本：即时渲染
    output.write(MarkdownRenderer.renderInline(chunk))
```

**关键理解**：当前只有两个状态——`insideCodeBlock` 和普通模式。需要添加第三个状态 `insideTableBlock`。

### 表格缓冲状态机设计

在 `else` 分支（普通模式）中添加表格检测逻辑。新的状态优先级：

1. **insideCodeBlock** — 最高优先级，code block 缓冲
2. **insideTableBlock** — 新增，表格缓冲
3. **普通模式** — `renderInline` 即时输出

**核心挑战**：chunk 是任意拆分的，一个 chunk 可能包含：
- 只有表格行的一部分（如 `| Nam`）
- 完整的一行或多行表格行（如 `| Name | Status |\n|------|--------|\n`）
- 表格行 + 后续普通文本（如 `| bar | idle | 0 |\n\nSome text after`）

**解决方案**：在普通模式下，每次 append 时将 chunk 累积到临时缓冲区（tableBuffer），然后扫描是否包含完整的表格。具体策略：

```swift
// 新增状态
private var _insideTableBlock = false

// append() 中新的 else 分支逻辑：
// 1. 如果 insideTableBlock == true，累积到 buffer
// 2. 检查累积内容中是否有表格结束（空行/非|行）
// 3. 如果 insideTableBlock == false，检查新 chunk 是否触发了表格开始
```

**更精确的实现策略**：

```swift
func append(_ chunk: String) {
    lock.lock()
    defer { lock.unlock() }

    if insideCodeBlock {
        buffer += chunk
        tryFlushCodeBlock()
    } else if chunk.contains("```") {
        buffer += chunk
        insideCodeBlock = true
        tryFlushCodeBlock()
    } else if _insideTableBlock {
        // 已经在表格缓冲中
        buffer += chunk
        tryFlushTableBlock()
    } else {
        // 普通模式：检查是否进入表格缓冲
        // 策略：将 chunk 累积，检查是否出现表格行模式
        buffer += chunk
        if detectTableStart() {
            _insideTableBlock = true
            tryFlushTableBlock()
        } else {
            // 不是表格，输出缓冲内容并清空
            output.write(MarkdownRenderer.renderInline(buffer))
            buffer = ""
        }
    }
}
```

**表格检测逻辑 `detectTableStart()`**：

扫描 buffer 中的行，检查是否有 >= 2 行匹配 `|...|` 模式（其中一行可以是 separator）。这与 MarkdownRenderer 中的 `isTableLine` 逻辑一致。

**表格结束检测 `tryFlushTableBlock()`**：

扫描 buffer，从表格区域之后检查：
- 空行（`\n\n`）：表格结束
- 非 `|` 行：表格结束
- buffer 仍在表格中：继续缓冲

```swift
private func tryFlushTableBlock() {
    let lines = buffer.components(separatedBy: "\n")

    // 找到表格结束位置
    var tableEndIndex = lines.count
    for (i, line) in lines.enumerated() {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if i > 0 && !trimmed.isEmpty && !isTableLine(trimmed) {
            tableEndIndex = i
            break
        }
    }

    if tableEndIndex < lines.count {
        // 表格结束：渲染表格部分
        let tableLines = Array(lines[0..<tableEndIndex])
        let tableContent = tableLines.joined(separator: "\n")
        output.write(MarkdownRenderer.render(tableContent))

        // 处理剩余内容
        let remainingLines = Array(lines[tableEndIndex...])
        let remaining = remainingLines.joined(separator: "\n")
        buffer = ""
        _insideTableBlock = false

        if !remaining.trimmingCharacters(in: .whitespaces).isEmpty {
            // 递归处理剩余内容
            append(remaining)
        }
    }
    // else: 表格尚未结束，继续缓冲
}
```

**重要**：`isTableLine` 检测方法已在 `MarkdownRenderer` 中存在（L551-556），但它 是 `private static`。需要考虑：
- **方案 A**：在 MarkdownBuffer 中复制 `isTableLine` 逻辑（简单，无耦合）
- **方案 B**：将 MarkdownRenderer.isTableLine 改为 `static`（非 private）或 internal
- **推荐方案 A**：MarkdownBuffer 中的检测可以更简单——只需检查 trim 后是否以 `|` 开头且以 `|` 结尾，不需要完整的表格验证

### flush() 修改

```swift
func flush() {
    lock.lock()
    defer { lock.unlock() }

    guard !buffer.isEmpty else { return }
    if insideCodeBlock {
        let rendered = MarkdownRenderer.renderCodeBlock(buffer)
        output.write(rendered)
    } else if _insideTableBlock {
        // AC#5: 最佳努力渲染不完整表格
        // MarkdownRenderer.render() 会处理：>= 2 行的表格行走 renderTable，
        // < 2 行的走 paragraph fallback
        let rendered = MarkdownRenderer.render(buffer)
        output.write(rendered)
        _insideTableBlock = false
    } else {
        output.write(MarkdownRenderer.render(buffer))
    }
    buffer = ""
    insideCodeBlock = false
}
```

### 潜在陷阱与防护

1. **表格检测误判**：单个 `|` 出现在普通文本中（如 `a | b`）不应触发表格缓冲。检测条件要求 >= 2 行连续的 `|...|` 行。

2. **separator 行识别**：`|---|---|` 是表格的一部分，不应被视为水平分割线。MarkdownRenderer 已处理此逻辑。

3. **code block 优先**：如果 chunk 同时包含 `|...|` 和 ``` ，code block 检测优先。现有代码中 `chunk.contains("```")` 分支在表格检测之前。

4. **空 chunk**：`data.text.isEmpty` 的 guard 在 `renderPartialMessage` 中已处理，但 MarkdownBuffer.append 本身也应防御空字符串。

5. **混合内容 chunk**：一个 chunk 可能是 `| a |\n| b |\n\nSome text`。需要在 `tryFlushTableBlock` 中正确分割表格和非表格部分。

### 不需要修改的文件

- `MarkdownRenderer.swift` — 渲染逻辑完整，本 story 只修改缓冲逻辑
- `ANSI.swift` — 无新 ANSI 方法需要
- `OutputRenderer+SDKMessage.swift` — `append()` 和 `flush()` 的调用方式不变
- `REPLLoop.swift` — 不涉及
- `CLI.swift` — 不涉及
- `Package.swift` — 无新依赖

### 实现约束

- **不修改 MarkdownRenderer** — 表格渲染已在 Story 10.2 完整实现，本 story 只在 MarkdownBuffer 层添加缓冲
- **不修改 OutputRenderer+SDKMessage.swift** — 调用接口不变
- **保持 MarkdownBuffer 线程安全** — 所有状态变更在 lock 保护内
- **向后兼容** — 现有 838+ 测试不应受影响

### Project Structure Notes

```
Sources/OpenAgentCLI/
  OutputRenderer.swift  -- 修改：MarkdownBuffer 添加表格缓冲状态机

Tests/OpenAgentCLITests/
  MarkdownBufferTests.swift  -- 新建：MarkdownBuffer 表格缓冲的单元测试
```

**注意**：当前没有 MarkdownBuffer 的直接单元测试（MarkdownBuffer 是 internal class，在 OutputRendererTests 中通过 OutputRenderer 间接测试）。需要新建专门的测试文件或扩展现有测试。

**测试策略**：直接创建 MarkdownBuffer 实例进行测试。MarkdownBuffer 的 init 接受 `AnyTextOutputStream`，测试中可用 MockOutputStream 捕获输出。参考 OutputRendererTests 中已有的 `MockTextOutputStream` 模式（L33-43）。

### References

- [Source: _bmad-output/planning-artifacts/epics.md -- Epic 10, Story 10.3 L1449-1482]
- [Source: Sources/OpenAgentCLI/OutputRenderer.swift -- MarkdownBuffer class L58-192]
- [Source: Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift -- renderPartialMessage, renderResult 调用 append/flush]
- [Source: Sources/OpenAgentCLI/MarkdownRenderer.swift -- isTableLine L551-556, renderTable L583-706]
- [Source: _bmad-output/implementation-artifacts/10-2-markdown-table-and-block-element-rendering.md -- 前一个 story 的完整实现记录]
- [Source: Tests/OpenAgentCLITests/OutputRendererTests.swift -- MockTextOutputStream 模式 L33-43]

### Previous Story Learnings (Story 10.2)

- 838 全量测试通过（0 failures, 2 skipped），Epic 10.2 无回归
- `MarkdownRenderer.isTableLine()` 是 `private static`——MarkdownBuffer 需要自己实现表格行检测或通过 `MarkdownRenderer.render()` 间接触发
- `MarkdownRenderer.renderTable()` 接受 `[String]` 参数（表格行数组），通过 `MarkdownRenderer.render()` -> `renderBlock()` -> `renderTable()` 链路调用
- 表格检测条件：`tableLines.count >= 2 && tableLines.count == lines.count`（所有行都是表格行且 >= 2 行）
- separator 行（`|---|---|`）在 MarkdownRenderer 中被正确跳过
- Story 10.2 不修改 OutputRenderer.swift——MarkdownBuffer 未变，本 Story 才是 MarkdownBuffer 的改动点
- `MarkdownBuffer` 是 `final class` + `@unchecked Sendable` + NSLock，可安全扩展状态变量

### Previous Story Learnings (Story 10.1)

- `MarkdownBuffer` 可变状态使用 class wrapper 实现
- Turn 标签通过 `turnHeaderPrinted` 状态管理，在 `renderPartialMessage` 中输出 `● ` 前缀
- `resetTurnHeader()` 在 `renderResult` 时调用——确保 flush() 在 resetTurnHeader() 之前调用（当前代码顺序：flush → resetTurnHeader）

### Git Intelligence (Recent Commits)

```
1323a0c feat: add markdown table, blockquote, horizontal rule and link rendering — Story 10.2
ffaf0ab feat: add turn labels and visual separation for multi-turn conversations — Story 10.1
e9c906d feat: enhance REPL skill invocation, tab completion and display
80105ef fix: replace linenoise-swift with CommandLineKit for CJK input support
681f0b2 fix: restore colored REPL prompt by setting terminal color before linenoise
```

- Story 10.2 添加了 MarkdownRenderer 的表格/引用块/分割线/链接渲染，MarkdownBuffer 未修改
- Story 10.1 修改了 MarkdownBuffer（添加 turn 状态），OutputRenderer+SDKMessage.swift（添加 turn 标签逻辑）
- 所有 Epic 9 改动集中在 REPL 输入层

## Dev Agent Record

### Agent Model Used

Claude Code (prior session implementation, verified by GLM-5.1)

### Debug Log References

### Completion Notes List

- All 6 tasks completed: table buffering state machine, end detection, multi-table support, chunk boundary splicing, flush best-effort, unit tests
- 23 ATDD tests all pass (StreamingTableBufferTests)
- Full suite: 586 tests pass with 0 failures, 0 regressions
- Implementation matches all 6 acceptance criteria (AC#1-AC#6)
- No modifications to MarkdownRenderer.swift, ANSI.swift, or OutputRenderer+SDKMessage.swift (as required)

### File List

- `Sources/OpenAgentCLI/OutputRenderer.swift` -- Modified: Added table buffering state machine to MarkdownBuffer (`insideTableBlock`, `isTableLine()`, `detectTableStart()`, `mightBeStartingTable()`, `flushSafePrefix()`, `tryFlushTableBlock()`, `processRemainingContent()`, updated `append()` and `flush()`)
- `Tests/OpenAgentCLITests/StreamingTableBufferTests.swift` -- New: 23 unit tests covering all ACs plus regression and edge cases

### Change Log

- 2026-04-26: Story 10.3 implementation verified complete -- all tasks done, 23/23 tests pass, 586/586 suite pass, no regressions
- 2026-04-26: Code review (yolo) -- 1 patch applied (bufferHasPlausibleTableContent guard), 2 dismissed. Status: done.

### Review Findings

- [x] [Review][Patch] `mightBeStartingTable()` causes indefinite buffering of non-table text starting with `|` [Sources/OpenAgentCLI/OutputRenderer.swift:L119] -- **Fixed:** Added `bufferHasPlausibleTableContent()` guard that prevents buffering when content is clearly not a table (multi-line with zero table lines, or single line >100 chars with no closing `|`). Real table fragments still buffer correctly.
- [x] [Review][Dismiss] `isTableLine()` count >= 2 passes for `||` -- handled gracefully downstream, no user-visible impact.
- [x] [Review][Dismiss] Empty chunk guard is redundant with caller's guard -- defensive coding, correct addition.
