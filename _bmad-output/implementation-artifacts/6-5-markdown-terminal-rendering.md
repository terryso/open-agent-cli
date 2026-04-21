# Story 6.5: Markdown 终端渲染

Status: review

## Story

作为一个用户，
我想要 Agent 的响应在终端中以基本 Markdown 格式渲染，
以便代码块、标题和列表清晰可读。

## Acceptance Criteria

1. **假设** Agent 以 Markdown 格式的文本响应
   **当** 在终端中渲染
   **那么** 代码块带有可视边框显示
   **并且** 标题加粗显示
   **并且** 列表正确缩进

2. **假设** 检测到终端宽度
   **当** 渲染长行时
   **那么** 文本在终端宽度边界处换行

## Tasks / Subtasks

- [x] Task 1: 创建 MarkdownRenderer 模块 (AC: #1)
  - [x] 新建 `Sources/OpenAgentCLI/MarkdownRenderer.swift`
  - [x] 实现块级元素解析：代码块（fenced ```）、标题（# ~ ######）、有序/无序列表、段落
  - [x] 代码块渲染：上下边框（`┌───` / `└───`），左侧竖线（`│`），内容原样保留不换行
  - [x] 标题渲染：使用 `ANSI.bold()` 包裹，`#` 数量映射为视觉层级（`#` 最大，`######` 最小）
  - [x] 列表渲染：`- ` / `* ` 渲染为 `  • `，有序列表 `1. ` 保持原格式，嵌套层级每级缩进 2 空格
  - [x] 行内元素：`**bold**` → `ANSI.bold()`，`` `code` `` → `ANSI.cyan()` 或反色高亮
  - [x] 普通文本段落：保持原样输出，相邻段落间空行分隔

- [x] Task 2: 实现终端宽度检测与文本换行 (AC: #2)
  - [x] 在 `ANSI.swift` 或新工具方法中添加 `terminalWidth() -> Int` 函数
  - [x] 使用 `Foundation.Process` / `stty size` 获取终端列数，fallback 为 80
  - [x] 实现 `wordWrap(_ text: String, width: Int) -> String` 工具函数
  - [x] 长行在单词边界处换行，保持前导缩进
  - [x] 代码块内容不换行（原样输出），仅普通文本和列表项触发换行

- [x] Task 3: 集成到 OutputRenderer 流式管道 (AC: #1)
  - [x] 修改 `OutputRenderer+SDKMessage.swift` 的 `renderPartialMessage()` 方法
  - [x] **关键设计决策**：Markdown 渲染发生在 `.partialMessage` 累积完成之后，而非逐 chunk 渲染
  - [x] 方案 A（推荐）：在 `.result` 消息到达时，收集到的完整文本经过 MarkdownRenderer 后一次性渲染
  - [x] 方案 B（备选）：添加缓冲层，检测到段落/代码块结束时触发渲染
  - [x] 确保渲染不破坏现有的流式体验（思考内容标记 `[thinking]` 仍然用 dim 样式）
  - [x] quiet 模式下 Markdown 渲染仍然生效（quiet 只过滤消息类型，不过滤格式）

- [x] Task 4: 更新 ANSI.swift 添加所需样式方法 (AC: #1)
  - [x] 添加 `ANSI.green(_:)` 用于成功/代码高亮（如需要）
  - [x] 添加 `ANSI.italic(_:)` 用于斜体模拟（如需要，终端支持有限可跳过）
  - [x] 确保现有 `bold`、`dim`、`cyan`、`red`、`yellow` 方法可复用

- [x] Task 5: 添加测试覆盖 (AC: #1, #2)
  - [x] 测试：Markdown 代码块解析和边框渲染
  - [x] 测试：标题 `#` ~ `######` 的 bold 渲染
  - [x] 测试：有序/无序列表正确缩进
  - [x] 测试：行内 bold 和 code 的 ANSI 包裹
  - [x] 测试：`wordWrap` 在指定宽度处正确换行
  - [x] 测试：终端宽度检测 fallback 为 80
  - [x] 测试：普通文本（无 Markdown）原样输出不变形
  - [x] 测试：嵌套 Markdown（如列表中的代码）正确渲染
  - [x] 回归测试：所有现有测试通过

## Dev Notes

### 前一故事的关键学习

Story 6.4（思考配置与安静模式）完成后的项目状态：

1. **OutputRenderer 通过 `quiet` 属性控制渲染过滤** — Markdown 渲染层应在 quiet 过滤之后、实际写入 output 之前执行
2. **`renderPartialMessage()` 是逐 chunk 调用的** — 文本是流式到达的，每次调用只包含一小段文本。Markdown 渲染需要完整文本才有意义
3. **SDK 没有 `.thinking` 专用 case** — 思考内容通过 `[thinking]` 前缀在 `.partialMessage` 中到达，已用 `ANSI.dim()` 处理
4. **`OutputRenderer+SDKMessage.swift` 包含所有 SDKMessage case 的渲染** — 这是 Markdown 集成的主要修改文件
5. **`ANSI.swift` 已有 `bold`、`dim`、`red`、`cyan`、`yellow`、`reset`、`clear` 方法** — 可直接复用

### 当前实现分析

#### 流式文本的 Markdown 渲染挑战

**核心问题：** Agent 的响应通过 `.partialMessage` 逐 chunk 流式到达。一个 Markdown 代码块可能跨多个 chunk 分片到达（如第一个 chunk 是 `` ```sw``，第二个是 ``ift\n``，第三个是 `let x = 1\n`，最后一个 chunk 是 `` ``` ``）。逐 chunk 解析 Markdown 会导致：

1. 未完成的代码块无法确定边框
2. 标题可能被拆分到多个 chunk
3. 列表项可能不完整

**推荐方案：延迟渲染**

```
partialMessage chunks → 累积到 buffer
                         ↓
                   result 消息到达
                         ↓
                   MarkdownRenderer.transform(fullText)
                         ↓
                   写入 output（替换原始流式输出）
```

具体实现：
- `renderPartialMessage()` 正常流式输出文本（保持现有行为，用户看到逐字输出）
- 在 `.result(.success)` 到达时，**不做额外操作** — 因为文本已经写到了终端
- **替代方案**：改为缓冲模式 — `renderPartialMessage()` 将 chunk 累积到内部 buffer，不立即输出。当检测到完整段落/代码块/或 `.result` 时，对完整块应用 Markdown 渲染后输出

**权衡：**
- 缓冲方案牺牲了逐字流式体验，但获得正确的 Markdown 格式
- 混合方案（先流式输出 plain text，result 时重绘）在终端中难以实现（无法回退已输出的行）
- **最实用的方案**：保持流式体验不变，仅在"累积到完整块"时才做 Markdown 渲染。检测段落边界（双换行）和代码块边界（`` ``` ``）作为渲染触发点

**最终建议：** 使用"块级缓冲"策略：
1. 逐 chunk 累积到 buffer
2. 检测到块级边界（双换行 `\n\n`、代码块闭合 `` ``` ``）时，对完整块应用 Markdown 渲染并输出
3. 非块级文本（普通句子中间）继续流式输出不缓冲
4. 这样既保持了流式体验，又能在块级元素上正确渲染 Markdown

#### 需要修改的文件

**1. `Sources/OpenAgentCLI/MarkdownRenderer.swift`（新建）**

核心 Markdown 渲染逻辑：
```swift
enum MarkdownRenderer {
    /// 将 Markdown 文本转换为终端 ANSI 格式化输出
    static func render(_ markdown: String, terminalWidth: Int = 80) -> String

    /// 解析并渲染单个块级元素
    private static func renderBlock(_ block: String, terminalWidth: Int) -> String

    /// 渲染行内 Markdown 元素（bold、code、italic）
    private static func renderInline(_ text: String) -> String

    /// 单词级换行，保持前导缩进
    static func wordWrap(_ text: String, width: Int) -> String
}
```

**2. `Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift`（修改）**

修改 `renderPartialMessage()` 实现块级缓冲策略。添加 buffer 属性和块边界检测。

**3. `Sources/OpenAgentCLI/OutputRenderer.swift`（可能修改）**

如果缓冲状态需要存储在 OutputRenderer 实例上，需要将 `let` 改为可变状态或使用 class wrapper（与 `CostTracker` 模式一致）。

**4. `Sources/OpenAgentCLI/ANSI.swift`（可能修改）**

添加缺失的 ANSI 样式方法（如 `green`、`italic`）。

#### 不需要修改的文件

```
Sources/OpenAgentCLI/
  ArgumentParser.swift       # 无新 CLI 参数
  AgentFactory.swift          # 无 Agent 配置变更
  REPLLoop.swift              # REPL 逻辑不变
  PermissionHandler.swift     # 不涉及
  SessionManager.swift        # 不涉及
  MCPConfigLoader.swift       # 不涉及
  HookConfigLoader.swift      # 不涉及
  CLI.swift                   # 不涉及（OutputRenderer 创建不变）
  CLISingleShot.swift         # 可能微调，但非核心
  ConfigLoader.swift           # 不涉及
  Version.swift                # 不涉及
  main.swift                  # 不涉及
  SignalHandler.swift          # 不涉及
```

### SDK API 参考

本故事不直接使用新的 SDK API。Markdown 渲染完全在 CLI 层处理。

相关现有 API：
- `SDKMessage.PartialData.text` — 流式文本 chunk
- `SDKMessage.ResultData` — 查询完成信号
- 无 SDK-GAP 预期（纯终端渲染逻辑）

[Source: architecture.md#FR9 — "Markdown 终端渲染（MVP 后评估）"]
[Source: prd.md#FR9.1 — "支持 Markdown 渲染输出（终端兼容）"]

### 架构合规性

本故事涉及架构文档中的 **FR9.1**：

- **FR9.1:** 支持 Markdown 渲染输出（终端兼容）(P1) → MarkdownRenderer + OutputRenderer 集成

**FR 覆盖映射：**
- FR9.1 → Epic 6, Story 6.5 (本故事)

[Source: epics.md#Story 6.5]
[Source: prd.md#FR9.1]
[Source: architecture.md#FR9]

### 关键约束

1. **零 internal 访问** — 整个项目仅允许 `import OpenAgentSDK`
2. **零第三方依赖** — Markdown 解析必须手写，不引入外部库（与"无第三方 CLI 库"约束一致）
3. **不修改 SDK** — 如遇 SDK 限制，记录为 `// SDK-GAP:` 注释
4. **跨平台兼容** — ANSI 码在 macOS 和 Linux 终端上行为应一致。避免使用 macOS 专用 API
5. **保持流式体验** — 用户不应看到明显的输出延迟。Markdown 渲染应在块级边界快速执行

### 不要做的事

1. **不要引入第三方 Markdown 解析库** — 必须手写轻量解析器。项目约束明确："无第三方 CLI 库"。Markdown 渲染需求相对简单（代码块、标题、列表、行内格式），不值得引入依赖。

2. **不要试图实现完整的 Markdown 规范** — 只需支持：代码块、标题（#）、有序/无序列表、行内 bold 和 code。不需要支持表格、脚注、链接、图片等复杂元素。

3. **不要在 `.partialMessage` 逐 chunk 时就做 Markdown 解析** — 逐 chunk 解析会导致未完成元素渲染错误。使用块级缓冲策略。

4. **不要假设终端总是支持 ANSI** — 虽然现代 macOS/Linux 终端都支持，但应保持 graceful fallback（如果 ANSI 检测失败，输出 plain text）。

5. **不要修改 OutputRendering 协议** — Markdown 渲染是 OutputRenderer 的实现细节，不是协议要求。

6. **不要在代码块内做换行** — 代码块内容必须原样输出，保持用户的缩进和格式。只对普通文本和列表项做 word wrap。

7. **不要在 Markdown 渲染中处理 `[thinking]` 标记** — 思考内容的处理已在 Story 6.4 中实现，Markdown 渲染应跳过 `[thinking]` 前缀的文本。

8. **不要为 Markdown 渲染添加 CLI 开关** — PRD 和 Epics 中没有 `--markdown` 或 `--no-markdown` 参数。Markdown 渲染应默认启用，作为输出格式的一部分。

### 项目结构说明

本故事新建一个源文件，修改 2-3 个现有文件：

```
Sources/OpenAgentCLI/
  MarkdownRenderer.swift              # 新建：Markdown 解析和终端渲染
  OutputRenderer.swift                # 可能修改：添加 buffer 状态
  OutputRenderer+SDKMessage.swift     # 修改：集成 Markdown 渲染到流式管道
  ANSI.swift                          # 可能修改：添加新样式方法
```

新增测试文件：
```
Tests/OpenAgentCLITests/
  MarkdownRendererTests.swift         # 新建：Markdown 渲染单元测试
```

[Source: architecture.md#项目结构]

### 测试策略

**新增测试分布预期：**

| 测试方法名 | 覆盖 AC | 说明 |
|-----------|---------|------|
| testCodeBlock_rendersWithBorders | #1 | `` ```code``` `` 带边框显示 |
| testCodeBlock_preservesIndentation | #1 | 代码块内容原样保留 |
| testHeading_boldRendering | #1 | `#` ~ `######` 加粗渲染 |
| testHeading_differentLevels | #1 | 不同级别标题有不同视觉权重 |
| testUnorderedList_bulletAndIndent | #1 | `- item` 渲染为 `  • item` |
| testOrderedList_preservesNumbering | #1 | `1. item` 保持编号格式 |
| testNestedList_correctIndentation | #1 | 嵌套列表每级缩进 2 空格 |
| testInlineBold_ansiWrapped | #1 | `**text**` 被 `ANSI.bold()` 包裹 |
| testInlineCode_cyanOrHighlighted | #1 | `` `code` `` 被高亮样式包裹 |
| testPlainText_noModification | #1 | 无 Markdown 的文本原样输出 |
| testWordWrap_wrapsAtBoundary | #2 | 长行在指定宽度处换行 |
| testWordWrap_preservesIndent | #2 | 换行后保持前导缩进 |
| testTerminalWidth_fallbackTo80 | #2 | 无法检测时 fallback 为 80 列 |
| testMixedMarkdown_correctRendering | #1 | 混合元素（列表+代码）正确渲染 |
| testParagraphSeparation_blankLines | #1 | 段落间有空行分隔 |

**测试方法：**

1. **单元测试** — `MarkdownRenderer.render()` 是纯函数，输入 Markdown 字符串，输出 ANSI 格式化字符串。使用普通字符串断言验证输出包含正确的 ANSI 转义序列。

2. **集成测试** — 构造包含 Markdown 的 `SDKMessage.partialMessage` 序列，验证 OutputRenderer 的完整输出包含格式化内容。

3. **回归测试** — 确保所有现有测试继续通过。特别注意 `renderPartialMessage` 的修改不影响 `[thinking]` 处理和 quiet 模式。

### 终端宽度检测实现参考

```swift
static func terminalWidth() -> Int {
    // 方法 1: stty size（macOS + Linux 均可用）
    if let output = try? Process.runSync("/usr/bin/env", "stty", "size"),
       let parts = output.split(separator: " ").last.flatMap({ Int($0) }),
       parts > 0 {
        return parts
    }
    // 方法 2: COLUMNS 环境变量
    if let cols = ProcessInfo.processInfo.environment["COLUMNS"],
       let width = Int(cols), width > 0 {
        return width
    }
    // Fallback: 80 列标准终端宽度
    return 80
}
```

注意：`Process.runSync` 不是 Foundation 公共 API，需要用 `Pipe` + `Process` 实现。使用 `stty size` 在 stdin 是 tty 时可用；在管道/重定向场景下 fallback 为 80。

### Markdown 块级解析策略

```
输入文本 → 按双换行分割为块
           ↓
     对每个块判断类型：
     - 以 ``` 开头且以 ``` 结尾 → 代码块
     - 以 # 开头 → 标题
     - 以 - / * / + 开头 → 无序列表
     - 以数字. 开头 → 有序列表
     - 其他 → 普通段落
           ↓
     每种类型调用对应渲染函数
           ↓
     合并渲染结果，块间空行分隔
```

行内解析在块级渲染后对文本内容执行：
- `**bold**` → `ANSI.bold("bold")`
- `` `code` `` → `ANSI.cyan("code")`
- `*italic*` → 可选，终端斜体支持有限

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.5]
- [Source: _bmad-output/planning-artifacts/prd.md#FR9.1]
- [Source: _bmad-output/planning-artifacts/architecture.md#FR9]
- [Source: Sources/OpenAgentCLI/OutputRenderer.swift — render(), renderPartialMessage 路由]
- [Source: Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift — renderPartialMessage(), 现有渲染方法]
- [Source: Sources/OpenAgentCLI/ANSI.swift — ANSI 样式方法]
- [Source: _bmad-output/implementation-artifacts/6-4-thinking-configuration-and-quiet-mode.md — 前一故事]

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No debug issues encountered during implementation.

### Completion Notes List

- Created MarkdownRenderer.swift as a pure enum with render(), renderInline(), renderCodeBlock(), wordWrap(), and terminalWidth() static methods.
- Implemented block-level parsing: splits input into code blocks (preserving internal blank lines), headings, lists, and paragraphs.
- Code blocks rendered with Unicode box-drawing characters (U+250C, U+2502, U+2514, U+2500).
- Headings rendered with ANSI.bold(). All levels (H1-H6) use bold styling.
- Unordered lists use bullet (U+2022) with 2-space indent per nesting level. Ordered lists preserve numbering.
- Inline formatting: **bold** -> ANSI.bold(), `code` -> ANSI.cyan().
- Word wrap breaks at word boundaries, preserves leading indentation, respects terminal width.
- Terminal width detection via stty size -> COLUMNS env var -> fallback 80.
- Created MarkdownBuffer class in OutputRenderer.swift for streaming integration.
- Buffering strategy: regular text chunks receive inline Markdown formatting and are written immediately (preserving streaming UX). Only code blocks are buffered until the closing fence is detected.
- [thinking] content bypasses the Markdown buffer entirely -- written directly with ANSI.dim().
- markdownBuffer.flush() called in renderResult() and renderAssistant() to handle remaining buffered content.
- Added ANSI.green() and ANSI.italic() methods to ANSI.swift.
- ATDD test suite (MarkdownRendererTests.swift) was pre-generated and covers all acceptance criteria.
- Existing tests remain compatible: plain text passes through renderInline() unchanged.

### File List

- Sources/OpenAgentCLI/MarkdownRenderer.swift (new)
- Sources/OpenAgentCLI/OutputRenderer.swift (modified)
- Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift (modified)
- Sources/OpenAgentCLI/ANSI.swift (modified)
- Tests/OpenAgentCLITests/MarkdownRendererTests.swift (pre-existing ATDD tests)

### Change Log

- 2026-04-21: Story 6.5 implementation complete -- Markdown terminal rendering with code block borders, heading bold, list formatting, inline bold/code, word wrap, terminal width detection.
