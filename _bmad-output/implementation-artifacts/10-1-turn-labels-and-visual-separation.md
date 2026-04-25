# Story 10.1: Turn 标签与视觉分隔

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为一个用户，
我想要清楚地看到哪些是我说的、哪些是 AI 回复的，
以便我在多轮对话中不会迷失上下文。

## Acceptance Criteria

### AC#1: AI 文本 Turn 前缀

**Given** AI 开始回复文本
**When** `SDKMessage.partialMessage` 第一个 chunk 到达
**Then** 在文本前输出蓝色 `● ` 前缀（`\u{001B}[34m●\u{001B}[0m `）
**And** 后续 chunk 不再重复输出前缀

### AC#2: Turn 结束分隔

**Given** 一个完整的 Agent turn 结束
**When** `SDKMessage.result(data)` 到达且 `subtype == .success`
**Then** 在 result 分隔线前输出一个空行，视觉上与下一个 turn 分隔

### AC#3: 用户输入前缀（无改动）

**Given** 用户输入一条消息
**When** 消息被发送到 Agent
**Then** 用户输入行上方显示绿色 `> ` 前缀（已有，无需改动）

### AC#4: 工具调用前空行

**Given** 工具调用被触发
**When** `SDKMessage.toolUse` 到达
**Then** 工具调用行保持青色 `> toolName(args)`（已有），但在首个工具调用前输出空行与 AI 文本分隔

### AC#5: 工具结果（无改动）

**Given** 工具结果返回
**When** `SDKMessage.toolResult` 到达
**Then** 结果保持灰色缩进显示（已有）

### AC#6: 系统消息前空行

**Given** 系统消息到达
**When** `SDKMessage.system` 到达
**Then** 保持灰色 `[system]` 前缀（已有），前加空行分隔

### AC#7: 错误前空行

**Given** AI 回复过程中出现错误
**When** `SDKMessage.assistant` 包含 error
**Then** 错误信息以红色显示（已有），前加空行分隔

### 颜色方案总览

| 元素 | 前缀 | ANSI 颜色 | 示例 |
|------|------|-----------|------|
| 用户输入 | `> ` | 绿色 (32) | `> hello` |
| AI 文本 | `● ` | 蓝色 (34) | `● Here is the answer...` |
| 工具调用 | `> ` | 青色 (36) | `> Read(file_path: ...)` |
| 工具结果 | `  ` (缩进) | 默认/dim | `  file contents...` |
| 系统消息 | `[system]` | dim (2) | `[system] compaction...` |
| 错误 | `Error:` | 红色 (31) | `Error: rate limit` |
| 分隔线 | `---` | dim (2) | `--- Turns: 1 \| Cost: ...` |

## Tasks / Subtasks

- [x] Task 1: 在 OutputRenderer 中添加 turn 状态追踪 (AC: #1)
  - [x] 添加 `private var turnHeaderPrinted = false` 状态属性
  - [x] 在 `renderPartialMessage` 中，首个 chunk 时输出 `● ` 前缀并置 `turnHeaderPrinted = true`
  - [x] 在 `renderResult` 中重置 `turnHeaderPrinted = false`

- [x] Task 2: 修改 renderResult 添加空行分隔 (AC: #2)
  - [x] success 分隔线前输出 `\n`（已有 `\n` 在 `---` 前面，确保有两个 `\n`）
  - [x] 检查现有的 `\n---` 格式，确保视觉上有足够间距

- [x] Task 3: 修改 renderToolUse 添加前导空行 (AC: #4)
  - [x] 首个工具调用前（当 `turnHeaderPrinted == true` 时），输出空行 `\n`
  - [x] 同一 turn 内的后续工具调用不输出额外空行

- [x] Task 4: 修改 renderSystem 添加前导空行 (AC: #6)
  - [x] 在 `[system]` 行前输出 `\n`

- [x] Task 5: 修改 renderAssistant error 分支添加前导空行 (AC: #7)
  - [x] 在 error 行前输出 `\n`

- [x] Task 6: 确保 ANSI.swift 中有 `blue()` 方法 (AC: #1)
  - [x] 检查现有 `ANSI.blue()` 方法（已存在），确认 `● ` 前缀使用 `ANSI.blue("● ")` 或直接用 escape code

- [x] Task 7: 编写单元测试 (AC: #1-#7)
  - [x] 测试 AC#1: 首个 partialMessage 输出 `● ` 前缀，后续 chunk 不重复
  - [x] 测试 AC#1: thinking 内容不输出 `● ` 前缀
  - [x] 测试 AC#2: success result 前有空行
  - [x] 测试 AC#4: 首个 toolUse 前有空行（AI 文本后跟工具调用）
  - [x] 测试 AC#4: 连续 toolUse 间无额外空行
  - [x] 测试 AC#6: system 消息前有空行
  - [x] 测试 AC#7: assistant error 前有空行
  - [x] 测试完整 turn 周期：partialMessage -> toolUse -> toolResult -> partialMessage -> result，验证分隔符正确

## Dev Notes

### 核心设计：turn 状态追踪

在 `OutputRenderer` 中添加一个状态变量来追踪当前 turn 是否已输出 AI 前缀：

```swift
struct OutputRenderer: OutputRendering {
    // ... existing properties ...
    private var turnHeaderPrinted = false
}
```

**问题：`OutputRenderer` 是 `struct`（值类型），在 `render()` 方法中修改 `turnHeaderPrinted` 需要 `mutating`。** 但 `render()` 被协议 `OutputRendering` 声明为非 mutating。

**解决方案**：与 Story 9.5 类似的模式。Epic 9 的 dev notes 指出 `REPLLoop` 是 struct，使用 class wrapper 处理可变状态。`OutputRenderer` 的情况不同——它的 `render` 方法需要修改 `turnHeaderPrinted`，但 `OutputRendering` 协议的 `render` 不是 mutating。

**选项 A**：将 `turnHeaderPrinted` 包装在一个 class wrapper 中（类似 `AnyTextOutputStream` 模式）：

```swift
final class TurnState: @unchecked Sendable {
    private let lock = NSLock()
    private var _headerPrinted = false

    var headerPrinted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _headerPrinted
    }

    func markPrinted() {
        lock.lock()
        defer { lock.unlock() }
        _headerPrinted = true
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        _headerPrinted = false
    }
}
```

**选项 B**：将 `turnHeaderPrinted` 放入已有的 `MarkdownBuffer` class 中（它已经是 reference type）：

```swift
final class MarkdownBuffer: @unchecked Sendable {
    // ... existing ...
    private(set) var turnHeaderPrinted = false

    func markTurnHeaderPrinted() {
        turnHeaderPrinted = true
    }

    func resetTurnHeader() {
        turnHeaderPrinted = false
    }
}
```

**推荐选项 B**：将 turn 状态放入 `MarkdownBuffer`，因为：
1. `MarkdownBuffer` 已经是 class + `@unchecked Sendable` + lock-based
2. `MarkdownBuffer` 已经管理流式文本状态（`insideCodeBlock`）
3. `renderPartialMessage` 已经访问 `markdownBuffer`
4. 避免引入新的 class 类型

### 各 render 方法的修改

**renderPartialMessage**（`OutputRenderer+SDKMessage.swift` L18-25）：

```swift
func renderPartialMessage(_ data: SDKMessage.PartialData) {
    guard !data.text.isEmpty else { return }

    // AC#6 (thinking) 不输出 turn header
    if data.text.hasPrefix("[thinking]") {
        output.write(ANSI.dim(data.text))
        return
    }

    // AC#1: 首个 partialMessage 输出 AI turn 前缀
    if !markdownBuffer.turnHeaderPrinted {
        output.write(ANSI.blue("● ") + ANSI.reset())
        markdownBuffer.markTurnHeaderPrinted()
    }

    markdownBuffer.append(data.text)
}
```

**注意**：`ANSI.blue()` 已存在于 `ANSI.swift` L25-27，格式为 `\u{001B}[34m\(text)\u{001B}[0m`。但 `ANSI.reset()` 也会输出 `\u{001B}[0m`，导致双重 reset。改用直接 escape code：

```swift
output.write("\u{001B}[34m●\u{001B}[0m ")
```

或者利用已有的 `ANSI.blue("●")` + 手动空格：
```swift
output.write(ANSI.blue("●") + " ")
```

**推荐后者**——`ANSI.blue("●")` 产生 `\u{001B}[34m●\u{001B}[0m`，然后加空格 `" "` 分隔后续文本。这是最干净的方案。

**renderToolUse**（`OutputRenderer+SDKMessage.swift` L100-106）：

```swift
func renderToolUse(_ data: SDKMessage.ToolUseData) {
    // AC#4: 首个工具调用前输出空行与 AI 文本分隔
    if markdownBuffer.turnHeaderPrinted {
        output.write("\n")
    }
    let summary = summarizeInput(data.input)
    let line = summary.isEmpty
        ? ANSI.cyan("> \(data.toolName)")
        : ANSI.cyan("> \(data.toolName)(\(summary))")
    output.write("\(line)\n")
}
```

**注意**：在同一个 turn 中，首个 toolUse 会输出 `\n`。后续 toolUse 时 `turnHeaderPrinted` 仍为 true，也会输出 `\n`。但这是合理的——每个工具调用之间有空行分隔是良好的视觉体验。如果需要只在首个工具调用前输出空行（同 turn 后续工具调用间无空行），需要额外的 `firstToolInTurn` 状态。

**根据 AC#4 的描述**："在首个工具调用前输出空行与 AI 文本分隔"。这意味着只有首个工具调用前需要空行。需要添加第二个状态标志 `firstToolInTurn`：

```swift
// MarkdownBuffer 中添加
private(set) var firstToolInTurn = true

func markToolInTurn() {
    firstToolInTurn = false
}

func resetTurnHeader() {
    turnHeaderPrinted = false
    firstToolInTurn = true  // 同时重置
}
```

```swift
func renderToolUse(_ data: SDKMessage.ToolUseData) {
    // AC#4: 首个工具调用前输出空行与 AI 文本分隔
    if markdownBuffer.turnHeaderPrinted && markdownBuffer.firstToolInTurn {
        output.write("\n")
        markdownBuffer.markToolInTurn()
    }
    let summary = summarizeInput(data.input)
    // ... rest unchanged
}
```

**renderResult**（`OutputRenderer+SDKMessage.swift` L57-82）：

在 `markdownBuffer.flush()` 后添加 turn 状态重置：

```swift
func renderResult(_ data: SDKMessage.ResultData) {
    markdownBuffer.flush()

    // AC#2: 重置 turn 状态
    markdownBuffer.resetTurnHeader()

    switch data.subtype {
    case .success:
        let summary = formatSummary(data)
        output.write("\n--- \(summary)\n")
    // ... rest unchanged
    }
}
```

**注意**：现有的 success result 已经输出 `\n---`（`\n` 在 `---` 前），这个 `\n` 就是视觉分隔。AC#2 要求"在 result 分隔线前输出一个空行"——现有的 `\n---` 已经实现了这个效果（`\n` 产生空行效果，因为 Markdown 内容不以 `\n` 结尾，所以 `\n---` 产生的是一个空行 + `---` 行）。**无需额外修改 success 分支**。

但 cancelled 和 error 分支也已有 `\n---`。需要检查是否所有分支都已正确处理。

**renderSystem**（`OutputRenderer+SDKMessage.swift` L89-92）：

```swift
func renderSystem(_ data: SDKMessage.SystemData) {
    // AC#6: 系统消息前加空行
    output.write("\n")
    let line = ANSI.dim("[system] \(data.message)")
    output.write("\(line)\n")
}
```

**renderAssistant** error 分支（`OutputRenderer+SDKMessage.swift` L34-46）：

```swift
func renderAssistant(_ data: SDKMessage.AssistantData) {
    markdownBuffer.flush()

    guard let error = data.error else { return }

    // AC#7: 错误前加空行
    output.write("\n")
    let errorLine = ANSI.red("Error: \(error.rawValue)")
    let guidance = actionableGuidance(for: error)
    output.write("\(errorLine) -- \(guidance)\n")
}
```

### 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `OutputRenderer+SDKMessage.swift` | **修改** | renderPartialMessage 添加 `● ` 前缀；renderToolUse 添加空行；renderSystem 添加空行；renderAssistant error 添加空行；renderResult 添加状态重置 |
| `OutputRenderer.swift` | **修改** | MarkdownBuffer 添加 `turnHeaderPrinted`、`firstToolInTurn` 状态管理方法 |
| `ANSI.swift` | **无需修改** | `ANSI.blue()` 已存在 |
| `TurnLabelTests.swift` | **新建** | ~8-10 个测试用例 |

### 不需要修改的文件

- `REPLLoop.swift` — Turn 视觉分隔是渲染层关注点，不影响输入循环
- `CLI.swift` — REPL 入口不变
- `MarkdownRenderer.swift` — Markdown 渲染逻辑不变，turn 前缀在 Markdown buffer 之外
- `AgentFactory.swift` — Agent 创建不变
- `Package.swift` — 无新依赖

### 关键实现细节

**1. thinking 内容的 turn 前缀**

AC 说明 thinking 内容前不需要 `● ` 前缀。在 `renderPartialMessage` 中，thinking 内容（`[thinking]` 前缀）绕过 Markdown buffer 直接输出，但也应绕过 turn header 逻辑。因为 thinking 是 SDK 内部操作，不是 AI 的正式回复。

**2. 多轮工具调用的空行策略**

一个 AI turn 可能包含多个工具调用序列：
```
● Let me check that for you.

> Read(file_path: "a.swift")
  file contents...
> Bash(command: "swift build")
  Build complete.
● Here's the answer...
```

首个 toolUse 前有空行（与 AI 文本分隔），后续 toolUse 间无额外空行。toolResult 后紧跟下一个 toolUse 也无空行。

**3. 空行输出方式**

使用 `output.write("\n")` 输出空行。注意 `output` 是 `AnyTextOutputStream`，write 是线程安全的（NSLock）。

**4. Quiet 模式下的行为**

Quiet 模式下不渲染 toolUse、system 等消息（`OutputRenderer.render()` 的 quiet 分支只处理 partialMessage、assistant error 和非 success result）。因此：
- AC#1（`● ` 前缀）在 quiet 模式下仍应生效——quiet 模式渲染 partialMessage
- AC#2（result 空行）在 quiet 模式下仅对非 success result 生效
- AC#4, #6, #7 在 quiet 模式下不适用（这些消息类型被静默）

需要确保 `turnHeaderPrinted` 在 quiet 模式下也正确管理，否则从 quiet 模式渲染 partialMessage 后再渲染 non-success result 时状态不一致。

**5. turn 状态在 result 后的重置时机**

`resetTurnHeader()` 在 `renderResult` 的 `flush()` 之后立即调用，确保下一个 turn 的首个 partialMessage 能正确输出 `● ` 前缀。这适用于所有 result subtype（success、cancelled、error）。

### Project Structure Notes

```
Sources/OpenAgentCLI/
  OutputRenderer+SDKMessage.swift  -- 修改：5 个 render 方法添加前缀/空行逻辑
  OutputRenderer.swift             -- 修改：MarkdownBuffer 添加 turn 状态管理

Tests/OpenAgentCLITests/
  TurnLabelTests.swift             -- 新建：turn 标签和视觉分隔测试
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md -- Epic 10, Story 10.1 L1309-1361]
- [Source: Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift -- 所有 render 方法]
- [Source: Sources/OpenAgentCLI/OutputRenderer.swift -- OutputRenderer struct + MarkdownBuffer class]
- [Source: Sources/OpenAgentCLI/ANSI.swift -- ANSI.blue() L25-27]
- [Source: Tests/OpenAgentCLITests/OutputRendererTests.swift -- 测试模式参考]
- [Source: _bmad-output/implementation-artifacts/9-5-multiline-input.md -- Story 9.5 struct 可变状态处理模式]

### Previous Story Learnings (Epic 9)

- `OutputRenderer` 是 `struct`，`OutputRendering` 协议的 `render` 方法是非 mutating
- 可变状态使用 class wrapper（`AnyTextOutputStream`、`MarkdownBuffer`）实现
- `MarkdownBuffer` 已是 `final class` + `@unchecked Sendable` + NSLock，可安全扩展状态
- 测试使用 `MockTextOutputStream` 捕获输出，`makeRenderer()` 辅助方法创建 (renderer, mock) 对
- 802+ 全量测试通过，Epic 9 所有 story 无回归
- `REPLLoop` 不需要修改——视觉分隔是渲染层关注点
- Epic 9 未修改 `OutputRenderer` 和 `AgentFactory`

### Git Intelligence (Recent Commits)

```
e9c906d feat: enhance REPL skill invocation, tab completion and display
80105ef fix: replace linenoise-swift with CommandLineKit for CJK input support
681f0b2 fix: restore colored REPL prompt by setting terminal color before linenoise
15c31c3 feat: auto-discover skills from global dirs and fix terminal display issues
8bcdb05 feat: add multiline input support with backslash continuation and triple-quote mode
```

- Story 9.5 修改了 `REPLLoop.swift` 和 `ANSI.swift`，未触及 OutputRenderer
- Story 9.4 修改了 `TabCompletionProvider.swift`、`LinenoiseInputReader.swift`、`CLI.swift`
- linenoise-swift 被替换为 CommandLineKit（commit 80105ef），但这不影响 OutputRenderer
- 所有 Epic 9 改动集中在 REPL 输入层，OutputRenderer 保持稳定

### 实现约束

- **不引入新的 SPM 依赖**——所有渲染基于 ANSI escape codes
- **不修改 `OutputRendering` 协议**——turn 状态在实现层管理
- **不修改 `REPLLoop`**——视觉分隔不影响输入循环
- **保持 backward compatible**——`OutputRenderer` 的 `init` 签名不变
- **`ANSI.swift` 不需修改**——`ANSI.blue()` 已存在（L25-27），返回 `\u{001B}[34m\(text)\u{001B}[0m`

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

### Completion Notes List

- Task 1: Added `turnHeaderPrinted` and `firstToolInTurn` state properties to `MarkdownBuffer` class in OutputRenderer.swift. Added `markTurnHeaderPrinted()`, `markToolInTurn()`, and `resetTurnHeader()` methods. Used Option B from Dev Notes (extend MarkdownBuffer rather than creating new class).
- Task 2: Verified existing `\n---` format in `renderResult` provides visual blank line separation. Added `markdownBuffer.resetTurnHeader()` call after `flush()` to reset turn state for all result subtypes.
- Task 3: Added blank line (`\n`) before first toolUse in a turn when `turnHeaderPrinted == true && firstToolInTurn == true`. Subsequent tool calls in same turn do not get extra blank line.
- Task 4: Added leading `\n` before `[system]` line in `renderSystem`.
- Task 5: Added leading `\n` before error message in `renderAssistant` error branch.
- Task 6: Confirmed `ANSI.blue()` already exists. Used `ANSI.blue("●") + " "` for the bullet prefix.
- Task 7: All 20 ATDD tests pass (10 were previously failing, now green). Updated 4 existing tests in OutputRendererTests.swift and ThinkingAndQuietModeTests.swift to account for new bullet prefix in partialMessage output. Full regression suite: 822 tests pass, 0 failures.

### Change Log

- 2026-04-25: Implemented turn labels and visual separation (Story 10.1). All 7 ACs satisfied. 20 ATDD tests pass, 822 total tests pass with 0 regressions.

### File List

- Sources/OpenAgentCLI/OutputRenderer.swift -- Modified: Added `turnHeaderPrinted`, `firstToolInTurn` state and management methods to MarkdownBuffer
- Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift -- Modified: Added bullet prefix in renderPartialMessage, blank lines in renderToolUse/renderSystem/renderAssistant error, state reset in renderResult
- Tests/OpenAgentCLITests/TurnLabelsTests.swift -- Pre-existing (ATDD red phase): 20 tests for turn labels
- Tests/OpenAgentCLITests/OutputRendererTests.swift -- Modified: Updated 3 test assertions to include blue bullet prefix
- Tests/OpenAgentCLITests/ThinkingAndQuietModeTests.swift -- Modified: Updated 1 test assertion to include blue bullet prefix
