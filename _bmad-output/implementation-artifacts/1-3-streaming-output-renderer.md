# Story 1.3: 流式输出渲染器

状态: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## 故事

作为一个用户，
我想要看到 Agent 的响应在生成时实时出现，
以便我不必盯着空白屏幕等待完整响应。

## 验收标准

1. **假设** Agent 正在流式传输响应
   **当** `SDKMessage.partialMessage(data)` 消息到达（逐块文本）
   **那么** 文本逐块输出到标准输出，无缓冲

2. **假设** Agent 响应完成（完整助手消息）
   **当** `SDKMessage.assistant(data)` 到达
   **那么** 如果该消息包含错误（`data.error != nil`），以红色显示错误类型和可操作指导
   **并且** 正常的 assistant 消息已被 partialMessage 流式输出，此处无需重复打印

3. **假设** Agent 查询结束
   **当** `SDKMessage.result(data)` 到达
   **那么** 显示汇总行，格式为 `--- Turns: N | Cost: $X.XXXX | Duration: Xs`
   **并且** 如果 `data.subtype` 为错误类型（`errorMaxTurns`, `errorDuringExecution`, `errorMaxBudgetUsd`），以红色高亮显示错误状态
   **并且** 如果 `data.subtype` 为 `cancelled`，以灰色显示 "cancelled" 状态

4. **假设** 系统消息到达（如自动压缩、初始化等）
   **当** 收到 `SDKMessage.system(data)`
   **那么** 以灰色/暗色文本显示，带有 `[system]` 前缀
   **并且** 精简显示：不打印完整 JSON，仅显示 `data.message` 文本

5. **假设** 流式传输过程中发生错误
   **当** `SDKMessage.result(data)` 包含错误子类型（如 `errorDuringExecution`）
   **那么** 错误以红色显示 `data.errors` 中的每条错误信息
   **并且** 附有可操作的指导

6. **假设** Agent 正在流式输出
   **当** 调用者使用 `OutputRenderer` 的流式消费方法
   **那么** 所有 `SDKMessage` case 均被处理，包括 `@unknown default` 前向兼容处理

## 任务 / 子任务

- [x] 任务 1: 创建 `OutputRenderer.swift` — 核心渲染器协议和实现 (AC: #1, #2, #3, #4, #5, #6)
  - [x] 定义 `OutputRenderer` 结构体，遵循 `OutputRendering` 协议
  - [x] 实现 `render(_ message: SDKMessage)` 主分发方法
  - [x] 实现 `renderStream(_ stream: AsyncStream<SDKMessage>)` 便利方法，消费整个流
  - [x] 所有输出通过 `TextOutputStream` 协议抽象（默认 stdout），便于测试

- [x] 任务 2: 创建 `OutputRenderer+SDKMessage.swift` — 每个 SDKMessage case 的渲染逻辑 (AC: #1, #2, #3, #4, #5, #6)
  - [x] `renderPartialMessage(_ data: PartialData)` — 逐块输出文本到 stdout，无换行
  - [x] `renderAssistant(_ data: AssistantData)` — 处理错误场景（`data.error != nil`）
  - [x] `renderResult(_ data: ResultData)` — 汇总行：turns、cost、duration；错误/取消状态着色
  - [x] `renderSystem(_ data: SystemData)` — 灰色 `[system] message` 前缀格式
  - [x] `renderToolUse(_ data: ToolUseData)` — 青色工具调用行（Story 2.2 会增强，本故事仅基础实现）
  - [x] `renderToolResult(_ data: ToolResultData)` — 结果文本，错误时红色（Story 2.2 会增强）
  - [x] 对其余 case（`userMessage`, `toolProgress`, `hookStarted` 等）提供 `default` 静默处理或基础渲染
  - [x] 使用 `@unknown default` 保证前向兼容

- [x] 任务 3: 扩展 `ANSI.swift` — 添加缺失的颜色辅助方法 (AC: #1, #2, #3, #4, #5)
  - [x] 添加 `green(_:)` 绿色前景色
  - [x] 添加 `yellow(_:)` 黄色前景色
  - [x] 添加 `gray(_:)` 或确认 `dim(_:)` 已满足灰色需求

- [x] 任务 4: 更新 `CLI.swift` — 单次模式集成 OutputRenderer (AC: #1, #3)
  - [x] 单次模式：替换 `print("Agent created. Prompt: ...")` 为 `agent.stream(prompt)` + `OutputRenderer.renderStream()`
  - [x] REPL 模式：保持占位信息不变（REPL 循环是 Story 1.4 的范围），但确保 OutputRenderer 已实例化

- [x] 任务 5: 创建 `OutputRendererTests.swift` (AC: #1, #2, #3, #4, #5, #6)
  - [x] 测试 partialMessage 逐块文本输出无换行
  - [x] 测试 assistant 错误场景（`data.error != nil`）以红色显示
  - [x] 测试 result 正常完成显示 turns/cost/duration 汇总行
  - [x] 测试 result 错误子类型（`errorMaxTurns`, `errorDuringExecution`）以红色显示
  - [x] 测试 result 取消子类型（`cancelled`）以灰色显示
  - [x] 测试 system 消息以灰色 `[system]` 前缀显示
  - [x] 测试未知/未来的 SDKMessage case 不崩溃（`@unknown default`）
  - [x] 使用 `MockTextOutputStream` 捕获输出，避免测试中写入真实 stdout

## 开发备注

### 前一故事的关键学习

Story 1.2 已完成，以下是已建立的模式和约定：

1. **AgentFactory 已就绪** — `AgentFactory.createAgent(from:)` 返回配置完成的 `Agent` 实例。CLI.swift 的 REPL 和单次模式分支已有 Agent 对象，当前输出占位信息，需替换为真实流式渲染。[来源: `Sources/OpenAgentCLI/CLI.swift#L42-49`]

2. **CLI.swift 当前状态** — 单次模式：`print("Agent created. Prompt: \(prompt)")`；REPL 模式：`print("Agent created. REPL mode ready.")`。两者均需在本故事中替换为 OutputRenderer 调用。[来源: `Sources/OpenAgentCLI/CLI.swift#L42-49`]

3. **一类型一文件 + 扩展文件** — `OutputRenderer.swift` 包含核心结构体，`OutputRenderer+SDKMessage.swift` 包含按 case 的渲染扩展。这与架构文档的文件结构一致。[来源: architecture.md#项目结构]

4. **ANSI.swift 已有** — 包含 `bold`, `dim`, `red`, `cyan`, `reset`, `clear` 方法。需评估是否需要添加 `green`, `yellow` 等。[来源: `Sources/OpenAgentCLI/ANSI.swift`]

5. **ConfigLoader 和测试已就绪** — 97 个测试全部通过。本故事的实现不应破坏任何现有测试。[来源: Story 1.2 完成备注]

6. **Code Review 补丁已应用** — Story 1.2 review 中修复了空 API Key、DRY 违规、ConfigLoader sentinel-value 等问题。[来源: Story 1.2 Review Findings]

### 架构合规性

本故事实现架构文档实现顺序中的**第三个组件**：
1. ~~`Version.swift` + `ANSI.swift`（常量）~~ — Story 1.1 完成
2. ~~`ArgumentParser.swift`（CLI 参数 -> ParsedArgs）~~ — Story 1.1 完成
3. **`OutputRenderer.swift`（SDKMessage -> 终端）** — 本故事
4. ~~`AgentFactory.swift`（从解析参数组装 Agent）~~ — Story 1.2 完成（注：架构顺序中 AgentFactory 在 OutputRenderer 之前，但实际开发中 AgentFactory 先实现）

[来源: architecture.md#实现顺序]

### 关键约束：零 internal 访问

整个项目仅允许 `import OpenAgentSDK`。不得导入任何 internal 模块或使用 `@_implementationOnly`。如果发现 SDK 缺少 public API，使用 `// SDK-GAP:` 注释记录，不绕过。

[来源: prd.md#技术约束, architecture.md#执行指南]

### SDK API 参考 — AsyncStream 与 SDKMessage

**核心流式 API：**
```swift
import OpenAgentSDK

// Agent 的流式 API — 返回 AsyncStream<SDKMessage>
let stream: AsyncStream<SDKMessage> = agent.stream("Hello")
for await message in stream {
    // 处理每个 SDKMessage 事件
}
```

**SDKMessage 完整 case 列表（19 个）：**
```swift
public enum SDKMessage: Sendable {
    case assistant(AssistantData)        // 完整助手响应
    case partialMessage(PartialData)     // 流式文本块 — 这是主要渲染目标
    case toolUse(ToolUseData)            // 工具调用请求
    case toolResult(ToolResultData)      // 工具执行结果
    case result(ResultData)              // 查询最终结果（含 turns/cost/duration）
    case system(SystemData)              // 系统事件（init/compactBoundary/status 等）
    case userMessage(UserMessageData)    // 用户消息回显
    case toolProgress(ToolProgressData)  // 工具执行进度
    case hookStarted(HookStartedData)    // Hook 开始执行
    case hookProgress(HookProgressData)  // Hook 中间输出
    case hookResponse(HookResponseData)  // Hook 最终结果
    case taskStarted(TaskStartedData)    // 子任务开始
    case taskProgress(TaskProgressData)  // 子任务进度
    case authStatus(AuthStatusData)      // 认证状态
    case filesPersisted(FilesPersistedData) // 文件已持久化
    case localCommandOutput(LocalCommandOutputData) // 本地命令输出
    case promptSuggestion(PromptSuggestionData) // 推荐提示
    case toolUseSummary(ToolUseSummaryData) // 工具使用汇总
}
```

[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/SDKMessage.swift]

**关键数据类型字段：**

| 类型 | 关键字段 | 说明 |
|------|---------|------|
| `PartialData` | `text: String` | 流式文本块，逐块渲染 |
| `AssistantData` | `text`, `model`, `stopReason`, `error: AssistantError?` | 完整响应；error 不为 nil 时表示错误 |
| `ResultData` | `subtype`, `text`, `usage: TokenUsage?`, `numTurns`, `durationMs`, `totalCostUsd`, `costBreakdown`, `errors: [String]?` | 最终结果，包含所有统计信息 |
| `ResultData.Subtype` | `success`, `errorMaxTurns`, `errorDuringExecution`, `errorMaxBudgetUsd`, `cancelled`, `errorMaxStructuredOutputRetries` | 结果状态枚举 |
| `SystemData` | `subtype`, `message`, `sessionId?`, `tools?`, `model?` | 系统事件 |
| `ToolUseData` | `toolName`, `toolUseId`, `input: String` | 工具调用（Story 2.2 增强） |
| `ToolResultData` | `toolUseId`, `content: String`, `isError: Bool` | 工具结果（Story 2.2 增强） |
| `TokenUsage` | `inputTokens`, `outputTokens`, `totalTokens` | 令牌使用统计 |
| `CostBreakdownEntry` | `model`, `inputTokens`, `outputTokens`, `costUsd` | 按模型成本明细 |

[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/SDKMessage.swift]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/TokenUsage.swift]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#CostBreakdownEntry]

**重要：partialMessage vs assistant 的关系**

SDK 在流式传输时，先发送多个 `partialMessage` 块（每个包含一小段文本），最后发送一个完整的 `assistant` 消息。因此：
- **partialMessage** 是主要的实时渲染目标 — 逐块打印到终端
- **assistant** 通常不需要再次打印文本（已通过 partialMessage 输出）
- **assistant** 主要用于检测错误（`data.error != nil`）和获取 model/stopReason 元数据

### OutputRenderer 设计模式

```swift
import Foundation
import OpenAgentSDK

/// Protocol for output rendering, enabling testability.
protocol OutputRendering: Sendable {
    func render(_ message: SDKMessage)
    func renderStream(_ stream: AsyncStream<SDKMessage>) async
}

/// Renders SDK messages to terminal output with ANSI styling.
///
/// Consumes `AsyncStream<SDKMessage>` from the SDK and formats each event
/// for terminal display. All output goes through a `TextOutputStream` abstraction
/// for testability.
struct OutputRenderer: OutputRendering {
    private let output: AnyTextOutputStream

    /// Create with default stdout output.
    init() {
        self.output = AnyTextOutputStream(FileHandleTextOutputStream())
    }

    /// Create with custom output stream (for testing).
    init<O: TextOutputStream>(output: O) {
        self.output = AnyTextOutputStream(output)
    }

    func render(_ message: SDKMessage) {
        switch message {
        case .partialMessage(let data):
            renderPartialMessage(data)
        case .assistant(let data):
            renderAssistant(data)
        case .result(let data):
            renderResult(data)
        case .system(let data):
            renderSystem(data)
        case .toolUse(let data):
            renderToolUse(data)
        case .toolResult(let data):
            renderToolResult(data)
        @unknown default:
            // Forward compatibility: silently ignore future message types
            break
        }
    }

    func renderStream(_ stream: AsyncStream<SDKMessage>) async {
        for await message in stream {
            render(message)
        }
    }
}
```

### 终端输出格式规范

| SDKMessage case | 格式 | 颜色 |
|-----------------|------|------|
| `.partialMessage(data)` | `data.text` 直接打印，`terminator: ""` | 默认色（无样式） |
| `.assistant(data)` (错误) | `ANSI.red("Error: \(data.error)")` | 红色 |
| `.assistant(data)` (正常) | 不打印（已通过 partialMessage 输出） | — |
| `.result(data)` (成功) | `--- Turns: N | Cost: $X.XXXX | Duration: Xs` | 默认色 |
| `.result(data)` (错误) | `--- [errorMaxTurns] Turns: N | Cost: $X.XXXX | Duration: Xs` | 红色（错误部分） |
| `.result(data)` (取消) | `--- [cancelled]` | 灰色（dim） |
| `.system(data)` | `[system] data.message` | 灰色（dim） |
| `.toolUse(data)` | `> toolName(args...)` | 青色（基础版，Story 2.2 增强） |
| `.toolResult(data)` (成功) | 结果文本（截断到合理长度） | 默认色 |
| `.toolResult(data)` (错误) | 结果文本 | 红色 |
| 其他 case | 静默忽略 | — |

[来源: architecture.md#终端输出格式]

### TextOutputStream 抽象（测试策略）

为了使 `OutputRenderer` 可测试（不写入真实 stdout），使用 `TextOutputStream` 协议抽象：

```swift
/// Type-erased TextOutputStream wrapper.
struct AnyTextOutputStream: TextOutputStream {
    private let _write: (String) -> Void
    init<O: TextOutputStream>(_ output: O) {
        var output = output
        _write = { output.write($0) }
    }
    mutating func write(_ string: String) {
        _write(string)
    }
}

/// FileHandle-based TextOutputStream for stdout.
struct FileHandleTextOutputStream: TextOutputStream {
    func write(_ string: String) {
        FileHandle.standardOutput.write(string.data(using: .utf8) ?? Data())
    }
}
```

测试中使用 `MockTextOutputStream`：
```swift
struct MockTextOutputStream: TextOutputStream {
    var output = ""
    mutating func write(_ string: String) {
        output += string
    }
}
```

### 汇总行格式详解

`SDKMessage.result(data)` 的渲染需要处理以下字段：

```
成功：--- Turns: 3 | Cost: $0.0023 | Duration: 4.2s
错误：--- [errorMaxTurns] Turns: 10 | Cost: $0.0089 | Duration: 12.5s
取消：--- [cancelled]
```

- `numTurns` 直接使用
- `totalCostUsd` 格式化为 `$X.XXXX`（4 位小数）
- `durationMs` 转换为秒：`String(format: "%.1f", Double(data.durationMs) / 1000.0)` + "s"
- 错误子类型：`errorMaxTurns`, `errorDuringExecution`, `errorMaxBudgetUsd`, `errorMaxStructuredOutputRetries` — 以红色方括号显示
- 取消子类型：`cancelled` — 以灰色显示

### 不要做的事

1. **不要实现工具调用的详细渲染** — 工具调用的参数摘要、执行耗时、截断策略是 Story 2.2 的范围。本故事只需为 `toolUse` 和 `toolResult` 提供最基础的渲染（工具名 + 简单输出）。
2. **不要实现 REPL 循环** — REPL 交互循环是 Story 1.4 的范围。本故事只创建 OutputRenderer 组件。
3. **不要实现权限提示渲染** — 那是 Story 5.2 的范围。
4. **不要实现 Markdown 渲染** — 那是 Story 6.5 的范围。本故事输出纯文本。
5. **不要修改 ArgumentParser** — ParsedArgs 已在 Story 1.1 中完整实现。
6. **不要修改 AgentFactory** — Agent 创建已在 Story 1.2 中完成。本故事只消费 Agent 的 stream 输出。
7. **不要为 `partialMessage` 后的 `assistant` 重复打印文本** — partialMessage 已经输出了所有文本，assistant 消息仅用于错误检测。

### 项目结构说明

需要创建/修改的文件：
```
Sources/OpenAgentCLI/
  OutputRenderer.swift               # 创建：核心渲染器 + TextOutputStream 抽象
  OutputRenderer+SDKMessage.swift    # 创建：按 case 的渲染扩展
  ANSI.swift                          # 修改：添加 green/yellow（如需要）
  CLI.swift                           # 修改：单次模式集成 OutputRenderer

Tests/OpenAgentCLITests/
  OutputRendererTests.swift          # 创建：渲染器测试（使用 MockTextOutputStream）
```

[来源: architecture.md#项目结构]

### 测试策略

**测试方法：** 使用 `MockTextOutputStream` 捕获渲染输出，验证格式正确性：

1. **partialMessage 测试** — 构造 `PartialData(text: "Hello")`，验证输出包含 "Hello" 且无尾随换行
2. **assistant 错误测试** — 构造 `AssistantData` with `error: .rateLimit`，验证输出包含红色错误信息
3. **result 成功测试** — 构造 `ResultData(subtype: .success, numTurns: 3, durationMs: 4200, totalCostUsd: 0.0023)`，验证汇总行格式
4. **result 错误测试** — 构造 `ResultData(subtype: .errorMaxTurns, ...)`，验证红色错误标记
5. **result 取消测试** — 构造 `ResultData(subtype: .cancelled, ...)`，验证灰色 "cancelled" 标记
6. **system 测试** — 构造 `SystemData(subtype: .init, message: "Session started")`，验证 `[system]` 前缀和灰色样式
7. **前向兼容测试** — 验证处理所有已知 case 时不崩溃，`@unknown default` 静默忽略

**测试数据构造：** 所有 SDK 类型都有 public init，可直接构造测试数据：
```swift
// partialMessage
let partial = SDKMessage.PartialData(text: "Hello, world!")

// assistant with error
let assistant = SDKMessage.AssistantData(
    text: "", model: "glm-5.1", stopReason: "error",
    error: .rateLimit
)

// result success
let result = SDKMessage.ResultData(
    subtype: .success, text: "Done",
    usage: TokenUsage(inputTokens: 100, outputTokens: 50),
    numTurns: 3, durationMs: 4200, totalCostUsd: 0.0023
)
```

### 配置分层回顾

OutputRenderer 不涉及配置分层 — 它是一个纯渲染组件，不读取任何配置。它的行为由调用者（CLI.swift 或 REPLLoop.swift）控制。

[来源: architecture.md#配置分层]

### 可测试性设计

遵循架构文档的基于协议的可测试性原则：
- `OutputRendering` 协议定义渲染接口
- `OutputRenderer` 结构体实现协议
- 通过 `TextOutputStream` 抽象解耦 stdout
- 测试通过 `MockTextOutputStream` 验证输出内容

[来源: architecture.md#结构模式]

### 性能注意事项

- **流式延迟** — NFR1.3 要求 SDK 层 < 50ms per chunk。OutputRenderer 必须在每个 partialMessage 到达时立即输出，不缓冲。
- **stdout 刷新** — 确保每个 partialMessage 后 stdout 被刷新（`fflush(stdout)` 或使用 unbuffered 写入）。
- **内存** — OutputRenderer 不持有状态，不累积消息。每次 render 调用是无状态的。

[来源: prd.md#NFR1.3, architecture.md#性能考量]

### 参考资料

- [来源: _bmad-output/planning-artifacts/epics.md#Story 1.3]
- [来源: _bmad-output/planning-artifacts/prd.md#FR2.5, FR9.4]
- [来源: _bmad-output/planning-artifacts/architecture.md#OutputRenderer, 实现顺序, 终端输出格式]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/SDKMessage.swift#SDKMessage enum]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/SDKMessage.swift#PartialData]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/SDKMessage.swift#AssistantData]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/SDKMessage.swift#ResultData]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/SDKMessage.swift#SystemData]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/SDKMessage.swift#ToolUseData]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/SDKMessage.swift#ToolResultData]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/TokenUsage.swift]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#CostBreakdownEntry]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#stream()]
- [来源: Sources/OpenAgentCLI/ANSI.swift]
- [来源: Sources/OpenAgentCLI/CLI.swift#current-implementation]
- [来源: _bmad-output/implementation-artifacts/1-2-agent-factory-with-core-configuration.md#前一故事学习]

## 开发代理记录

### 使用的代理模型

GLM-5.1

### 调试日志引用

### 完成备注列表

- ✅ 任务 1: 创建 OutputRenderer.swift — 核心渲染器结构体，包含 OutputRendering 协议、AnyTextOutputStream（线程安全的类型擦除包装器）、FileHandleTextOutputStream（stdout 写入器）、以及主 render/renderStream 方法。使用 @unchecked Sendable + NSLock 确保 AnyTextOutputStream 线程安全。
- ✅ 任务 2: 创建 OutputRenderer+SDKMessage.swift — 按 case 的渲染逻辑扩展。partialMessage 直接写文本（无换行）；assistant 仅处理错误（正常消息已通过 partialMessage 输出）；result 格式化汇总行并按 subtype 着色（成功/错误/取消）；system 以灰色 [system] 前缀显示；toolUse 以青色显示工具名；toolResult 成功时截断显示，错误时红色。
- ✅ 任务 3: 扩展 ANSI.swift — 添加 green(_:) 和 yellow(_:) 方法。dim(_:) 已存在并满足灰色需求。
- ✅ 任务 4: 更新 CLI.swift — 单次模式替换占位 print 为 agent.stream(prompt) + OutputRenderer.renderStream()。REPL 模式保持占位不变（Story 1.4 范围）。
- ✅ 任务 5: 创建 OutputRendererTests.swift — 27 个测试覆盖全部 6 个 AC。使用类引用型 MockTextOutputStream 解决 struct copy 问题。全部 124 测试通过（97 已有 + 27 新增），零回归。

### 文件列表

| 操作 | 路径 |
|------|------|
| 新增 | Sources/OpenAgentCLI/OutputRenderer.swift |
| 新增 | Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift |
| 修改 | Sources/OpenAgentCLI/ANSI.swift |
| 修改 | Sources/OpenAgentCLI/CLI.swift |
| 修改 | Tests/OpenAgentCLITests/OutputRendererTests.swift |
| 修改 | _bmad-output/implementation-artifacts/1-3-streaming-output-renderer.md |
| 修改 | _bmad-output/implementation-artifacts/sprint-status.yaml |
