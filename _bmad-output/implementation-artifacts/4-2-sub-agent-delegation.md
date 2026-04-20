# Story 4.2: 子代理委派

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## 故事

作为一个用户，
我想要 Agent 为复杂任务生成子代理，
以便工作可以并行化或委派给专门的 Agent。

## 验收标准

1. **假设** 指定了 `--tools advanced`
   **当** Agent 创建其工具池
   **那么** 包含 Agent 工具（子代理生成器）

2. **假设** Agent 决定生成子代理
   **当** 子代理运行
   **那么** 其输出在终端中可见，带有缩进前缀

3. **假设** 子代理完成
   **当** 返回结果
   **那么** 父代理使用子代理的输出继续

4. **假设** 父代理有权限模式和 API 配置
   **当** 子代理被生成
   **那么** 子代理继承父代理的权限模式和 API 配置

5. **假设** 子代理正在执行
   **当** 产生进度消息
   **那么** 进度在终端中以缩进的 `[sub-agent]` 前缀显示

## 任务 / 子任务

- [x] 任务 1: 在 AgentFactory 中包含 createAgentTool() (AC: #1)
  - [x] 修改 `computeToolPool(from:skillRegistry:)` 方法：当 `args.tools` 为 "advanced" 或 "all" 或 "specialist" 时，将 `createAgentTool()` 加入 customTools 数组
  - [x] 确保 createAgentTool() 与现有的 SkillTool 共存（两者都通过 customTools 数组传入）
  - [x] 验证 `--tools core`（默认）不包含 Agent 工具

- [x] 任务 2: 在 OutputRenderer 中渲染子代理进度消息 (AC: #2, #5)
  - [x] 在 `OutputRenderer.swift` 的 render 方法中处理 `.taskStarted` 消息类型
  - [x] 渲染格式：缩进两格 + `[sub-agent] ` 前缀 + 任务描述，使用黄色 ANSI 样式
  - [x] 在 `OutputRenderer.swift` 的 render 方法中处理 `.taskProgress` 消息类型
  - [x] 渲染格式：缩进两格 + `[sub-agent] ` 前缀 + 任务 ID + 进度信息，使用灰色 ANSI 样式
  - [x] 将 `.taskStarted` 和 `.taskProgress` 从当前的 silent `break` 分支移到有渲染逻辑的分支

- [x] 任务 3: 编写 SubAgent 集成测试 (AC: #1, #3, #4)
  - [x] 测试 `--tools advanced` 时工具池包含 "Agent" 工具
  - [x] 测试 `--tools core` 时工具池不包含 "Agent" 工具
  - [x] 测试 `--tools all` 时工具池包含 "Agent" 工具
  - [x] 测试 `--tools specialist` 时工具池包含 "Agent" 工具
  - [x] 回归测试验证：319 项现有测试全部通过

## 开发备注

### 前一故事的关键学习

Story 4.1（MCP 服务器配置与连接）完成后的项目状态：

1. **319 项测试全部通过** — 包括 ArgumentParserTests、AgentFactoryTests、ConfigLoaderTests、OutputRendererTests、REPLLoopTests、CLISingleShotTests、SmokePerformanceTests、ToolLoadingTests、SkillLoadingTests、SessionSaveTests、SessionListResumeTests、AutoRestoreTests、MCPConfigLoaderTests。[来源: Story 4.1 完成笔记]

2. **AgentFactory.createAgent 返回 (Agent, SessionStore) 元组** — 所有调用方（CLI.swift 和测试）使用此元组。[来源: `Sources/OpenAgentCLI/AgentFactory.swift#L60`]

3. **computeToolPool 已支持 customTools 数组** — 当前通过可选的 `customTools: [ToolProtocol]?` 参数传入自定义工具。SkillTool 已通过此机制注入。`createAgentTool()` 应通过相同路径注入。[来源: `Sources/OpenAgentCLI/AgentFactory.swift#L130-146`]

4. **OutputRenderer 当前对 taskStarted/taskProgress 静默忽略** — 这些消息类型在 `render(_:)` 方法的 silent `break` 分支中。本故事需要将它们移到有渲染逻辑的分支。[来源: `Sources/OpenAgentCLI/OutputRenderer.swift#L85-99`]

5. **deferred-work.md 有 4 项** — 包括 force-unwrap 模式、误导性错误消息、AgentOptions 未完整填充、缺失测试路径。不要在此故事中修复这些问题。[来源: `_bmad-output/implementation-artifacts/deferred-work.md`]

### SDK API 详细参考

本故事使用的核心 SDK API — Agent 工具（子代理生成器）：

```swift
// SDK 导出的工厂函数 (Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift)
/// 创建 Agent 工具用于生成子代理
public func createAgentTool() -> ToolProtocol
```

**AgentTool 工作原理：**
- AgentTool 是一个高级工具，由 LLM 决定何时调用
- 它接收 `prompt`（任务描述）和 `description`（简短摘要）作为必需参数
- 可选参数包括：`subagent_type`（Explore/Plan）、`model`、`name`、`maxTurns`、`run_in_background`、`isolation`、`team_name`、`mode`（权限模式）、`resume`
- 工具使用 `SubAgentSpawner` 协议（由 SDK Core 在运行时注入到 ToolContext）创建子代理
- 子代理继承父代理的 API 配置（apiKey、model、baseURL、provider）
- 子代理的权限模式可通过 `mode` 参数覆盖，默认继承父代理

```swift
// SDK 消息类型 (Sources/OpenAgentSDK/Types/SDKMessage.swift)
/// 子代理任务启动事件
case taskStarted(TaskStartedData)
/// 子代理任务进度事件
case taskProgress(TaskProgressData)

public struct TaskStartedData: Sendable, Equatable {
    public let taskId: String      // 任务唯一标识
    public let taskType: String    // 任务类型（如 "subagent"）
    public let description: String // 任务描述
}

public struct TaskProgressData: Sendable, Equatable {
    public let taskId: String      // 任务 ID
    public let taskType: String    // 任务类型
    public let usage: TokenUsage?  // 当前的 token 使用量
}
```

**关键洞察：** SDK 在子代理生命周期中自动发出 `taskStarted` 和 `taskProgress` 消息。CLI 只需要渲染这些消息——不需要手动跟踪子代理状态或进度。子代理的执行结果通过 `toolResult` 消息返回（AgentTool 作为工具执行完毕后返回结果文本）。

[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/SDKMessage.swift#L46-48, L577-609]

### 核心设计决策

#### 决策 1: createAgentTool 的注入时机

`createAgentTool()` 是一个无参工厂函数。它不需要任何配置——SDK 在运行时通过 `ToolContext.agentSpawner` 注入子代理创建能力。因此：

- **不需要修改 AgentOptions** — 子代理的 API 配置（apiKey、model、provider）由 SDK 自动从父代理继承
- **不需要修改 ArgumentParser** — `--tools advanced` 参数已存在
- **只需要在 computeToolPool 中添加工具实例** — 当工具层级包含 advanced 时

#### 决策 2: 子代理进度消息的渲染格式

| SDKMessage 类型 | 渲染格式 | ANSI 颜色 |
|----------------|---------|----------|
| `.taskStarted` | `  [sub-agent] <description>` | 黄色（表示新活动） |
| `.taskProgress` | `  [sub-agent] <taskId> - <usage info>` | 灰色/暗色（状态更新） |

使用两格缩进将子代理活动与父代理工具调用（使用 `> toolName` 格式）在视觉上区分开。

#### 决策 3: 不修改 toolResult 渲染

子代理的最终结果通过 `.toolResult(data)` 消息返回（其中 `data.toolName` 为 "Agent"）。现有的 `renderToolResult` 已经处理了工具结果的渲染（500 字符截断、错误红色显示）。不需要为子代理结果添加特殊处理——统一使用现有的工具结果渲染路径。

### 架构合规性

本故事涉及架构文档中的 **FR8.1、FR8.2、FR8.3**：

- **FR8.1:** Agent 工具自动可用（Advanced 层加载时） → `AgentFactory.swift`（当 `--tools advanced` 时包含 `createAgentTool()`）
- **FR8.2:** 子代理继承父代理的权限模式和 API 配置 → SDK 内置行为（`SubAgentSpawner` 自动继承父代理配置）
- **FR8.3:** 子代理执行进度实时显示 → `OutputRenderer.swift`（渲染 `.taskStarted` 和 `.taskProgress` 消息）

架构文档中提到的文件映射：
- FR8 → `AgentFactory.swift` — 本故事修改此文件以包含 createAgentTool()
- FR8.3 → `OutputRenderer+SDKMessage.swift` — 本故事在此文件中添加子代理消息渲染

[来源: _bmad-output/planning-artifacts/epics.md#Story 4.2]
[来源: _bmad-output/planning-artifacts/prd.md#FR8.1, FR8.2, FR8.3]
[来源: _bmad-output/planning-artifacts/architecture.md#FR8:子代理→AgentFactory.swift]

### 关键约束：零 internal 访问

整个项目仅允许 `import OpenAgentSDK`。不得导入任何 internal 模块或使用 `@_implementationOnly`。如果发现 SDK 缺少 public API，使用 `// SDK-GAP:` 注释记录，不绕过。

[来源: prd.md#技术约束, architecture.md#执行指南]

### 不要做的事

1. **不要修改 ArgumentParser** — `--tools advanced` 参数已完整实现。[来源: `Sources/OpenAgentCLI/ArgumentParser.swift#L123-129`]

2. **不要修改 AgentOptions** — 子代理的 API 配置和权限继承由 SDK 自动处理。CLI 不需要在 AgentOptions 中设置子代理相关字段。

3. **不要创建 SubAgentSpawner** — SDK 通过 `ToolContext.agentSpawner` 在运行时自动注入。CLI 只需调用 `createAgentTool()` 获取工具实例。

4. **不要为 toolResult 添加子代理特殊处理** — 子代理结果通过常规的 `toolResult` 消息返回，现有的渲染逻辑已足够。

5. **不要实现 SendMessage 工具** — SendMessage 是 P2 功能（FR8.4），属于 Epic 7 Story 7.5。本故事只做 Agent 工具。

6. **不要实现后台子代理或 worktree 隔离** — AgentTool 支持 `run_in_background` 和 `isolation` 参数，但这些是 LLM 端的配置，CLI 不需要为此添加特殊逻辑。SDK 处理所有生命周期管理。

7. **不要修改 CLI.swift** — 子代理工具的添加完全在 AgentFactory 和 OutputRenderer 中完成。CLI 的启动流程不需要变化。

8. **不要修改 REPLLoop** — 子代理消息通过 AsyncStream 正常传递，REPLLoop 已经在消费完整的消息流。

### 项目结构说明

需要修改的文件：
```
Sources/OpenAgentCLI/
  AgentFactory.swift                    # 修改：在 computeToolPool 中包含 createAgentTool()
  OutputRenderer.swift                  # 修改：将 taskStarted/taskProgress 从 silent 分支移出
  OutputRenderer+SDKMessage.swift       # 修改：添加 renderTaskStarted 和 renderTaskProgress 方法
```

需要新增的测试：
```
Tests/OpenAgentCLITests/
  SubAgentTests.swift                   # 新建：覆盖工具池包含/排除 Agent 工具的测试
```

不修改的文件：
```
Sources/OpenAgentCLI/
  ArgumentParser.swift                  # 参数解析不变（--tools 已存在）
  CLI.swift                             # 启动流程不变
  REPLLoop.swift                        # REPL 循环不变
  MCPConfigLoader.swift                 # MCP 配置不变
  CLISingleShot.swift                   # 单次模式不变
  ConfigLoader.swift                    # 配置加载不变
  ANSI.swift                            # ANSI 辅助不变（可能新增黄色辅助方法）
  Version.swift                         # 版本不变
  main.swift                            # 入口不变
```

[来源: architecture.md#项目结构]

### 测试策略

**新增测试分布预期：**

| 测试方法名 | 覆盖 AC | 说明 |
|-----------|---------|------|
| testToolPool_advanced_includesAgentTool | #1 | `--tools advanced` 工具池包含 "Agent" 工具 |
| testToolPool_core_excludesAgentTool | #1 | `--tools core` 工具池不包含 "Agent" 工具 |
| testToolPool_all_includesAgentTool | #1 | `--tools all` 工具池包含 "Agent" 工具 |
| testToolPool_specialist_includesAgentTool | #1 | `--tools specialist` 工具池包含 "Agent" 工具 |
| testToolPool_advancedWithSkill_includesBoth | #1 | advanced + skill 同时包含 Agent 和 Skill 工具 |
| testExistingTestsStillPass_regression | 全部 | 319 项测试无回归 |

**测试方法：**

1. **工具池包含性测试** — 调用 `AgentFactory.computeToolPool(from:)` 传入不同的 `ParsedArgs.tools` 值，断言结果中是否包含名称为 "Agent" 的工具。

2. **回归测试** — 添加 createAgentTool 不应影响任何现有测试。特别注意 `--tools core`（默认值）不应包含 Agent 工具。

**输出渲染测试：** taskStarted/taskProgress 的渲染可以通过 `OutputRendererTests` 中的现有测试模式验证（构造 `SDKMessage` 实例，传入 renderer，断言输出字符串）。但这些测试不是本故事的 AC 要求——AC #2 和 #5 是关于终端可见性的用户级验收标准，可以通过手动测试验证。

### 参考

- [来源: _bmad-output/planning-artifacts/epics.md#Story 4.2]
- [来源: _bmad-output/planning-artifacts/prd.md#FR8.1, FR8.2, FR8.3]
- [来源: _bmad-output/planning-artifacts/architecture.md#FR8:子代理→AgentFactory.swift]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift (createAgentTool 工厂函数)]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/SDKMessage.swift#L46-48 (taskStarted/taskProgress)]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/SDKMessage.swift#L577-609 (TaskStartedData, TaskProgressData)]
- [来源: Sources/OpenAgentCLI/AgentFactory.swift#L130-146 (computeToolPool)]
- [来源: Sources/OpenAgentCLI/OutputRenderer.swift#L85-99 (silent message handling)]
- [来源: Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift (现有渲染方法模式)]
- [来源: _bmad-output/implementation-artifacts/4-1-mcp-server-configuration-and-connection.md (前一故事学习)]
- [来源: _bmad-output/implementation-artifacts/deferred-work.md (4 项延迟工作)]

### 项目结构说明

- 所有修改遵循架构文档中的文件命名约定（PascalCase，一个类型一个文件）
- `createAgentTool()` 是 SDK 提供的无参工厂函数，通过 `getAllBaseTools(tier: .advanced)` 返回的工具列表中的高级工具之一
- 但实际上 `createAgentTool()` 是一个独立的导出函数，需要单独调用并注入到 customTools 中
- 没有与统一项目结构的冲突或偏差

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Task 1: Modified `AgentFactory.computeToolPool` to include `createAgentTool()` in customTools when `args.tools` is "advanced", "all", or "specialist". The Agent tool coexists with SkillTool via the same customTools array. `--tools core` (default) correctly excludes the Agent tool.
- Task 2: Added `renderTaskStarted` and `renderTaskProgress` methods to `OutputRenderer+SDKMessage.swift`. Updated `OutputRenderer.render` dispatch to route `.taskStarted` and `.taskProgress` to their renderers instead of silently ignoring them. Added `ANSI.yellow` helper. Indent spaces are placed outside ANSI codes so `hasPrefix("  ")` works correctly.
- Task 3: All 7 SubAgentTests pass (tool pool inclusion/exclusion for advanced/core/all/specialist). All 9 task rendering tests in OutputRendererTests pass. Full regression: 335 tests pass (319 existing + 16 new), 0 failures.

### File List

- `Sources/OpenAgentCLI/AgentFactory.swift` — Modified: Added createAgentTool() to customTools in computeToolPool for advanced/all/specialist tiers
- `Sources/OpenAgentCLI/OutputRenderer.swift` — Modified: Routed .taskStarted and .taskProgress to renderTaskStarted/renderTaskProgress methods
- `Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift` — Modified: Added renderTaskStarted and renderTaskProgress methods
- `Sources/OpenAgentCLI/ANSI.swift` — Modified: Added yellow() helper method
- `Tests/OpenAgentCLITests/SubAgentTests.swift` — Pre-existing: ATDD tests (all now passing)
- `Tests/OpenAgentCLITests/OutputRendererTests.swift` — Pre-existing: ATDD tests for task rendering (all now passing)

### Review Findings

- [x] [Review][Defer] testToolPool_advancedWithSkill_includesBoth name misleading (only asserts Agent, not "both") [`Tests/OpenAgentCLITests/SubAgentTests.swift:116`] — deferred, pre-existing test quality gap
- [x] [Review][Defer] Weak ANSI color assertions in tests (`|| contains("\u{001B}[")` matches any ANSI code) [`Tests/OpenAgentCLITests/OutputRendererTests.swift:931,981`] — deferred, by-design test simplification
- [x] [Review][Defer] AC#3 and AC#4 have no automated tests (SDK-internal behaviors) — deferred, not testable at CLI level by design

### Change Log

- 2026-04-20: Story 4.2 implementation complete. Added Agent tool loading for advanced/all/specialist tiers and sub-agent progress rendering. 335 tests pass, 0 failures.
- 2026-04-20: Code review passed. 0 decision-needed, 0 patch, 3 deferred, 3 dismissed. Status updated to done.
