# Story 2.1: 核心工具加载与显示

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## 故事

作为一个用户，
我想要 Agent 默认拥有文件和 Shell 工具的访问权限，
以便它能执行真实任务，如读取文件和运行命令。

## 验收标准

1. **假设** CLI 以默认设置启动（不带 `--tools` 参数）
   **当** 创建 Agent
   **那么** 加载 Core 层工具（Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, AskUser, ToolSearch）

2. **假设** CLI 使用 `--tools advanced` 启动
   **当** 创建 Agent
   **那么** 同时加载 Core 和 Advanced 层工具

3. **假设** 指定了 `--tools all`
   **当** 创建 Agent
   **那么** Core + Specialist 层工具全部加载
   **注意**：SDK 当前 `.advanced` 层返回空数组。`all` 等价于 `core` + `specialist`。

4. **假设** 指定了 `--tools specialist`
   **当** 创建 Agent
   **那么** 加载 Specialist 层工具（Worktree, Plan, Cron, Todo, LSP, Config, RemoteTrigger, MCP Resources）

5. **假设** 工具已加载
   **当** 我在 REPL 中输入 `/tools`
   **那么** 显示已加载的工具名称列表

6. **假设** 提供了 `--tool-allow "Bash,Read"` 和 `--tools core`
   **当** 创建 Agent
   **那么** 仅加载 Bash 和 Read 工具（allowedTools 过滤生效）

7. **假设** 提供了 `--tool-deny "Write"` 和 `--tools core`
   **当** 创建 Agent
   **那么** 加载 Core 工具但排除 Write（disallowedTools 过滤生效）

## 任务 / 子任务

- [x] 任务 1: 在 AgentFactory 中实现工具加载逻辑 (AC: #1, #2, #3, #4)
  - [x] 添加 `mapToolTier(_:) -> [ToolProtocol]` 静态方法，将 `ParsedArgs.tools` 字符串映射到对应的工具数组
  - [x] 实现 tier 解析逻辑：
    - `"core"` → `getAllBaseTools(tier: .core)` （10 个工具）
    - `"advanced"` → `getAllBaseTools(tier: .core) + getAllBaseTools(tier: .advanced)` （Core + 空的 Advanced）
    - `"specialist"` → `getAllBaseTools(tier: .specialist)` （13 个专业工具）
    - `"all"` → `getAllBaseTools(tier: .core) + getAllBaseTools(tier: .specialist)` （全部）
  - [x] 在 `createAgent(from:)` 方法中调用工具加载逻辑，将结果传给 `AgentOptions.tools`
  - [x] 使用 `assembleToolPool()` 进行去重和过滤

- [x] 任务 2: 在 AgentFactory 中集成工具过滤 (AC: #6, #7)
  - [x] 在 `createAgent(from:)` 中使用 `assembleToolPool(baseTools:customTools:mcpTools:allowed:disallowed:)` 替代直接设置 `AgentOptions.tools`
  - [x] 确保 `ParsedArgs.toolAllow` 映射为 `allowed` 参数
  - [x] 确保 `ParsedArgs.toolDeny` 映射为 `disallowed` 参数
  - [x] 验证 `allowedTools` 和 `disallowedTools` 也传递给 `AgentOptions`（SDK 侧双重过滤）

- [x] 任务 3: 在 REPLLoop 中实现 `/tools` 命令 (AC: #5)
  - [x] 在 `handleSlashCommand(_:)` 的 switch 中添加 `/tools` case
  - [x] `/tools` 命令需要访问当前已加载的工具列表
  - [x] 方案：REPLLoop 需要持有工具名列表（在构造时从 AgentFactory 获取并传入）
  - [x] 格式：每行一个工具名称，按字母排序

- [x] 任务 4: 更新 CLI.swift 将工具名列表传递给 REPLLoop (AC: #5)
  - [x] 在 Agent 创建后提取工具名列表
  - [x] 修改 REPLLoop 构造函数接收 `toolNames: [String]` 参数
  - [x] 单次提问模式不需要工具列表显示

- [x] 任务 5: 编写 AgentFactory 工具加载单元测试 (AC: #1, #2, #3, #4, #6, #7)
  - [x] 测试 `mapToolTier("core")` 返回 10 个工具
  - [x] 测试 `mapToolTier("advanced")` 返回 Core 工具
  - [x] 测试 `mapToolTier("specialist")` 返回 Specialist 工具
  - [x] 测试 `mapToolTier("all")` 返回 Core + Specialist 工具
  - [x] 测试 `createAgent` 传递 `tools` 参数给 `AgentOptions`
  - [x] 测试 `--tool-allow` 过滤后仅包含指定工具
  - [x] 测试 `--tool-deny` 过滤后排除指定工具
  - [x] 测试 `--tool-allow` 与 `--tool-deny` 同时指定时 deny 优先

- [x] 任务 6: 编写 REPLLoop `/tools` 命令测试 (AC: #5)
  - [x] 测试 `/tools` 命令输出包含所有已加载工具名
  - [x] 测试无工具时 `/tools` 输出为空列表消息
  - [x] 测试 `/tools` 输出按字母排序

- [x] 任务 7: 回归测试验证 (AC: 全部)
  - [x] 确保 192 项现有测试全部通过
  - [x] 确保不破坏 Story 1.1-1.6 的任何功能

## 开发备注

### 前一故事的关键学习

Story 1.6（冒烟测试）已完成 Epic 1 的全部工作。以下是已建立的模式和当前状态：

1. **192 项测试全部通过** — 分布于 ArgumentParserTests、AgentFactoryTests、ConfigLoaderTests、OutputRendererTests（含消息渲染测试）、REPLLoopTests、CLISingleShotTests、SmokePerformanceTests。[来源: 最新 `swift test` 执行结果]

2. **MockTextOutputStream 模式** — OutputRendererTests 中的 `MockTextOutputStream`，使用 `@unchecked Sendable` + `NSLock`。测试 OutputRenderer 时复用此模式。[来源: `Tests/OpenAgentCLITests/OutputRendererTests.swift`]

3. **AgentFactory 的转换方法暴露为 static** — `mapLogLevel(_:)`、`mapProvider(_:)` 等方法为 `static`，可直接在测试中调用。[来源: `Sources/OpenAgentCLI/AgentFactory.swift`]

4. **Story 1.2 已预留 tools 字段** — `ParsedArgs.tools` 默认值为 `"core"`，`AgentFactory.createAgent(from:)` 当前**不使用**此字段。`AgentOptions.tools` 被设为 `nil`（SDK 默认）。本故事的核心工作就是在 AgentFactory 中将 `ParsedArgs.tools` 转换为工具数组并传给 `AgentOptions.tools`。[来源: `Sources/OpenAgentCLI/AgentFactory.swift#L62-76`, Story 1.2 开发备注]

5. **`allowedTools` / `disallowedTools` 已传递给 AgentOptions** — Story 1.2 的 AgentFactory 已将 `ParsedArgs.toolAllow` 和 `ParsedArgs.toolDeny` 直接传递给 `AgentOptions.allowedTools` 和 `AgentOptions.disallowedTools`。但 SDK 的 `assembleToolPool` 也有自己的过滤逻辑。本故事需要确保两层过滤一致。[来源: `Sources/OpenAgentCLI/AgentFactory.swift#L74-75`]

6. **REPLLoop 的 slash 命令模式** — `handleSlashCommand` 使用简单的 switch 语句。当前支持 `/help`、`/exit`、`/quit`。添加 `/tools` 只需新增一个 case。[来源: `Sources/OpenAgentCLI/REPLLoop.swift#L73-87`]

7. **REPLLoop 不持有 Agent 引用** — REPLLoop 通过构造函数接收 `Agent` 实例。要实现 `/tools` 命令，需要在构造时额外传入工具名列表（因为 Agent 没有暴露已注册工具名的 public API）。[来源: `Sources/OpenAgentCLI/REPLLoop.swift#L38-42`]

8. **FileHandle.readLine() 不可用** — 使用 `Swift.readLine()` 内置函数。Mock 输入需要 `@unchecked Sendable`。[来源: Story 1.4 调试日志]

### 架构合规性

本故事涉及架构文档中的 **FR3 工具系统**：

- **FR3.1:** 默认加载所有 Core 层工具 → `AgentFactory.swift` + `getAllBaseTools(.core)`
- **FR3.2:** 通过 `--tools advanced` 加载 Advanced 层工具 → `AgentFactory.swift`
- **FR3.5:** 工具调用过程实时显示 → 这是 Story 2.2 的范围，但 `/tools` 命令是本故事

[来源: prd.md#FR3, architecture.md#需求到结构的映射]

### SDK API 详细参考

本故事使用以下 SDK public API：

```swift
// 工具层级枚举（CaseIterable, String 原始值）
public enum ToolTier: String, Sendable, CaseIterable {
    case core        // 10 个工具: Read, Write, Edit, Glob, Grep, Bash, AskUser, ToolSearch, WebFetch, WebSearch
    case advanced    // 当前返回空数组 []
    case specialist  // 14 个工具: Worktree, Plan, Cron, Todo, LSP, Config, RemoteTrigger, MCP Resources
}

// 获取指定层级的所有基础工具
public func getAllBaseTools(tier: ToolTier) -> [ToolProtocol]

// 组装完整工具池（去重 + 过滤）
public func assembleToolPool(
    baseTools: [ToolProtocol],
    customTools: [ToolProtocol]?,   // nil = 无自定义工具
    mcpTools: [ToolProtocol]?,      // nil = 无 MCP 工具
    allowed: [String]?,             // nil = 无限制
    disallowed: [String]?           // nil = 无排除
) -> [ToolProtocol]

// 过滤工具列表
public func filterTools(
    tools: [ToolProtocol],
    allowed: [String]?,
    disallowed: [String]?
) -> [ToolProtocol]

// ToolProtocol 的关键属性
public protocol ToolProtocol {
    var name: String { get }
    var description: String { get }
    // ...
}

// AgentOptions.tools 字段
public var tools: [ToolProtocol]?  // nil = SDK 默认（无工具），非 nil = 指定工具列表
```

[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/ToolRegistry.swift]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#AgentOptions.tools]

### 重要注意事项：Advanced 层当前为空

SDK 的 `getAllBaseTools(tier: .advanced)` 当前返回**空数组**。这意味着：
- `--tools advanced` 实际只加载 Core 工具（因为 Advanced 为空）
- `--tools all` 实际等于 Core + Specialist
- 不要对此产生困惑或在测试中做错误断言
- 未来 SDK 实现 Advanced 层后，CLI 无需修改即可工作

[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/ToolRegistry.swift#L79-81]

### 实现策略

**工具加载流程：**

```
ParsedArgs.tools (String: "core"/"advanced"/"specialist"/"all")
  ↓ mapToolTier()
[ToolProtocol] (基础工具数组)
  ↓ assembleToolPool(baseTools:customTools:mcpTools:allowed:disallowed:)
[ToolProtocol] (最终工具池)
  ↓
AgentOptions.tools
```

**`mapToolTier` 实现逻辑：**

```swift
static func mapToolTier(_ tier: String) -> [ToolProtocol] {
    switch tier {
    case "core":
        return getAllBaseTools(tier: .core)
    case "advanced":
        return getAllBaseTools(tier: .core) + getAllBaseTools(tier: .advanced)
    case "specialist":
        return getAllBaseTools(tier: .specialist)
    case "all":
        return getAllBaseTools(tier: .core) + getAllBaseTools(tier: .specialist)
    default:
        return getAllBaseTools(tier: .core)  // 安全回退
    }
}
```

**AgentFactory.createAgent 修改点：**

在现有的 `AgentOptions` 构造之前添加：

```swift
// 加载工具
let baseTools = mapToolTier(args.tools)
let toolPool = assembleToolPool(
    baseTools: baseTools,
    customTools: nil,    // 自定义工具在后续 Story 实现
    mcpTools: nil,       // MCP 工具在 Story 4.1 实现
    allowed: args.toolAllow,
    disallowed: args.toolDeny
)
```

然后将 `toolPool` 传给 `AgentOptions` 的 `tools` 参数。

**`/tools` 命令实现：**

REPLLoop 需要持有工具名列表。修改构造函数：

```swift
struct REPLLoop {
    let agent: Agent
    let renderer: OutputRenderer
    let reader: InputReading
    let toolNames: [String]  // 新增

    init(agent: Agent, renderer: OutputRenderer, reader: InputReading, toolNames: [String] = []) {
        self.agent = agent
        self.renderer = renderer
        self.reader = reader
        self.toolNames = toolNames
    }
}
```

在 `handleSlashCommand` 中添加：

```swift
case "/tools":
    if toolNames.isEmpty {
        renderer.output.write("No tools loaded.\n")
    } else {
        let sorted = toolNames.sorted()
        renderer.output.write("Loaded tools (\(sorted.count)):\n")
        for name in sorted {
            renderer.output.write("  \(name)\n")
        }
    }
```

**CLI.swift 修改：**

在创建 REPLLoop 时提取工具名列表：

```swift
// REPL 模式中
let toolPool = ... // 从 AgentFactory 获取
let toolNames = toolPool.map { $0.name }
let repl = REPLLoop(agent: agent, renderer: renderer, reader: reader, toolNames: toolNames)
```

### 关键约束：零 internal 访问

整个项目仅允许 `import OpenAgentSDK`。不得导入任何 internal 模块或使用 `@_implementationOnly`。如果发现 SDK 缺少 public API，使用 `// SDK-GAP:` 注释记录，不绕过。

[来源: prd.md#技术约束, architecture.md#执行指南]

### 不要做的事

1. **不要实现工具调用可见性的增强渲染** — 那是 Story 2.2 的范围。本故事只加载工具，不修改 `OutputRenderer+SDKMessage.swift` 中的 `renderToolUse` / `renderToolResult` 方法。
2. **不要实现技能加载** — 那是 Story 2.3 的范围。`ParsedArgs.skillDir` 和 `ParsedArgs.skillName` 本故事不处理。
3. **不要实现 MCP 工具加载** — 那是 Story 4.1 的范围。`ParsedArgs.mcpConfigPath` 本故事不处理，传 `mcpTools: nil` 给 `assembleToolPool`。
4. **不要修改 ArgumentParser** — `ParsedArgs.tools` 字段已在 Story 1.1 中完整实现，默认值为 `"core"`，有效值为 `["core", "advanced", "specialist", "all"]`。
5. **不要假设 Advanced 层有工具** — 测试中 `--tools advanced` 断言工具列表等于 Core 层（因为 SDK Advanced 层当前为空）。

### 项目结构说明

需要修改的文件：
```
Sources/OpenAgentCLI/
  AgentFactory.swift          # 添加 mapToolTier() 和工具加载逻辑
  REPLLoop.swift              # 添加 toolNames 属性和 /tools 命令
  CLI.swift                   # 传递工具名列表给 REPLLoop
```

需要新增的测试文件：
```
Tests/OpenAgentCLITests/
  ToolLoadingTests.swift      # 工具加载和过滤的单元测试
```

需要修改的测试文件：
```
Tests/OpenAgentCLITests/
  AgentFactoryTests.swift     # 可能需要调整 makeArgs 以适应新测试
  REPLLoopTests.swift         # 添加 /tools 命令测试
```

不修改的文件：
```
Sources/OpenAgentCLI/
  ArgumentParser.swift        # ParsedArgs 已完整
  OutputRenderer.swift        # 渲染器不涉及工具加载
  OutputRenderer+SDKMessage.swift  # 工具渲染增强是 Story 2.2
  ANSI.swift                  # 无需修改
  Version.swift               # 无需修改
  CLISingleShot.swift         # 单次模式不需要工具列表
  ConfigLoader.swift          # 配置加载不涉及
```

[来源: architecture.md#项目结构]

### 测试策略

**新增测试分布预期：**

| 测试文件 | 新增测试数 | 覆盖 AC |
|----------|-----------|---------|
| ToolLoadingTests.swift | ~12 | #1-#4, #6-#7 |
| REPLLoopTests.swift (追加) | ~3 | #5 |
| 合计 | ~15 | |

**测试方法：**

1. **mapToolTier 单元测试** — 直接调用 `AgentFactory.mapToolTier("core")` 等，验证返回的工具数组长度和工具名称。
2. **createAgent 集成测试** — 构造不同 `tools` 值的 `ParsedArgs`，验证 Agent 创建成功。
3. **过滤测试** — 构造带 `toolAllow`/`toolDeny` 的 `ParsedArgs`，验证工具池被正确过滤。
4. **REPLLoop 测试** — 使用 `MockInputReader` 和 `MockTextOutputStream`，验证 `/tools` 命令输出。

### 参考资料

- [来源: _bmad-output/planning-artifacts/epics.md#Story 2.1]
- [来源: _bmad-output/planning-artifacts/prd.md#FR3.1, FR3.2]
- [来源: _bmad-output/planning-artifacts/architecture.md#AgentFactory, 需求到结构的映射]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/ToolRegistry.swift#getAllBaseTools, assembleToolPool]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#AgentOptions.tools]
- [来源: _bmad-output/implementation-artifacts/1-6-smoke-test-performance-and-reliability.md#前一故事学习]
- [来源: _bmad-output/implementation-artifacts/1-2-agent-factory-with-core-configuration.md#不要做的事]
- [来源: Sources/OpenAgentCLI/AgentFactory.swift (当前实现)]
- [来源: Sources/OpenAgentCLI/REPLLoop.swift (slash 命令模式)]
- [来源: Sources/OpenAgentCLI/CLI.swift (REPL 构造)]

## 开发代理记录

### 使用的代理模型

GLM-5.1

### 调试日志引用

- 初始编译错误：`AgentOptions` init 参数顺序需要 `tools` 在 `logLevel` 之前。修复了参数传递顺序。
- SDK specialist 层实际返回 13 个工具（EnterWorktree, ExitWorktree, EnterPlanMode, ExitPlanMode, CronCreate, CronDelete, CronList, TodoWrite, LSP, Config, RemoteTrigger, ListMcpResources, ReadMcpResource），故事规格中的 "14 个" 为近似值。

### 完成备注列表

- 实现了 `mapToolTier(_:)` 静态方法，支持 "core"/"advanced"/"specialist"/"all"/default 五种映射
- 在 `createAgent(from:)` 中集成了工具加载和 `assembleToolPool` 过滤逻辑
- `REPLLoop` 新增 `toolNames` 属性和 `/tools` 命令，支持字母排序显示
- `CLI.swift` 在 REPL 模式中提取工具名列表传递给 REPLLoop
- 所有 15 个新增测试通过（12 ToolLoadingTests + 3 REPLLoopTests）
- 全部 207 项测试通过（192 既有 + 15 新增），0 回归

### 文件列表

- `Sources/OpenAgentCLI/AgentFactory.swift` — 新增 `mapToolTier(_:)` 方法，`createAgent(from:)` 集成工具加载和过滤
- `Sources/OpenAgentCLI/REPLLoop.swift` — 新增 `toolNames` 属性、`init` 构造函数、`/tools` 命令和 `printTools()` 方法
- `Sources/OpenAgentCLI/CLI.swift` — REPL 模式中提取工具名列表并传递给 REPLLoop
- `Tests/OpenAgentCLITests/ToolLoadingTests.swift` — 12 个工具加载单元测试（ATDD RED 阶段创建）
- `Tests/OpenAgentCLITests/REPLLoopTests.swift` — 新增 3 个 `/tools` 命令测试（ATDD RED 阶段追加）

### 变更日志

- 2026-04-20: 实现工具加载与显示功能 — 新增 mapToolTier、集成 assembleToolPool、REPLLoop /tools 命令 (GLM-5.1)
