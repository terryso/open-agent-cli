# Story 1.5: 单次提问模式

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## 故事

作为一个用户，
我想要从命令行运行单个查询并获取结果，
以便我可以将 CLI 集成到脚本和快速任务中。

## 验收标准

1. **假设** 传入了提示字符串作为位置参数
   **当** CLI 以 `openagent "what is 2+2?"` 运行
   **那么** Agent 处理提示并输出响应文本

2. **假设** 单次提问响应完成且成功
   **当** `agent.prompt()` 返回 `QueryResult`
   **那么** CLI 显示响应文本
   **并且** 显示汇总行（轮次、成本、耗时）
   **并且** CLI 以退出码 0 退出

3. **假设** 单次提问模式中发生错误
   **当** API 调用失败或 `QueryResult.status` 为错误状态
   **那么** 错误输出到 stderr
   **并且** CLI 以退出码 1 退出

4. **假设** 单次提问模式中 Agent 返回空响应
   **当** `QueryResult.text` 为空字符串
   **那么** CLI 仍以退出码 0 退出（空响应不是错误）

## 任务 / 子任务

- [ ] 任务 1: 重构 CLI.swift 单次模式分支 — 使用 `agent.prompt()` 替换 `agent.stream()` (AC: #1, #2, #3, #4)
  - [ ] 将单次模式从 `agent.stream(prompt)` + `renderer.renderStream()` 改为 `let result = await agent.prompt(prompt)`
  - [ ] 输出 `result.text` 到 stdout
  - [ ] 输出汇总行（复用 OutputRenderer 的格式化逻辑：`--- Turns: N | Cost: $X.XXXX | Duration: Xs`）
  - [ ] 根据 `result.status` 决定退出码：`.success` → 0，其他 → 1
  - [ ] 错误状态时将错误信息输出到 stderr

- [ ] 任务 2: 处理错误和退出码逻辑 (AC: #3)
  - [ ] 检查 `QueryResult.status` 值：`.success`, `.errorMaxTurns`, `.errorDuringExecution`, `.errorMaxBudgetUsd`, `.cancelled`
  - [ ] 非成功状态时：将状态描述输出到 stderr，退出码 1
  - [ ] `result.isCancelled` 为 true 时也视为非成功退出

- [ ] 任务 3: 更新或扩展 OutputRenderer — 添加单次模式汇总行格式化 (AC: #2)
  - [ ] 在 OutputRenderer 或 OutputRenderer+SDKMessage 中添加 `renderSummary(from: QueryResult)` 方法
  - [ ] 复用已有的汇总行格式逻辑（避免 DRY 违规）
  - [ ] 或者：提取汇总行格式化为独立方法，供流式模式和单次模式共用

- [ ] 任务 4: 创建 `CLISingleShotTests.swift` (AC: #1, #2, #3, #4)
  - [ ] 测试成功响应：输出文本 + 汇总行，退出码 0
  - [ ] 测试错误状态（`errorMaxTurns`）：错误到 stderr，退出码 1
  - [ ] 测试空响应：无文本输出但正常退出，退出码 0
  - [ ] 测试取消状态：退出码 1

## 开发备注

### 前一故事的关键学习

Story 1.4（交互式 REPL 循环）已完成，以下是已建立的模式和当前状态：

1. **CLI.swift 单次模式当前实现** — 单次模式当前使用 `agent.stream(prompt)` + `renderer.renderStream()` 进行流式渲染。本故事需将其改为使用 `agent.prompt(prompt)` 阻塞调用。[来源: `Sources/OpenAgentCLI/CLI.swift#L42-46`]

2. **OutputRenderer 已有汇总行格式** — `OutputRenderer+SDKMessage.swift` 中 `renderResult()` 方法已实现汇总行格式化：`--- Turns: N | Cost: $X.XXXX | Duration: Xs`，且处理了成功/错误/取消状态着色。应复用此逻辑，避免 DRY 违规。[来源: `Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift`]

3. **TextOutputStream 抽象已建立** — `AnyTextOutputStream` + `FileHandleTextOutputStream` 用于 stdout 写入。stderr 写入当前使用 `FileHandle.standardError.write()`。[来源: `Sources/OpenAgentCLI/CLI.swift#L29-32`]

4. **全部 146 测试通过** — 本故事的实现不应破坏任何现有测试（97 基础 + 27 渲染器 + 22 REPL）。[来源: Story 1.4 完成备注]

5. **FileHandle.readLine() 不可用** — Swift 6.2 / macOS 15 上需使用 `Swift.readLine()` 内置函数。[来源: Story 1.4 调试日志]

6. **Mock 对象使用 @unchecked Sendable** — MockInputReader 因 Swift 6 严格并发检查需要 `@unchecked Sendable` 注解。[来源: Story 1.4 调试日志]

### 架构合规性

本故事涉及架构文档中的 **FR2.2 单次提问模式**：
- CLI 通过位置参数接收提示字符串（已在 Story 1.1 的 ArgumentParser 中实现）
- 使用 `agent.prompt()` 阻塞 API 获取结果
- 使用 `QueryResult` 类型获取响应和状态

[来源: architecture.md#FR2: 交互模式 → CLI.swift, architecture.md#SDK → CLI 通信模式]

### 关键约束：零 internal 访问

整个项目仅允许 `import OpenAgentSDK`。不得导入任何 internal 模块或使用 `@_implementationOnly`。如果发现 SDK 缺少 public API，使用 `// SDK-GAP:` 注释记录，不绕过。

[来源: prd.md#技术约束, architecture.md#执行指南]

### SDK API 参考 — agent.prompt() 与 QueryResult

**核心阻塞 API：**
```swift
import OpenAgentSDK

// Agent 的阻塞 API — 返回 QueryResult
let result: QueryResult = await agent.prompt("Hello")
// result.text        — 响应文本 (String)
// result.usage       — Token 使用统计 (TokenUsage)
// result.numTurns    — 轮次 (Int)
// result.durationMs  — 耗时毫秒 (Int)
// result.status      — 状态 (QueryStatus)
// result.totalCostUsd — 总成本 (Double)
// result.costBreakdown — 按模型成本明细 ([CostBreakdownEntry])
// result.messages    — 消息集合 ([SDKMessage])
// result.isCancelled — 是否取消 (Bool)
```

**QueryStatus 枚举值：**
```swift
public enum QueryStatus: String, Sendable, Equatable {
    case success                    // 正常完成
    case errorMaxTurns              // 超过最大轮次
    case errorDuringExecution       // 执行中出错（API 错误、网络故障等）
    case errorMaxBudgetUsd          // 超过最大预算
    case cancelled                  // 用户取消
}
```

**重要差异：prompt() vs stream()**

- `agent.stream(_:)` 返回 `AsyncStream<SDKMessage>` — 流式传输，实时渲染每个消息事件
- `agent.prompt(_:)` 返回 `QueryResult` — 阻塞调用，等待完整响应后返回
- `prompt()` **不抛出异常** — 签名为 `async -> QueryResult`（非 `async throws`），错误通过 `QueryResult.status` 传达
- 单次提问模式应使用 `prompt()` 而非 `stream()` — 更简洁，语义更清晰，适合脚本集成

[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L814]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#L689-760]

### CLI.swift 修改点

当前 CLI.swift 单次模式分支（第 42-46 行）：
```swift
if let prompt = args.prompt {
    // Single-shot mode: stream the prompt through OutputRenderer.
    let renderer = OutputRenderer()
    let stream = agent.stream(prompt)
    await renderer.renderStream(stream)
}
```

需替换为使用 `agent.prompt()` 的阻塞调用：
```swift
if let prompt = args.prompt {
    let result = await agent.prompt(prompt)
    // 输出响应文本到 stdout
    // 输出汇总行（复用 OutputRenderer 格式）
    // 根据 result.status 决定退出码
}
```

[来源: Sources/OpenAgentCLI/CLI.swift#L42-46]

### OutputRenderer 汇总行复用策略

当前汇总行格式化逻辑在 `OutputRenderer+SDKMessage.swift` 的 `renderResult()` 方法中，它消费 `SDKMessage.ResultData`（非 `QueryResult`）。两者的字段映射关系：

| QueryResult 字段 | ResultData 字段 | 用途 |
|------------------|----------------|------|
| `numTurns` | `numTurns` | 轮次 |
| `totalCostUsd` | `totalCostUsd` | 成本 |
| `durationMs` | `durationMs` | 耗时 |
| `status` | `subtype` | 状态 |

**推荐方案：** 提取汇总行格式化为独立方法，接受 turns/cost/duration/status 参数。流式模式 `renderResult()` 和单次模式共用此方法。避免在两个地方维护相同格式。

### 不要做的事

1. **不要修改 ArgumentParser** — 位置参数解析已在 Story 1.1 中完整实现，`args.prompt` 已正确设置。单次模式判断基于 `args.prompt != nil`。
2. **不要修改 AgentFactory** — Agent 创建已在 Story 1.2 中完成。
3. **不要修改 REPLLoop** — REPL 循环已在 Story 1.4 中完成，使用 `agent.stream()` 是正确的。
4. **不要在单次模式中使用 `agent.stream()`** — `stream()` 是流式 API，适合 REPL 实时交互。单次模式应使用 `agent.prompt()` 阻塞 API，更适合脚本集成场景。
5. **不要为 `prompt()` 添加 try/catch** — `prompt()` 签名不抛异常（`async -> QueryResult`），错误通过 `result.status` 表达。
6. **不要在单次模式中等待 agent.close()** — 单次模式是一次性执行，进程退出时资源自动释放。`agent.close()` 主要用于 REPL 模式的优雅退出和会话保存。

### 项目结构说明

需要修改的文件：
```
Sources/OpenAgentCLI/
  CLI.swift                           # 修改：单次模式从 stream() 改为 prompt()
  OutputRenderer.swift 或
  OutputRenderer+SDKMessage.swift     # 修改：提取/添加汇总行格式化方法

Tests/OpenAgentCLITests/
  CLISingleShotTests.swift            # 创建：单次模式测试
```

[来源: architecture.md#项目结构]

### 测试策略

**测试挑战：** `agent.prompt()` 需要 LLM API 调用，无法在纯单元测试中执行。

**推荐方案：** 测试汇总行格式化逻辑和退出码判断逻辑（这些可以独立测试），CLI 整体行为通过集成/冒烟测试验证。

1. **汇总行格式化测试** — 如果提取了独立方法，直接测试该方法
2. **退出码判断测试** — 测试 QueryStatus → 退出码映射逻辑
3. **输出内容测试** — 使用 MockTextOutputStream 捕获输出，验证格式

**具体测试用例：**
- 成功状态 → 退出码 0，输出包含文本和汇总行
- `errorMaxTurns` → 退出码 1，stderr 包含错误描述
- `errorDuringExecution` → 退出码 1
- `cancelled` → 退出码 1
- 空文本 + 成功状态 → 退出码 0

### 性能注意事项

- **单次模式无需流式** — `prompt()` 阻塞等待完整响应，用户在脚本中可接受等待
- **无需进度指示器** — 单次模式是脚本集成场景，不需要实时渲染
- **汇总行开销可忽略** — 格式化字符串操作，< 1ms

[来源: prd.md#NFR1, architecture.md#性能考量]

### 参考资料

- [来源: _bmad-output/planning-artifacts/epics.md#Story 1.5]
- [来源: _bmad-output/planning-artifacts/prd.md#FR2.2]
- [来源: _bmad-output/planning-artifacts/architecture.md#SDK → CLI 通信模式, FR2: 交互模式]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L814 (prompt)]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#L689 (QueryStatus)]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#L729 (QueryResult)]
- [来源: Sources/OpenAgentCLI/CLI.swift#L42-46 (单次模式分支)]
- [来源: Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift (汇总行格式)]
- [来源: _bmad-output/implementation-artifacts/1-4-interactive-repl-loop.md#前一故事学习]

## 开发代理记录

### 使用的代理模型

{{agent_model_name_version}}

### 调试日志引用

### 完成备注列表

### 文件列表
