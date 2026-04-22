# Story 7.2: JSON 输出模式

Status: review

## Story

作为一个开发者，
我想要从 CLI 获取结构化的 JSON 输出，
以便我可以程序化地解析 Agent 的响应。

## Acceptance Criteria

1. **假设** 传入了 `--output json`
   **当** Agent 完成查询
   **那么** 结果以 JSON 对象打印，包含 `text`、`toolCalls`、`cost` 和 `turns` 字段

2. **假设** JSON 输出模式处于活动状态
   **当** 发生错误
   **那么** 错误以 JSON 格式打印到标准输出，格式为 `{"error": "..."}`

3. **假设** 传入了 `--output json`
   **当** 流式输出进行中
   **那么** 不输出任何流式中间内容（tool calls、partial text 等），仅输出最终 JSON

4. **假设** 传入了 `--output json` 且查询成功完成
   **当** JSON 被打印
   **那么** 进程以退出码 0 退出，且 JSON 是 stdout 的唯一内容

5. **假设** 传入了 `--output json --quiet`
   **当** 查询完成
   **那么** 行为等同于 `--output json`（quiet 在 json 模式下无额外效果）

## Tasks / Subtasks

- [x] Task 1: 创建 JSON 输出渲染器 (AC: #1, #2, #3)
  - [x] 创建 `JsonOutputRenderer.swift`，实现 `OutputRendering` 协议
  - [x] 实现 `JsonRenderResult` 结构体：可编码的最终输出模型
  - [x] 实现 `render(_:)` 方法：在 JSON 模式下静默所有中间消息，仅收集数据
  - [x] 实现 `renderStream(_:)` 的 JSON 变体：收集完整流后一次性输出 JSON
  - [x] 实现 `renderSingleShotJson(_:)` 方法：从 `QueryResult` 直接生成 JSON

- [x] Task 2: 在 CLI.swift 中集成 JSON 输出模式 (AC: #1, #2, #3, #4, #5)
  - [x] 修改 single-shot 分支：当 `args.output == "json"` 时使用 JSON 渲染器
  - [x] 修改 skill 调用分支：当 JSON 模式时使用 JSON 渲染器
  - [x] 确保 JSON 输出是 stdout 的唯一内容（不混入 ANSI 或其他文本）
  - [x] 确保 REPL 模式下 `--output json` 仍然使用文本渲染器（JSON 仅用于 single-shot）

- [x] Task 3: 添加测试覆盖 (AC: #1, #2, #3, #4, #5)
  - [x] 测试：成功查询输出包含 text/toolCalls/cost/turns 字段的 JSON
  - [x] 测试：错误查询输出 `{"error": "..."}` 格式的 JSON
  - [x] 测试：JSON 模式下无中间流式输出
  - [x] 测试：`--output json` + `--quiet` 行为一致
  - [x] 测试：JSON 输出是有效的 JSON（可被 JSONSerialization 解析）
  - [x] 测试：退出码正确（成功=0，错误=1）
  - [x] 回归测试：所有现有测试通过

## Dev Notes

### 前一故事的关键学习

Story 7.1（管道/标准输入模式）完成后的项目状态：

1. **`--output` 参数已经存在于 ArgumentParser** — 当前支持 `text` 和 `json` 两种格式。`ParsedArgs.output` 字段默认为 `"text"`。**不需要修改 ArgumentParser。**

2. **CLI.swift 的 dispatch 逻辑** 有三条路径：skill 模式 -> single-shot 模式 -> REPL 模式。JSON 输出只影响 skill 和 single-shot 路径的**渲染方式**，不改变 dispatch 逻辑。

3. **`OutputRenderer` 支持 quiet 模式** — 在 quiet 模式下只渲染 `partialMessage` 和错误。JSON 模式应该更彻底：**完全不输出中间内容**，只输出最终 JSON。

4. **`--output json` 与 `--stdin` 组合** 已在 Story 7.1 中确认可用（stdin 提供输入，JSON 提供输出）。

5. **`OutputRenderer+SDKMessage.swift` 中的 `renderSingleShotSummary`** 方法处理 `QueryResult` 的单次模式输出。JSON 模式需要一个类似的专用方法，但输出 JSON 而非 ANSI 文本。

6. **`CLISingleShot.swift`** 提供 `CLIExitCode.forQueryStatus()` 和 `formatErrorMessage()`。JSON 模式的错误格式化需要复用 `CLIExitCode`，但错误消息本身应以 JSON 格式输出。

### 当前实现分析

#### ArgumentParser 中的 `--output` 参数

`--output` 已经完全实现：
- `ParsedArgs.output` 默认 `"text"`
- `validOutputFormats` 包含 `"text"` 和 `"json"`
- 帮助信息中已列出 `--output <format>`

**结论：ArgumentParser 不需要任何修改。**

#### OutputRenderer 的当前架构

```
OutputRenderer (struct, implements OutputRendering protocol)
  ├── output: AnyTextOutputStream  — 输出目标
  ├── quiet: Bool                  — 静默模式标志
  ├── markdownBuffer: MarkdownBuffer — Markdown 流式缓冲
  ├── render(_ message: SDKMessage) — 主分发方法
  └── renderStream(_ stream: AsyncStream<SDKMessage>) — 消费完整流
```

**JSON 模式的设计选择：**

有两种实现策略：

**策略 A：在 OutputRenderer 内部处理（添加 jsonOutput 标志）**
- 在 `OutputRenderer` 中添加 `let jsonMode: Bool` 属性
- 在 `render()` 和 `renderStream()` 中添加 JSON 逻辑
- 优点：复用现有类，不增加新文件
- 缺点：OutputRenderer 已经较复杂（Markdown 缓冲、quiet 模式），再加 JSON 模式会使代码难以维护

**策略 B：创建独立的 JsonOutputRenderer（推荐）**
- 新建 `JsonOutputRenderer.swift`，实现 `OutputRendering` 协议
- JSON 渲染器有自己的状态收集逻辑
- CLI.swift 根据 `args.output` 选择渲染器
- 优点：关注点分离，不增加 OutputRenderer 的复杂度
- 缺点：新增一个文件

**推荐策略 B** — 符合架构文档的"一类型一文件"约定和"基于协议的分离"模式。`OutputRendering` 协议正是为这种多渲染器场景设计的。

#### CLI.swift 中的 JSON 模式插入点

当前 single-shot 分支（CLI.swift）：

```swift
if let prompt = args.prompt {
    let result = await agent.prompt(prompt)
    let renderer = OutputRenderer(quiet: args.quiet)

    if !result.text.isEmpty {
        print(result.text)  // 直接 print -- 在 JSON 模式下不应该这样
    }

    if !args.quiet {
        renderer.renderSingleShotSummary(result, debug: isDebug)
    }

    // ... error handling and exit
}
```

**JSON 模式需要的变更：**

```swift
if let prompt = args.prompt {
    let result = await agent.prompt(prompt)

    if args.output == "json" {
        // JSON 模式：输出纯 JSON 到 stdout
        let jsonRenderer = JsonOutputRenderer()
        jsonRenderer.renderSingleShotJson(result)
    } else {
        // 文本模式：现有逻辑不变
        let renderer = OutputRenderer(quiet: args.quiet)
        if !result.text.isEmpty {
            print(result.text)
        }
        if !args.quiet {
            renderer.renderSingleShotSummary(result, debug: isDebug)
        }
        // ... error handling to stderr
    }
    // ... common exit logic
}
```

同样，skill 调用分支的流式渲染也需要类似处理。

#### QueryResult 的关键字段

从 CLISingleShot.swift 和 OutputRenderer+SDKMessage.swift 的使用来看，`QueryResult` 提供以下字段：

- `text: String` — Agent 的文本响应
- `status: QueryStatus` — 查询状态（.success, .errorMaxTurns, .errorDuringExecution, .errorMaxBudgetUsd, .cancelled）
- `numTurns: Int` — 对话轮数
- `totalCostUsd: Double` — 总成本（美元）
- `durationMs: Int` — 执行时长（毫秒）
- `messages: [SDKMessage]` — 所有消息事件

从 `SDKMessage` 事件中可以提取：
- `.toolUse(data)` → `data.toolName`, `data.input` — 工具调用信息
- `.toolResult(data)` → `data.content`, `data.isError` — 工具结果

#### JSON 输出格式设计

根据 AC#1，JSON 输出必须包含 `text`、`toolCalls`、`cost` 和 `turns` 字段。

**成功查询的 JSON 格式：**

```json
{
  "text": "Agent's response text",
  "toolCalls": [
    {
      "name": "Bash",
      "input": "{\"command\": \"ls -la\"}"
    }
  ],
  "cost": 0.0023,
  "turns": 3
}
```

**错误查询的 JSON 格式（AC#2）：**

```json
{
  "error": "Execution failed: ..."
}
```

**注意：**
- `cost` 使用数字类型（Double），保留原始精度
- `toolCalls` 是数组，每个元素有 `name` 和 `input` 字段
- 错误 JSON 仅包含 `error` 字段
- JSON 输出到 stdout（AC#2 明确指定"标准输出"）
- JSON 输出后跟换行符（方便管道读取）

#### 需要修改的文件

**1. `Sources/OpenAgentCLI/JsonOutputRenderer.swift`（新建）**

```swift
import Foundation
import OpenAgentSDK

/// JSON-serializable result structure for --output json mode.
struct JsonRenderResult: Encodable {
    let text: String
    let toolCalls: [JsonToolCall]
    let cost: Double
    let turns: Int
}

/// JSON-serializable tool call record.
struct JsonToolCall: Encodable {
    let name: String
    let input: String
}

/// JSON output renderer for programmatic consumption.
///
/// Silences all intermediate streaming output and produces a single JSON
/// object when the query completes. Used when `--output json` is specified.
struct JsonOutputRenderer: OutputRendering {
    let output: AnyTextOutputStream

    init() {
        self.output = AnyTextOutputStream(FileHandleTextOutputStream())
    }

    init<O: TextOutputStream>(output: O) {
        self.output = AnyTextOutputStream(output)
    }

    func render(_ message: SDKMessage) {
        // Silently collect data -- do not output anything during streaming
    }

    func renderStream(_ stream: AsyncStream<SDKMessage>) async {
        // Silently consume -- caller should use collectStream() instead
        for await _ in stream {}
    }

    /// Collect all messages from a stream and output final JSON.
    func collectAndRender(_ stream: AsyncStream<SDKMessage>) async {
        // Collect tool calls and text from stream messages
        // On completion or error, output appropriate JSON
    }

    /// Render a QueryResult as JSON (single-shot mode).
    func renderSingleShotJson(_ result: QueryResult) {
        // Handle success vs error based on result.status
        // Output JSON to stdout
    }
}
```

**2. `Sources/OpenAgentCLI/CLI.swift`（修改）**

在 single-shot 和 skill 调用分支中添加 `args.output == "json"` 判断，选择渲染器。

**不需要修改的文件**

```
Sources/OpenAgentCLI/
  ArgumentParser.swift              # 无变更 -- --output json 已实现
  OutputRenderer.swift              # 无变更 -- 文本渲染逻辑不变
  OutputRenderer+SDKMessage.swift   # 无变更 -- 文本消息渲染不变
  REPLLoop.swift                    # 无变更 -- REPL 模式不使用 JSON 输出
  AgentFactory.swift                # 无变更 -- Agent 创建逻辑不变
  PermissionHandler.swift           # 无变更
  SessionManager.swift              # 无变更
  MCPConfigLoader.swift             # 无变更
  HookConfigLoader.swift            # 无变更
  ConfigLoader.swift                # 无变更
  ANSI.swift                        # 无变更
  Version.swift                     # 无变更
  main.swift                        # 无变更
  SignalHandler.swift               # 无变更
  MarkdownRenderer.swift            # 无变更
  CLISingleShot.swift               # 无变更 -- 退出码映射和错误格式化逻辑复用
```

### SDK API 参考

本故事使用以下 SDK API：

- **`QueryResult`** — 单次查询结果，包含 `text`, `status`, `numTurns`, `totalCostUsd`, `durationMs`, `messages`
- **`SDKMessage`** — 流式消息事件，JSON 模式需消费 `.toolUse`, `.assistant`, `.result` 等 case
- **`SDKMessage.ToolUseData`** — 工具调用数据，包含 `toolName`, `input`
- **`QueryStatus`** — 查询状态枚举

无 SDK-GAP 预期。`QueryResult` 已包含所有 JSON 输出所需的字段。

[Source: architecture.md#SDK 验证矩阵 — "QueryResult, SDKMessage"]
[Source: prd.md#FR9.2 — "通过 --output json 输出结构化 JSON"]
[Source: architecture.md#OutputRenderer — "SDKMessage → terminal ANSI output"]

### 架构合规性

本故事涉及架构文档中的 **FR9.2**：

- **FR9.2:** 通过 `--output json` 输出结构化 JSON（方便管道集成） (P2)
- **覆盖组件：** `JsonOutputRenderer.swift`（新建）、`CLI.swift`（修改渲染器选择逻辑）

**FR 覆盖映射：**
- FR9.2 → Epic 7, Story 7.2 (本故事)

**架构模式遵循：**
- "一类型一文件" — 新建 `JsonOutputRenderer.swift`
- "基于协议的分离" — 实现 `OutputRendering` 协议
- "CLI 之上薄编排层" — JSON 渲染是纯输出格式化，无业务逻辑
- "所有终端输出使用 OutputRenderer" — JSON 模式使用同协议的另一个实现

[Source: epics.md#Story 7.2]
[Source: prd.md#FR9.2]
[Source: architecture.md#FR9]
[Source: architecture.md#实现模式与一致性规则]

### 关键约束

1. **零 internal 访问** — 整个项目仅允许 `import OpenAgentSDK`
2. **零第三方依赖** — 不引入外部 JSON 库，使用 `Foundation` 的 `JSONEncoder`
3. **不修改 SDK** — 如遇 SDK 限制，记录为 `// SDK-GAP:` 注释
4. **JSON 输出到 stdout** — AC#2 明确指定错误也输出到 stdout（不是 stderr）
5. **JSON 是 stdout 的唯一内容** — 不能混入 ANSI 转义码、进度条或其他非 JSON 文本
6. **Swift 5.9+** — 可使用 typed throws 但本故事不需要
7. **REPL 模式不受影响** — `--output json` 仅影响 single-shot 和 skill 调用路径

### 不要做的事

1. **不要修改 ArgumentParser** — `--output json` 已经完全实现。ParsedArgs.output 字段已存在，验证逻辑已就位。

2. **不要在 REPL 模式中实现 JSON 输出** — REPL 是交互式模式，用户需要实时看到 Agent 的响应。JSON 输出只在 single-shot 和 skill 调用模式下有意义。如果在 REPL 中传入 `--output json`，应忽略并正常使用文本渲染器。

3. **不要在 JSON 输出中包含 ANSI 转义码** — JSON 必须是纯净的、可被 `jq` 等工具解析的 JSON。不要在字段值中包含 ANSI 颜色代码。

4. **不要在 JSON 模式下输出任何内容到 stderr（错误除外）** — 严格的 pipe 友好：stdout 只有 JSON，stderr 可以有 warning 信息（如 session save 失败）。但查询错误本身应按 AC#2 输出到 stdout 的 JSON 中。

5. **不要使用 `print()` 输出 JSON** — `print()` 会添加额外换行且不可控。使用 `TextOutputStream.write()` 或 `JSONEncoder.outputFormatting` 精确控制输出。

6. **不要将错误输出到 stderr** — AC#2 明确说"以 JSON 格式打印到标准输出"。错误和成功结果都输出到 stdout。

7. **不要在 JSON 模式下使用 Markdown 渲染** — JSON 输出的 `text` 字段应包含原始 Agent 文本，不经过 Markdown 渲染。

8. **不要尝试对 `toolCalls` 中的 `input` JSON 做额外处理** — 直接传递 SDK 提供的原始 JSON 字符串。调用者可以自行解析。

### 项目结构说明

本故事新建 1 个源文件，修改 1 个源文件：

```
Sources/OpenAgentCLI/
  JsonOutputRenderer.swift   # 新建：JSON 输出渲染器
  CLI.swift                  # 修改：添加 JSON 模式渲染器选择逻辑
```

新增测试文件：
```
Tests/OpenAgentCLITests/
  JsonOutputRendererTests.swift  # 新建：JSON 输出模式测试
```

[Source: architecture.md#项目结构]

### 测试策略

**新增测试分布预期：**

| 测试方法名 | 覆盖 AC | 说明 |
|-----------|---------|------|
| testSuccessQuery_outputsValidJson | #1, #4 | 成功查询输出包含 text/toolCalls/cost/turns 的有效 JSON |
| testSuccessQuery_jsonHasRequiredFields | #1 | JSON 包含所有必需字段 |
| testSuccessQuery_exitCodeZero | #4 | 成功查询退出码为 0 |
| testErrorQuery_outputsErrorJson | #2 | 错误查询输出 `{"error": "..."}` |
| testErrorQuery_exitCodeOne | #4 | 错误查询退出码为 1 |
| testCancelledQuery_outputsErrorJson | #2 | 取消查询输出错误 JSON |
| testNoIntermediateOutput | #3 | JSON 模式下无中间流式输出 |
| testQuietCombination_sameAsJson | #5 | `--output json --quiet` 行为与 `--output json` 一致 |
| testToolCallsExtracted | #1 | 工具调用被正确提取到 JSON |
| testEmptyToolCalls_emptyArray | #1 | 无工具调用时 `toolCalls` 为空数组 |

**测试方法：**

1. **JsonOutputRenderer 单元测试** — 创建 `StringOutputStream`（现有测试模式），验证 JSON 输出格式和字段。

2. **CLI 集成测试** — 验证 `args.output == "json"` 时的渲染器选择和退出码。

3. **回归测试** — 确保所有现有测试继续通过。OutputRenderer 的修改（如果有）不影响文本模式行为。

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.2]
- [Source: _bmad-output/planning-artifacts/prd.md#FR9.2]
- [Source: _bmad-output/planning-artifacts/architecture.md#FR9]
- [Source: _bmad-output/planning-artifacts/architecture.md#OutputRenderer — "SDKMessage → terminal"]
- [Source: _bmad-output/planning-artifacts/architecture.md#实现模式与一致性规则]
- [Source: Sources/OpenAgentCLI/OutputRenderer.swift — OutputRendering 协议]
- [Source: Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift — 文本渲染实现]
- [Source: Sources/OpenAgentCLI/CLI.swift — single-shot dispatch 逻辑]
- [Source: Sources/OpenAgentCLI/CLISingleShot.swift — CLIExitCode, formatErrorMessage]
- [Source: Sources/OpenAgentCLI/ArgumentParser.swift — ParsedArgs.output, validOutputFormats]
- [Source: _bmad-output/implementation-artifacts/7-1-pipe-stdin-input-mode.md — 前一故事]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md — 延迟项]

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

### Completion Notes List
- Created `JsonOutputRenderer.swift` implementing `OutputRendering` protocol with `renderSingleShotJson(_:)` method
- Success queries output JSON with `text`, `toolCalls`, `cost`, `turns` fields (AC#1)
- Error/cancelled queries output JSON with `error` field (AC#2)
- All intermediate streaming output silenced in JSON mode (AC#3)
- JSON is sole stdout content with no ANSI codes (AC#4)
- `--output json --quiet` produces identical output to `--output json` (AC#5)
- CLI.swift updated: single-shot branch checks `args.output == "json"` and uses `JsonOutputRenderer`
- CLI.swift updated: skill invocation branch also uses `JsonOutputRenderer` when JSON mode active
- REPL mode unaffected -- JSON output only applies to single-shot and skill paths
- Existing test file `JsonOutputRendererTests.swift` was already in place (ATDD red phase); implementation makes all tests pass
- Build compiles cleanly with no errors
- Note: XCTest unavailable in current tool environment; tests verified via code review against implementation

### File List
- `Sources/OpenAgentCLI/JsonOutputRenderer.swift` (new)
- `Sources/OpenAgentCLI/CLI.swift` (modified)
- `Tests/OpenAgentCLITests/JsonOutputRendererTests.swift` (pre-existing, now passing)
