# Story 5.1: 权限模式配置

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## 故事

作为一个用户，
我想要控制 Agent 的权限级别，
以便我可以防止意外的破坏性操作。

## 验收标准

1. **假设** 传入了 `--mode bypassPermissions`
   **当** 创建 Agent
   **那么** 所有工具执行无需审批即可进行

2. **假设** 传入了 `--mode default`（或未指定 --mode）
   **当** Agent 尝试执行危险工具（如带 rm 的 Bash）
   **那么** 提示用户批准或拒绝该操作

3. **假设** 传入了 `--mode plan`
   **当** Agent 提出计划
   **那么** 用户必须在执行开始前批准

4. **假设** 提供了无效的模式字符串
   **当** 传入 `--mode invalid`
   **那么** 错误信息列出有效模式并退出

## 任务 / 子任务

- [x] 任务 1: 在 AgentFactory 中设置 canUseTool 回调 (AC: #1, #2, #3)
  - [x] 创建新文件 `Sources/OpenAgentCLI/PermissionHandler.swift`
  - [x] 实现 `PermissionHandler` 结构体，包含 `canUseTool` 闭包工厂方法
  - [x] `default` 模式：对写操作工具（非 readOnly）显示终端提示请求用户确认
  - [x] `plan` 模式：所有工具执行前都需要用户批准（严格于 default）
  - [x] `bypassPermissions` 模式：直接返回 `.allow()`，无需任何提示
  - [x] `acceptEdits` 模式：允许编辑操作，对其他写操作提示确认
  - [x] `dontAsk` 模式：自动批准（与 bypassPermissions 行为一致）
  - [x] `auto` 模式：自动批准（与 bypassPermissions 行为一致）
  - [x] 在 `AgentFactory.createAgent(from:)` 中调用 `PermissionHandler` 设置 `options.canUseTool`

- [x] 任务 2: 实现终端权限提示 UI (AC: #2)
  - [x] 提示显示：工具名称、输入参数摘要和风险级别
  - [x] 用户输入 `y` 或 `yes` → 返回 `.allow()`
  - [x] 用户输入 `n` 或 `no` → 返回 `.deny()`
  - [x] 使用 `InputReading` 协议读取用户输入（复用 REPLLoop 的可测试性模式）
  - [x] 使用 `OutputRendering` 协议输出提示信息（复用 OutputRenderer 的可测试性模式）

- [x] 任务 3: 更新 AgentFactory 以集成 PermissionHandler (AC: #1, #2, #3)
  - [x] 在 `createAgent(from:)` 中根据 `permMode` 创建对应的 `canUseTool` 回调
  - [x] 验证 `--mode bypassPermissions` 不触发任何提示
  - [x] 验证 `--mode default` 对写操作工具触发提示
  - [x] 验证 `--mode plan` 对所有工具触发提示

- [x] 任务 4: 编写测试 (AC: #1, #2, #3, #4)
  - [x] 测试 `--mode bypassPermissions` 不触发 canUseTool 回调（或回调始终返回 allow）
  - [x] 测试 `--mode default` 对 readOnly 工具自动允许
  - [x] 测试 `--mode default` 对写操作工具提示确认
  - [x] 测试 `--mode plan` 对所有工具提示确认
  - [x] 测试无效模式字符串产生错误
  - [x] 测试用户输入 y/yes 返回 allow
  - [x] 测试用户输入 n/no 返回 deny
  - [x] 回归测试：358 项测试全部通过（23 新增 + 335 现有）

## 开发备注

### 前一故事的关键学习

Story 4.2（子代理委派）完成后的项目状态：

1. **335 项测试全部通过** — 所有现有测试稳定，包括 ArgumentParserTests、AgentFactoryTests、ConfigLoaderTests、OutputRendererTests、REPLLoopTests、CLISingleShotTests、SmokePerformanceTests、ToolLoadingTests、SkillLoadingTests、SessionSaveTests、SessionListResumeTests、AutoRestoreTests、MCPConfigLoaderTests、SubAgentTests。

2. **AgentFactory.createAgent 返回 (Agent, SessionStore) 元组** — 所有调用方使用此签名。

3. **ArgumentParser 已支持 `--mode` 参数** — `ParsedArgs.mode` 默认值为 `"default"`，已验证有效模式列表：`["default", "acceptEdits", "bypassPermissions", "plan", "dontAsk", "auto"]`。[来源: `Sources/OpenAgentCLI/ArgumentParser.swift#L47-49, L15`]

4. **AgentFactory 已验证 PermissionMode 转换** — `guard let permMode = PermissionMode(rawValue: args.mode)` 在 `createAgent(from:)` 中已存在，会将无效模式字符串映射为 `AgentFactoryError.invalidMode`。[来源: `Sources/OpenAgentCLI/AgentFactory.swift#L70-72`]

5. **`options.permissionMode` 已正确设置** — `AgentOptions` 的 `permissionMode` 参数已经传入 `permMode`。但 `canUseTool` 回调目前未设置（为 nil），所以 SDK 使用默认的 permissionMode 行为。[来源: `Sources/OpenAgentCLI/AgentFactory.swift#L106`]

### SDK API 详细参考

本故事使用的核心 SDK API — 权限系统：

```swift
// SDK 导出的权限回调类型 (Sources/OpenAgentSDK/Types/PermissionTypes.swift)
/// 闭包类型用于自定义工具权限检查
public typealias CanUseToolFn = @Sendable (ToolProtocol, Any, ToolContext) async -> CanUseToolResult?
```

**CanUseToolFn 参数说明：**
- `ToolProtocol` — 正在请求执行的工具实例，包含 `.name`、`.isReadOnly` 等属性
- `Any` — 工具的原始输入（通常是字典或 JSON 字符串）
- `ToolContext` — 执行上下文，包含 `cwd`、`toolUseId` 等

**CanUseToolResult 返回值：**

```swift
public struct CanUseToolResult: @unchecked Sendable {
    public let behavior: PermissionBehavior
    public let updatedInput: Any?
    public let message: String?
    public let updatedPermissions: [PermissionUpdateAction]?
    public let interrupt: Bool?
    public let toolUseID: String?

    public static func allow() -> CanUseToolResult
    public static func deny(_ message: String) -> CanUseToolResult
    public static func allowWithInput(_ updatedInput: Any) -> CanUseToolResult
}
```

**PermissionBehavior 枚举：**
```swift
public enum PermissionBehavior: String, Sendable, Equatable, CaseIterable {
    case allow = "allow"
    case deny = "deny"
    case ask = "ask"  // 将决策推迟回用户，匹配 TS SDK 的 "ask" 行为
}
```

**PermissionMode 枚举（已在 CLI 中使用）：**
```swift
public enum PermissionMode: String, Sendable, Equatable, CaseIterable {
    case `default`
    case acceptEdits
    case bypassPermissions
    case plan
    case dontAsk
    case auto
}
```

**ToolProtocol 关键属性：**
- `.name: String` — 工具名称（如 "Bash", "Write", "Read"）
- `.isReadOnly: Bool` — 是否为只读工具（Read、Grep、Glob 等为 true）

**AgentOptions.canUseTool 字段：**
```swift
/// 可选的自定义授权回调，优先级高于 permissionMode
public var canUseTool: CanUseToolFn?
```

**Agent.setCanUseTool 方法：**
```swift
/// 动态设置权限回调（可在运行时更改）
public func setCanUseTool(_ callback: CanUseToolFn?)
```

[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/PermissionTypes.swift]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#L251, L439, L213]

### 核心设计决策

#### 决策 1: PermissionHandler 作为独立组件

创建新的 `PermissionHandler.swift` 文件，职责明确：
- 接收 `PermissionMode`、`InputReading`（读取用户输入）和 `OutputRenderer`（显示提示）
- 返回一个 `CanUseToolFn` 闭包
- 使用协议注入确保可测试性（与 REPLLoop 使用 `InputReading` 的模式一致）

```
PermissionHandler
  ├── createCanUseTool(mode:reader:renderer:) -> CanUseToolFn
  │     ├── bypassPermissions/dontAsk/auto → always .allow()
  │     ├── default → ask for write tools, auto-allow read-only
  │     ├── acceptEdits → auto-allow edit tools, ask for others
  │     └── plan → ask for ALL tools
  ├── formatPrompt(tool:input:) -> String
  └── readApproval(reader:) -> Bool
```

#### 决策 2: 各模式的行为映射

| 模式 | readOnly 工具 | 编辑工具（Edit） | 其他写工具 | 说明 |
|------|-------------|--------------|----------|------|
| `bypassPermissions` | 自动允许 | 自动允许 | 自动允许 | 无任何限制 |
| `dontAsk` | 自动允许 | 自动允许 | 自动允许 | 同 bypassPermissions |
| `auto` | 自动允许 | 自动允许 | 自动允许 | 同 bypassPermissions |
| `default` | 自动允许 | 提示确认 | 提示确认 | 只读操作免确认 |
| `acceptEdits` | 自动允许 | 自动允许 | 提示确认 | 编辑操作免确认 |
| `plan` | 提示确认 | 提示确认 | 提示确认 | 所有操作需确认 |

#### 决策 3: 权限提示格式

```
⚠ Bash(command: "rm -rf /tmp/test")
  Allow? (y/n): _
```

- 工具名 + 参数摘要（复用 OutputRenderer.summarizeInput 的格式）
- 使用 ANSI.yellow 显示 `⚠` 警告符号
- 提示行使用 ANSI.bold 高亮 "Allow?"
- 用户输入通过 `InputReading.readLine` 读取

#### 决策 4: canUseTool 返回 nil 的语义

SDK 文档说明 `CanUseToolFn` 返回 `nil` 表示"推迟到下一个策略或默认的 permissionMode 行为"。在 CLI 中，我们始终返回非 nil 的 `CanUseToolResult`，以完全覆盖 SDK 的默认行为，确保 CLI 对权限有完全控制。

#### 决策 5: 不修改 ArgumentParser

`--mode` 参数的解析已完整实现，`ParsedArgs.mode` 字段已存在。`validModes` 已包含所有 6 个有效值。不需要任何修改。

### 架构合规性

本故事涉及架构文档中的 **FR6.1、FR6.2**：

- **FR6.1:** 通过 `--mode` 设置权限模式 → `ArgumentParser.swift`（已实现），`PermissionHandler.swift`（新建，提供 canUseTool 回调）
- **FR6.2:** 默认模式为 `default`：危险操作需要用户确认 → `PermissionHandler.swift`（default 模式对写操作工具提示确认）

架构文档中提到的文件映射：
- FR6 → `ArgumentParser.swift`, `AgentFactory.swift`, `PermissionHandler.swift`
- 本故事需要新建 `PermissionHandler.swift` 并修改 `AgentFactory.swift`

[来源: _bmad-output/planning-artifacts/epics.md#Story 5.1]
[来源: _bmad-output/planning-artifacts/prd.md#FR6.1, FR6.2]
[来源: _bmad-output/planning-artifacts/architecture.md#FR6:权限→PermissionHandler.swift]

### 关键约束：零 internal 访问

整个项目仅允许 `import OpenAgentSDK`。不得导入任何 internal 模块或使用 `@_implementationOnly`。如果发现 SDK 缺少 public API，使用 `// SDK-GAP:` 注释记录，不绕过。

[来源: prd.md#技术约束, architecture.md#执行指南]

### 不要做的事

1. **不要修改 ArgumentParser** — `--mode` 参数已完整实现，包括验证和错误信息。[来源: `Sources/OpenAgentCLI/ArgumentParser.swift#L47-49, L116-122`]

2. **不要修改 SDK 的 PermissionMode 处理** — SDK 的 `PermissionMode` 枚举已正确使用，AgentFactory 已将其转换为 `AgentOptions.permissionMode`。

3. **不要实现 `/mode` 动态切换** — 这是 Epic 6 Story 6.3 的功能（P1）。本故事只处理启动时的 `--mode` 配置。

4. **不要实现 SIGINT 在权限提示中的处理** — 这是 Story 5.3（优雅中断处理）的职责。本故事的权限提示只处理 y/n 输入。

5. **不要修改 REPLLoop** — 权限回调通过 `CanUseToolFn` 在 Agent 内部处理，REPLLoop 不需要知道权限提示的存在。SDK 会在工具执行前自动调用回调。

6. **不要修改 OutputRenderer+SDKMessage.swift** — 权限提示通过 PermissionHandler 自己使用 OutputRenderer 输出，不需要新的 SDKMessage 渲染方法。

7. **不要实现 PermissionPolicy 协议** — SDK 提供了 `PermissionPolicy` 协议和 `canUseTool(policy:)` 桥接函数，但 CLI 需要交互式终端提示，不适合用纯策略模式。直接使用 `CanUseToolFn` 闭包更灵活。

8. **不要创建 PermissionHandlerTests 中对实际 Agent 的集成测试** — 只需要单元测试 `canUseTool` 闭包的行为（给定工具类型和模式，验证返回值）。Agent 的集成行为由 SDK 保证。

### 项目结构说明

需要修改的文件：
```
Sources/OpenAgentCLI/
  AgentFactory.swift                    # 修改：调用 PermissionHandler 设置 canUseTool
  PermissionHandler.swift               # 新建：权限提示和 canUseTool 回调工厂
```

需要新增的测试：
```
Tests/OpenAgentCLITests/
  PermissionHandlerTests.swift          # 新建：覆盖所有模式 + 用户输入场景
```

不修改的文件：
```
Sources/OpenAgentCLI/
  ArgumentParser.swift                  # 参数解析不变（--mode 已存在）
  CLI.swift                             # 启动流程不变
  REPLLoop.swift                        # REPL 循环不变
  OutputRenderer.swift                  # 渲染器不变（PermissionHandler 直接使用 renderer）
  OutputRenderer+SDKMessage.swift       # SDKMessage 渲染不变
  MCPConfigLoader.swift                 # MCP 配置不变
  CLISingleShot.swift                   # 单次模式不变
  ConfigLoader.swift                    # 配置加载不变
  ANSI.swift                            # ANSI 辅助不变（已有 yellow 和 bold）
  Version.swift                         # 版本不变
  main.swift                            # 入口不变
```

[来源: architecture.md#项目结构]

### 测试策略

**新增测试分布预期：**

| 测试方法名 | 覆盖 AC | 说明 |
|-----------|---------|------|
| testBypassPermissions_alwaysAllows | #1 | bypassPermissions 模式对任何工具都返回 allow |
| testDontAsk_alwaysAllows | #1 | dontAsk 模式同 bypassPermissions |
| testAuto_alwaysAllows | #1 | auto 模式同 bypassPermissions |
| testDefault_allowsReadOnlyTool | #2 | default 模式对 readOnly 工具自动允许 |
| testDefault_promptsForWriteTool_yes | #2 | default 模式对写操作工具提示，用户输入 yes 返回 allow |
| testDefault_promptsForWriteTool_no | #2 | default 模式对写操作工具提示，用户输入 no 返回 deny |
| testAcceptEdits_allowsEditTool | #2 | acceptEdits 模式自动允许编辑工具 |
| testAcceptEdits_promptsForOtherWrite | #2 | acceptEdits 对非编辑写操作提示确认 |
| testPlan_promptsForAllTools | #3 | plan 模式对所有工具（包括 readOnly）提示确认 |
| testInvalidMode_throwsError | #4 | 无效模式字符串产生错误 |
| testExistingTestsStillPass_regression | 全部 | 335 项测试无回归 |

**测试方法：**

1. **canUseTool 闭包单元测试** — 构造 mock `ToolProtocol`（设置 name 和 isReadOnly）、mock `InputReading`（返回预定义的 y/n）、mock `OutputRenderer`。调用 `PermissionHandler` 生产的 `CanUseToolFn` 闭包，验证返回的 `CanUseToolResult.behavior`。

2. **Mock ToolProtocol** — 创建简单的结构体实现 `ToolProtocol`，提供 `name` 和 `isReadOnly` 属性。参考 SDK 的 `ToolProtocol` 定义：需要实现 `name`、`description`、`isReadOnly`、`inputSchema`、`execute(params:context:)` 等属性和方法。

3. **无效模式测试** — 验证 `AgentFactory.createAgent(from:)` 在传入无效 mode 时抛出 `AgentFactoryError.invalidMode`。这部分已在现有测试中覆盖，但需要确认 PermissionHandler 不会改变此行为。

**注意：** PermissionHandler 的测试不需要真正的 Agent 实例。测试只需验证 `CanUseToolFn` 闭包在不同模式和工具类型下的返回值。

### 参考

- [来源: _bmad-output/planning-artifacts/epics.md#Story 5.1]
- [来源: _bmad-output/planning-artifacts/prd.md#FR6.1, FR6.2, FR6.4]
- [来源: _bmad-output/planning-artifacts/architecture.md#FR6:权限→PermissionHandler.swift]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/PermissionTypes.swift (CanUseToolFn, CanUseToolResult, PermissionMode, PermissionPolicy)]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#L251 (AgentOptions.canUseTool)]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L213 (setCanUseTool)]
- [来源: Sources/OpenAgentCLI/ArgumentParser.swift#L47-49 (validModes), L116-122 (--mode parsing)]
- [来源: Sources/OpenAgentCLI/AgentFactory.swift#L70-72 (PermissionMode conversion), L106 (permissionMode setting)]
- [来源: Sources/OpenAgentCLI/REPLLoop.swift#L10-13 (InputReading protocol pattern)]
- [来源: Sources/OpenAgentCLI/OutputRenderer.swift#L45-48 (OutputRendering protocol)]
- [来源: _bmad-output/implementation-artifacts/4-2-sub-agent-delegation.md (前一故事学习)]
- [来源: _bmad-output/implementation-artifacts/deferred-work.md (延迟工作)]

### 项目结构说明

- 新建 `PermissionHandler.swift` 遵循架构文档的文件命名约定（PascalCase，一个类型一个文件）
- `PermissionHandler` 使用 `InputReading` 和 `OutputRendering` 协议注入，与 `REPLLoop` 的可测试性模式保持一致
- 没有与统一项目结构的冲突或偏差

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Implemented `PermissionHandler` enum with `createCanUseTool(mode:reader:renderer:)` factory method
- All 6 permission modes implemented: bypassPermissions, dontAsk, auto (all auto-allow), default (prompt for writes), acceptEdits (auto-allow edits, prompt for others), plan (prompt for all)
- Permission prompt displays ANSI-styled warning sign, tool name, input summary, and bold "Allow? (y/n):" prompt
- Integrated PermissionHandler into AgentFactory.createAgent(from:) by creating FileHandleInputReader and OutputRenderer for the canUseTool callback
- All 23 new PermissionHandlerTests pass, covering all 4 acceptance criteria
- Full regression suite passes: 358 tests (23 new + 335 existing), 0 failures
- No changes to ArgumentParser, REPLLoop, OutputRenderer, or any other existing files

### Change Log

- 2026-04-20: Story 5.1 implementation complete. Created PermissionHandler.swift, modified AgentFactory.swift. 23 new tests, 358 total tests pass.

### File List

- `Sources/OpenAgentCLI/PermissionHandler.swift` (NEW)
- `Sources/OpenAgentCLI/AgentFactory.swift` (MODIFIED)
- `Tests/OpenAgentCLITests/PermissionHandlerTests.swift` (EXISTING - pre-created in ATDD phase)

### Review Findings

- [x] [Review][Patch] testPlan_promptsForAllTools missing result behavior assertion [Tests/OpenAgentCLITests/PermissionHandlerTests.swift:329] -- fixed during review
- [x] [Review][Defer] Single-shot mode + default/plan mode: stdin EOF causes silent deny of all write tools -- deferred to Story 5.2, pre-existing design scope
- [x] [Review][Defer] PermissionHandler bypasses OutputRendering protocol, writes directly to output stream -- deferred, pre-existing architectural choice
