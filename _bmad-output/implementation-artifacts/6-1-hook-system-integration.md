# Story 6.1: 钩子系统集成

Status: done

## Story

作为一个用户，
我想要在 Agent 生命周期事件上配置 Shell 钩子，
以便我可以记录日志、审计或转换 Agent 的行为。

## Acceptance Criteria

1. **假设** 存在钩子配置 JSON 文件
   **当** 我运行 `openagent --hooks ./hooks.json`
   **那么** 钩子通过 SDK 的 `createHookRegistry()` 注册

2. **假设** 为 `preToolUse` 事件配置了钩子
   **当** Agent 调用工具
   **那么** 钩子脚本在工具运行之前执行

3. **假设** 钩子脚本超时或出错
   **当** 执行时
   **那么** 记录警告但 Agent 操作继续

## Tasks / Subtasks

- [x] Task 1: 创建 HookConfigLoader (AC: #1)
  - [x] 创建 `HookConfigLoader.swift`，从 JSON 文件加载钩子配置
  - [x] 定义 `HookConfigLoaderError` 错误枚举（fileNotFound, invalidJSON, invalidEventName, missingCommand）
  - [x] 解析 JSON 格式：`{ "hooks": { "preToolUse": [{ "command": "..." }], ... } }`
  - [x] 将每个钩子条目映射为 SDK 的 `HookDefinition`（command, matcher, timeout）
  - [x] 验证事件名称是否为有效的 `HookEvent` rawValue

- [x] Task 2: 集成 HookConfigLoader 到 AgentFactory (AC: #1, #2)
  - [x] 在 `AgentFactory.createAgent(from:)` 中加载钩子配置
  - [x] 使用 `createHookRegistry(config:)` 创建 `HookRegistry`
  - [x] 将 `hookRegistry` 传递到 `AgentOptions`
  - [x] 当 `--hooks` 未指定时，`hookRegistry` 为 nil（无钩子）

- [x] Task 3: 更新 CLI.swift 显示钩子配置状态 (AC: #1)
  - [x] 类似 MCP 配置的启动提示：`[Hooks configured]`

- [x] Task 4: 编写测试 (AC: #1, #2, #3)
  - [x] HookConfigLoaderTests: 文件不存在、无效 JSON、有效配置、部分无效事件名
  - [x] AgentFactoryTests: 钩子配置传递到 AgentOptions
  - [x] 回归测试：全部现有测试通过

## Dev Notes

### 前一故事的关键学习

Story 5.3（优雅的中断处理）完成后的项目状态：

1. **396 项测试全部通过** — 所有现有测试稳定
2. **SignalHandler.swift** 已创建 — `sigaction` 信号处理，跨平台支持
3. **REPLLoop.swift** 已更新 — 流消费循环中集成中断检测
4. **CLI.swift** 中 `SignalHandler.register()` 在配置加载后调用
5. **ArgumentParser.swift 已有 `--hooks` 标志** — `hooksConfigPath` 字段已在 `ParsedArgs` 中定义，帮助信息已列出 `--hooks <path>`
6. **AgentFactory 尚未使用 `hooksConfigPath`** — 需要在本故事中集成

### SDK API 详细参考

本故事使用的核心 SDK API：

```swift
// HookEvent — 22 个生命周期事件
public enum HookEvent: String, Sendable, Equatable, CaseIterable {
    case preToolUse, postToolUse, postToolUseFailure
    case sessionStart, sessionEnd, stop
    case subagentStart, subagentStop
    case userPromptSubmit, permissionRequest, permissionDenied
    case taskCreated, taskCompleted
    case configChange, cwdChanged, fileChanged, notification
    case preCompact, postCompact, teammateIdle
    case setup, worktreeCreate, worktreeRemove
}

// HookDefinition — 钩子定义
public struct HookDefinition: @unchecked Sendable {
    public let command: String?          // Shell 命令
    public let handler: (@Sendable (HookInput) async -> HookOutput?)?  // 闭包处理器
    public let matcher: String?          // 正则匹配工具名
    public let timeout: Int?             // 超时毫秒数（默认 30000）
    public init(command:handler:matcher:timeout:)
}

// createHookRegistry — 工厂函数
public func createHookRegistry(config: [String: [HookDefinition]]? = nil) async -> HookRegistry

// HookRegistry — Actor，线程安全
public actor HookRegistry {
    public func register(_ event: HookEvent, definition: HookDefinition)
    public func registerFromConfig(_ config: [String: [HookDefinition]])
    public func execute(_ event: HookEvent, input: HookInput) async -> [HookOutput]
}

// AgentOptions.hookRegistry — 可选字段
public var hookRegistry: HookRegistry?
```

**关键行为：**
- `createHookRegistry(config:)` 接受 `[String: [HookDefinition]]` 字典，key 是事件名称字符串
- 无效的事件名称被静默跳过（不报错）
- Shell 命令钩子通过 `ShellHookExecutor` 执行，使用 `/bin/bash -c`
- 超时默认 30000ms，超时后钩子被取消，不影响主流程
- 钩子失败不传播 — 错误被记录，Agent 继续
- `matcher` 是正则表达式，用于过滤特定工具名

[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/HookTypes.swift]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Hooks/HookRegistry.swift]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Hooks/ShellHookExecutor.swift]

### 核心设计决策

#### 决策 1: HookConfigLoader 架构

遵循 `MCPConfigLoader` 的设计模式（enum + static 方法 + 错误枚举）：

```swift
/// 加载钩子配置时可能发生的错误。
enum HookConfigLoaderError: LocalizedError {
    case fileNotFound(String)
    case invalidJSON(String)
    case invalidEventName(String)
    case missingCommand(event: String)
    case emptyCommand(event: String)
}

/// 从 JSON 文件加载钩子配置。
///
/// JSON 格式：
/// {
///   "hooks": {
///     "preToolUse": [
///       { "command": "echo 'Before tool'", "matcher": "Bash", "timeout": 5000 }
///     ],
///     "postToolUse": [
///       { "command": "echo 'After tool'" }
///     ]
///   }
/// }
enum HookConfigLoader {
    static func loadHooksConfig(from path: String) throws -> [String: [HookDefinition]]
}
```

**为什么遵循 MCPConfigLoader 模式：**
- 一致的项目约定（enum 无实例，仅静态方法）
- 错误处理模式一致（具体错误类型 + 可操作消息）
- 文件验证 → JSON 解析 → 结构验证 → 返回结果

#### 决策 2: JSON 格式

```json
{
  "hooks": {
    "preToolUse": [
      {
        "command": "/path/to/script.sh",
        "matcher": "Bash",
        "timeout": 5000
      }
    ],
    "postToolUse": [
      {
        "command": "echo 'tool done'"
      }
    ],
    "sessionStart": [
      {
        "command": "logger 'session started'"
      }
    ]
  }
}
```

**设计要点：**
- 顶层使用 `"hooks"` 键（类似 MCP 的 `"mcpServers"` 键）——与未来可能的其他配置共存
- 每个事件名必须匹配 `HookEvent.rawValue`（22 个有效值）
- 每个钩子条目必须包含 `command` 字段（Shell 命令钩子）
- `matcher` 和 `timeout` 为可选字段
- CLI 仅加载 Shell 命令钩子（不加载 handler 闭包，因为闭包无法从 JSON 表示）

#### 决策 3: AgentFactory 集成

在 `AgentFactory.createAgent(from:)` 中添加钩子加载步骤（在 MCP 加载之后）：

```swift
// 6c. Load hooks configuration (if --hooks provided)
let hookRegistry: HookRegistry? = try await args.hooksConfigPath.map {
    let config = try HookConfigLoader.loadHooksConfig(from: $0)
    return await createHookRegistry(config: config)
}
```

**注意：** `createHookRegistry` 是 `async` 函数，而 `createAgent(from:)` 当前不是 async。需要将 `createAgent` 改为 `async throws`。

#### 决策 4: createAgent 方法签名变更

当前签名：
```swift
static func createAgent(from args: ParsedArgs) throws -> (Agent, SessionStore)
```

需要改为：
```swift
static func createAgent(from args: ParsedArgs) async throws -> (Agent, SessionStore)
```

因为 `createHookRegistry(config:)` 是 async 函数。这会影响所有调用点：
- `CLI.createAgentOrExit(from:)` 需要加 `await`
- `AgentFactoryTests` 中测试需要加 `await`

### 架构合规性

本故事涉及架构文档中的 **FR7.1, FR7.2, FR7.3**：

- **FR7.1:** 通过 `--hooks <config.json>` 参数加载钩子配置 (P1) → `HookConfigLoader.swift`, `ArgumentParser.swift`（已有）
- **FR7.2:** 支持所有 21 个生命周期事件的 Shell 钩子 (P1) → SDK `HookEvent` 有 22 个事件
- **FR7.3:** 钩子执行超时和错误不阻塞主流程 (P1) → SDK `HookRegistry` 内置此行为

架构文档中的钩子规范：
- Hook 配置格式：JSON 文件（SDK 的 `HookDefinition` 结构体）
- Hook 配置传递：通过 `createHookRegistry()` 注册

[来源: _bmad-output/planning-artifacts/epics.md#Story 6.1]
[来源: _bmad-output/planning-artifacts/prd.md#FR7.1, FR7.2, FR7.3]
[来源: _bmad-output/planning-artifacts/architecture.md#HookConfigLoader]

### 关键约束：零 internal 访问

整个项目仅允许 `import OpenAgentSDK`。不得导入任何 internal 模块或使用 `@_implementationOnly`。如果发现 SDK 缺少 public API，使用 `// SDK-GAP:` 注释记录，不绕过。

[来源: prd.md#技术约束, architecture.md#执行指南]

### 不要做的事

1. **不要重新实现 Shell 命令执行** — SDK 已有 `ShellHookExecutor`，只需通过 `HookDefinition.command` 传入 shell 命令即可。

2. **不要修改 ArgumentParser** — `--hooks` 标志和 `hooksConfigPath` 字段已存在。无需修改。

3. **不要修改 OutputRenderer** — 钩子执行是 SDK 内部行为，不需要特殊的终端输出。启动时仅显示 `[Hooks configured]` 提示。

4. **不要在 JSON 配置中支持 handler 闭包** — JSON 只能表示 Shell 命令钩子（`command` 字段）。`handler` 闭包无法从 JSON 反序列化。

5. **不要为无效事件名称抛出错误** — SDK 的 `registerFromConfig` 静默跳过无效事件名。HookConfigLoader 应在加载时验证并给出警告，但不阻止其他有效钩子的注册。

6. **不要修改 REPLLoop** — 钩子触发是 SDK 内部行为，通过 `AgentOptions.hookRegistry` 传递后自动生效。REPL 不需要任何改动。

7. **不要创建过度复杂的配置验证** — 参考 MCPConfigLoader 的模式：基本验证（文件存在、JSON 格式、必需字段），不需要验证所有 22 个事件。

### 项目结构说明

需要创建的文件：
```
Sources/OpenAgentCLI/
  HookConfigLoader.swift            # 新建：JSON → [String: [HookDefinition]] 加载器
```

需要修改的文件：
```
Sources/OpenAgentCLI/
  AgentFactory.swift                # 修改：加载钩子配置，传递到 AgentOptions，方法签名加 async
  CLI.swift                         # 修改：await 调用适配，显示钩子配置状态
```

需要创建的测试：
```
Tests/OpenAgentCLITests/
  HookConfigLoaderTests.swift       # 新建：配置加载器测试
  AgentFactoryTests.swift           # 修改：添加钩子集成测试
```

不修改的文件：
```
Sources/OpenAgentCLI/
  ArgumentParser.swift              # --hooks 已存在，无需修改
  REPLLoop.swift                    # 钩子是 SDK 内部行为，无需改动
  OutputRenderer.swift              # 无渲染变更
  OutputRenderer+SDKMessage.swift   # SDKMessage 渲染不变
  MCPConfigLoader.swift             # MCP 配置不变
  PermissionHandler.swift           # 权限逻辑不变
  SignalHandler.swift               # 信号处理不变
  SessionManager.swift              # 会话管理不变
  CLISingleShot.swift               # 单次模式不变
  ConfigLoader.swift                # 配置加载不变
  ANSI.swift                        # ANSI 辅助不变
  Version.swift                     # 版本不变
  main.swift                        # 入口不变
```

[来源: architecture.md#项目结构]

### 测试策略

**新增测试分布预期：**

| 测试方法名 | 覆盖 AC | 说明 |
|-----------|---------|------|
| testLoadHooks_validConfig | #1 | 加载有效 JSON 配置返回正确映射 |
| testLoadHooks_fileNotFound | #1 | 文件不存在抛出 .fileNotFound |
| testLoadHooks_invalidJSON | #1 | 无效 JSON 抛出 .invalidJSON |
| testLoadHooks_missingHooksKey | #1 | 缺少 hooks 键抛出错误 |
| testLoadHooks_emptyHooks | #1 | 空 hooks 返回空字典 |
| testLoadHooks_multipleEvents | #2 | 多个事件类型正确解析 |
| testLoadHooks_withMatcherAndTimeout | #2 | matcher 和 timeout 可选字段正确传递 |
| testLoadHooks_missingCommand | #1 | 钩子缺少 command 字段抛出错误 |
| testLoadHooks_emptyCommand | #1 | 空 command 抛出错误 |
| testAgentFactory_hooksPassedToOptions | #1 | hooks 配置传递到 AgentOptions.hookRegistry |
| testAgentFactory_noHooksWhenNotSpecified | #1 | 无 --hooks 时 hookRegistry 为 nil |
| testExistingTestsPass_regression | 全部 | 396 项测试无回归 |

**测试方法：**

1. **HookConfigLoader 测试** — 创建临时 JSON 文件，验证各种配置场景。参考 MCPConfigLoaderTests 的模式。

2. **AgentFactory 集成测试** — 验证 hooksConfigPath 被正确转换为 HookRegistry 并传递到 AgentOptions。可能需要 mock 或使用 `XCTExpectation` 处理 async。

3. **回归测试** — `createAgent` 方法签名从 `throws` 变为 `async throws` 会影响现有测试。所有调用点需要添加 `await`。

### 参考

- [来源: _bmad-output/planning-artifacts/epics.md#Story 6.1]
- [来源: _bmad-output/planning-artifacts/prd.md#FR7.1, FR7.2, FR7.3]
- [来源: _bmad-output/planning-artifacts/architecture.md#HookConfigLoader]
- [来源: Sources/OpenAgentCLI/MCPConfigLoader.swift — 参考实现模式]
- [来源: Sources/OpenAgentCLI/AgentFactory.swift — 需要添加钩子加载]
- [来源: Sources/OpenAgentCLI/CLI.swift — 需要适配 async]
- [来源: Sources/OpenAgentCLI/ArgumentParser.swift — hooksConfigPath 已存在]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/HookTypes.swift — HookDefinition, HookEvent]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Hooks/HookRegistry.swift — HookRegistry, createHookRegistry]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Hooks/ShellHookExecutor.swift — Shell 命令执行]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift — AgentOptions.hookRegistry]
- [来源: _bmad-output/implementation-artifacts/5-3-graceful-interrupt-handling.md — 前一故事]

### 项目结构说明

- 新建 `HookConfigLoader.swift` 遵循一文件一类型的约定
- `HookConfigLoader` 使用 `enum`（无实例，只有静态方法），与项目中 `MCPConfigLoader`、`ANSI`、`CLI` 等类型保持一致
- `HookConfigLoaderError` 作为独立枚举定义在同一文件中（同 MCPConfigLoaderError 模式）
- 无与统一项目结构的冲突或偏差

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

### Completion Notes List

- Implemented HookConfigLoader.swift following MCPConfigLoader pattern: enum with static methods + error enum
- HookConfigLoaderError includes: fileNotFound, invalidJSON, missingHooksKey, invalidEventName, missingCommand, emptyCommand
- Changed AgentFactory.createAgent(from:) from `throws` to `async throws` to support createHookRegistry async API
- Updated all 11 test files that reference createAgent to use async/await pattern
- Added `[Hooks configured]` startup message in CLI.swift when --hooks flag is provided
- Updated REPLLoop.swift to use await for the async createAgent call
- All 413 tests pass (17 new tests + 396 existing)
- AC#1: Hooks config JSON loads via HookConfigLoader, registers via createHookRegistry()
- AC#2: preToolUse hooks correctly parsed and passed to AgentOptions.hookRegistry (SDK handles execution)
- AC#3: Hook timeout/error resilience is built into SDK HookRegistry (errors caught, not propagated)

### File List

**New files:**
- Sources/OpenAgentCLI/HookConfigLoader.swift

**Modified files:**
- Sources/OpenAgentCLI/AgentFactory.swift — added hook loading, changed signature to async throws
- Sources/OpenAgentCLI/CLI.swift — added await for createAgentOrExit, added [Hooks configured] message
- Sources/OpenAgentCLI/REPLLoop.swift — added await for createAgent call
- Tests/OpenAgentCLITests/AgentFactoryTests.swift — updated to async/await, hook integration tests
- Tests/OpenAgentCLITests/MCPConfigLoaderTests.swift — updated to async/await
- Tests/OpenAgentCLITests/AutoRestoreTests.swift — updated to async/await
- Tests/OpenAgentCLITests/CLISingleShotTests.swift — updated to async/await
- Tests/OpenAgentCLITests/PermissionHandlerTests.swift — updated to async/await
- Tests/OpenAgentCLITests/REPLLoopInterruptTests.swift — updated to async/await
- Tests/OpenAgentCLITests/REPLLoopTests.swift — updated to async/await
- Tests/OpenAgentCLITests/SessionListResumeTests.swift — updated to async/await
- Tests/OpenAgentCLITests/SessionSaveTests.swift — updated to async/await
- Tests/OpenAgentCLITests/SkillLoadingTests.swift — updated to async/await
- Tests/OpenAgentCLITests/SmokePerformanceTests.swift — updated to async/await
- Tests/OpenAgentCLITests/SubAgentTests.swift — updated to async/await
- Tests/OpenAgentCLITests/ToolLoadingTests.swift — updated to async/await

**Unchanged files (as designed):**
- Sources/OpenAgentCLI/ArgumentParser.swift — hooksConfigPath already existed
- Sources/OpenAgentCLI/REPLLoop.swift — only the one await line changed
- Sources/OpenAgentCLI/OutputRenderer.swift — no rendering changes needed

## Change Log

- 2026-04-21: Story 6.1 implementation complete. Created HookConfigLoader, integrated hook loading into AgentFactory, updated CLI to display hooks status, updated all test files for async/await pattern. 413 tests pass.
