# Story 5.2: 交互式权限提示

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## 故事

作为一个用户，
我想要在 Agent 请求权限时看到清晰的提示，显示操作内容和风险级别，
以便我了解它即将做什么并能做出明智的决定。

## 验收标准

1. **假设** Agent 请求执行危险工具
   **当** 权限回调触发
   **那么** 提示显示：工具名称、输入参数摘要和风险级别

2. **假设** 权限提示已显示
   **当** 我输入 `y` 或 `yes`
   **那么** 工具执行继续

3. **假设** 权限提示已显示
   **当** 我输入 `n` 或 `no`
   **那么** 工具执行被拒绝，Agent 收到通知

## 任务 / 子任务

- [x] 任务 1: 增强权限提示的显示内容 (AC: #1)
  - [x] 在 PermissionHandler 中添加风险级别分类逻辑（high/medium/low）
  - [x] 根据 `tool.name` 和 `tool.isReadOnly` 判定风险级别
  - [x] 增强提示格式：显示工具名称 + 参数摘要 + 风险级别标签
  - [x] 高风险工具（Bash with destructive commands, Write, Edit to sensitive paths）显示红色风险标签
  - [x] 中风险工具（普通 Write/Edit）显示黄色风险标签
  - [x] 为单次提问模式（non-interactive stdin）添加优雅降级处理

- [x] 任务 2: 增强用户交互体验 (AC: #2, #3)
  - [x] 支持 `y`/`yes`/`n`/`no` 以外，增加 `a`/`always` 选项（本次会话始终允许该工具）
  - [x] 增加空输入（直接按 Enter）默认为 `n` 的行为
  - [x] 非交互模式下（stdin EOF）提供明确的拒绝消息而非静默拒绝

- [x] 任务 3: 处理单次提问模式的权限问题 (AC: #1, #2, #3)
  - [x] 检测 stdin 是否为终端（isatty 检查或 FileHandleInputReader 的 EOF 行为）
  - [x] 非交互模式下：对 default/plan 模式显示警告并自动拒绝写操作
  - [x] 非交互模式下：推荐用户使用 `--mode bypassPermissions` 或 `--mode dontAsk`

- [x] 任务 4: 编写测试 (AC: #1, #2, #3)
  - [x] 测试风险级别分类的正确性（Bash rm → high, Write → medium, Read → N/A）
  - [x] 测试提示输出包含工具名、参数摘要和风险标签
  - [x] 测试 `a`/`always` 选项的会话级记忆功能
  - [x] 测试空输入默认拒绝行为
  - [x] 测试非交互模式下的降级行为
  - [x] 回归测试：确保所有现有测试通过

## 开发备注

### 前一故事的关键学习

Story 5.1（权限模式配置）完成后的项目状态：

1. **358 项测试全部通过** — 所有现有测试稳定，包括 PermissionHandlerTests（23 项新增测试）

2. **PermissionHandler.swift 已创建** — 核心结构如下：
   - `PermissionHandler` 枚举，包含 `createCanUseTool(mode:reader:renderer:)` 工厂方法
   - `promptUser(tool:input:reader:renderer:)` 私有方法处理终端提示
   - `summarizeInput(_:)` 私有方法生成参数摘要
   - 所有 6 种权限模式的行为已实现
   - [来源: `Sources/OpenAgentCLI/PermissionHandler.swift`]

3. **现有提示格式**（需要增强）：
   ```
   ⚠ Bash(command: "rm -rf /tmp/test")
     Allow? (y/n): _
   ```
   - 仅显示工具名 + 参数摘要，缺少风险级别标签
   - 没有区分不同风险等级的视觉差异
   - [来源: `Sources/OpenAgentCLI/PermissionHandler.swift#L78-95`]

4. **延迟工作（来自 Story 5.1 Review）**：
   - **单次提问模式 + default/plan 模式：stdin EOF 导致静默拒绝所有写工具** — 当使用 `--prompt`（单次提问）配合 `--mode default` 或 `--mode plan` 时，stdin 是非交互式的。`FileHandleInputReader.readLine()` 返回 nil（EOF），导致 `canUseTool` 返回 `.deny("No input received")`。需要在 Story 5.2 中解决此问题。
   - **PermissionHandler 绕过 OutputRendering 协议** — 直接写入 `renderer.output`（AnyTextOutputStream）。这是有意的架构选择，因为 `OutputRendering` 设计用于 `SDKMessage` 事件，而非权限提示。
   - [来源: `_bmad-output/implementation-artifacts/deferred-work.md`]

5. **AgentFactory 集成** — `canUseTool` 回调在 `AgentFactory.createAgent(from:)` 中通过以下代码设置：
   ```swift
   let reader = FileHandleInputReader()
   let permRenderer = OutputRenderer()
   let canUseTool = PermissionHandler.createCanUseTool(mode: permMode, reader: reader, renderer: permRenderer)
   ```
   - 每次创建 Agent 时生成新的 PermissionHandler 闭包
   - [来源: `Sources/OpenAgentCLI/AgentFactory.swift#L97-103`]

### SDK API 详细参考

本故事使用的核心 SDK API — 与 Story 5.1 相同，无需新的 SDK 类型：

```swift
// CanUseToolFn 闭包签名
public typealias CanUseToolFn = @Sendable (ToolProtocol, Any, ToolContext) async -> CanUseToolResult?

// CanUseToolResult 工厂方法
public static func allow() -> CanUseToolResult
public static func deny(_ message: String) -> CanUseToolResult
public static func allowWithInput(_ updatedInput: Any) -> CanUseToolResult

// ToolProtocol 关键属性
// .name: String — 工具名称
// .isReadOnly: Bool — 是否为只读工具
```

**不需要新的 SDK API。** 所有功能均基于现有的 `CanUseToolFn`、`ToolProtocol` 和 `ANSI` 辅助类型实现。

[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/PermissionTypes.swift]

### 核心设计决策

#### 决策 1: 风险级别分类

在 `PermissionHandler` 中添加风险级别分类，不引入新的类型或文件：

| 风险级别 | 工具/条件 | 标签颜色 | 示例 |
|---------|----------|---------|------|
| HIGH | Bash 含破坏性命令（rm, rm -rf, rmdir, format, mkfs） | 红色 `[HIGH RISK]` | `Bash(command: "rm -rf /tmp")` |
| MEDIUM | 非编辑写操作工具（Write, Bash 非 destructive） | 黄色 `[MEDIUM RISK]` | `Write(file_path: "/tmp/out.txt")` |
| LOW | 编辑工具（Edit）、acceptEdits 模式下的编辑操作 | 暗色 `[LOW RISK]` | `Edit(file_path: "src/main.swift")` |

风险级别通过检查 `tool.name` 和 `input` 参数内容来确定。对于 Bash 工具，检查命令字符串是否包含破坏性关键词。

#### 决策 2: 增强的提示格式

新提示格式：
```
⚠ [HIGH RISK] Bash
  command: "rm -rf /tmp/test"
  Allow? (y/n/a - yes/no/always): _
```

对比现有格式（Story 5.1）：
```
⚠ Bash(command: "rm -rf /tmp/test")
  Allow? (y/n): _
```

变化：
- 风险级别标签在工具名之前，使用对应颜色
- 参数摘要换行缩进显示（每个参数一行，而非逗号分隔）
- 提示选项增加 `a`/`always`
- 高风险标签使用 ANSI.red，中风险使用 ANSI.yellow，低风险使用 ANSI.dim

#### 决策 3: "Always" 选项的会话级记忆

当用户输入 `a` 或 `always` 时：
- 在 PermissionHandler 内部维护一个 `Set<String>` 记录被始终允许的工具名
- 同一会话内后续对同名工具的权限请求自动允许
- 此状态通过闭包捕获的引用类型（类包装器）共享
- 不持久化到磁盘（仅会话级有效）

实现方式：将 `PermissionHandler` 从枚举改为可以使用实例方法，或引入一个 `PermissionState` 类来持有 `alwaysAllowedTools` 集合。

```swift
/// Mutable state for permission session-level memory.
final class PermissionState: @unchecked Sendable {
    private let lock = NSLock()
    private var _alwaysAllowedTools: Set<String> = []

    func isAlwaysAllowed(_ toolName: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _alwaysAllowedTools.contains(toolName)
    }

    func markAlwaysAllowed(_ toolName: String) {
        lock.lock()
        defer { lock.unlock() }
        _alwaysAllowedTools.insert(toolName)
    }
}
```

#### 决策 4: 非交互模式降级处理

解决 Story 5.1 延迟的问题：单次提问模式下的 stdin EOF 导致静默拒绝。

**检测方法：** 在 `PermissionHandler.createCanUseTool` 中添加 `isInteractive: Bool` 参数。由 `AgentFactory` 根据是否有 `--prompt` 参数来判断。

```swift
static func createCanUseTool(
    mode: PermissionMode,
    reader: InputReading,
    renderer: OutputRenderer,
    isInteractive: Bool  // 新参数
) -> CanUseToolFn
```

**非交互模式行为：**
- bypassPermissions/dontAsk/auto：保持自动允许（无变化）
- default：写操作被拒绝，并输出警告信息 "Non-interactive mode: tool '{name}' denied. Use --mode bypassPermissions to allow."
- plan：所有操作被拒绝，并输出警告信息
- acceptEdits：非编辑写操作被拒绝，并输出警告信息

**AgentFactory 修改：**
```swift
let isInteractive = args.prompt == nil && args.skillName == nil
let canUseTool = PermissionHandler.createCanUseTool(
    mode: permMode,
    reader: reader,
    renderer: permRenderer,
    isInteractive: isInteractive
)
```

#### 决策 5: 空输入默认拒绝

当用户直接按 Enter（空输入）时，默认视为拒绝：
- 空行 → 返回 `.deny("Permission denied (default)")`
- 这比当前行为（空行落入 default case 返回 deny）更明确，因为现在会输出说明

#### 决策 6: 不修改现有测试的期望行为

现有的 23 项 PermissionHandlerTests 中的测试调用签名需要更新（添加 `isInteractive` 参数），但测试的期望行为不变。新的 `isInteractive` 参数默认为 `true` 可以避免破坏现有测试。

### 架构合规性

本故事涉及架构文档中的 **FR6.4**：

- **FR6.4:** 权限确认提示清晰显示操作内容和风险 → `PermissionHandler.swift`（增强提示格式，添加风险级别）

架构文档中提到的文件映射：
- FR6 → `ArgumentParser.swift`, `AgentFactory.swift`, `PermissionHandler.swift`
- 本故事主要修改 `PermissionHandler.swift`，小幅修改 `AgentFactory.swift`
- 不需要修改 `ArgumentParser.swift`

[来源: _bmad-output/planning-artifacts/epics.md#Story 5.2]
[来源: _bmad-output/planning-artifacts/prd.md#FR6.4]
[来源: _bmad-output/planning-artifacts/architecture.md#FR6:权限→PermissionHandler.swift]

### 关键约束：零 internal 访问

整个项目仅允许 `import OpenAgentSDK`。不得导入任何 internal 模块或使用 `@_implementationOnly`。如果发现 SDK 缺少 public API，使用 `// SDK-GAP:` 注释记录，不绕过。

[来源: prd.md#技术约束, architecture.md#执行指南]

### 不要做的事

1. **不要实现 `/mode` 动态切换** — 这是 Epic 6 Story 6.3 的功能（P1）。本故事只处理权限提示的显示和交互增强。

2. **不要修改 ArgumentParser** — `--mode` 参数已完整实现。不需要添加新的命令行参数。[来源: `Sources/OpenAgentCLI/ArgumentParser.swift`]

3. **不要修改 REPLLoop** — 权限回调通过 `CanUseToolFn` 在 Agent 内部处理，REPLLoop 不需要知道权限提示的存在。

4. **不要修改 OutputRenderer+SDKMessage.swift** — 权限提示通过 PermissionHandler 自己使用 OutputRenderer 输出，不需要新的 SDKMessage 渲染方法。

5. **不要创建新的 Swift 文件** — 所有更改都在 `PermissionHandler.swift`（增强）和 `AgentFactory.swift`（传递 isInteractive 参数）中完成。`PermissionState` 类可以定义在 `PermissionHandler.swift` 内部。

6. **不要引入第三方依赖** — 风险级别分类使用纯 Swift 字符串匹配，不使用正则表达式库。

7. **不要实现持久化的权限策略** — `always` 选项仅在当前会话有效，不写入配置文件。

### 项目结构说明

需要修改的文件：
```
Sources/OpenAgentCLI/
  PermissionHandler.swift               # 修改：增强提示格式、添加风险级别、支持 always 选项、非交互降级
  AgentFactory.swift                    # 修改：传递 isInteractive 参数给 PermissionHandler
```

需要修改的测试：
```
Tests/OpenAgentCLITests/
  PermissionHandlerTests.swift          # 修改：更新调用签名、添加新测试用例
```

不修改的文件：
```
Sources/OpenAgentCLI/
  ArgumentParser.swift                  # 参数解析不变
  CLI.swift                             # 启动流程不变
  REPLLoop.swift                        # REPL 循环不变
  OutputRenderer.swift                  # 渲染器不变
  OutputRenderer+SDKMessage.swift       # SDKMessage 渲染不变
  MCPConfigLoader.swift                 # MCP 配置不变
  CLISingleShot.swift                   # 单次模式不变
  ConfigLoader.swift                    # 配置加载不变
  ANSI.swift                            # ANSI 辅助不变（已有 red, yellow, dim, bold）
  Version.swift                         # 版本不变
  main.swift                            # 入口不变
```

[来源: architecture.md#项目结构]

### 测试策略

**新增/修改测试分布预期：**

| 测试方法名 | 覆盖 AC | 说明 |
|-----------|---------|------|
| testRiskLevel_highRisk_destructiveBash | #1 | Bash 含 rm -rf 命令 → 高风险 |
| testRiskLevel_mediumRisk_writeTool | #1 | Write 工具 → 中风险 |
| testRiskLevel_lowRisk_editTool | #1 | Edit 工具 → 低风险 |
| testPromptDisplays_riskLevelTag | #1 | 提示输出包含风险级别标签 |
| testPromptDisplays_toolName | #1 | 提示输出包含工具名称 |
| testPromptDisplays_inputSummary | #1 | 提示输出包含参数摘要 |
| testAlwaysOption_sessionLevelMemory | #2 | 输入 `a` 后，同工具不再提示 |
| testEmptyInput_defaultsToDeny | #3 | 空输入 → 拒绝 |
| testNonInteractive_defaultMode_deniesWriteTool | #1, #3 | 非交互模式下写操作被拒绝，有警告信息 |
| testNonInteractive_planMode_deniesAllTools | #1, #3 | 非交互模式下所有操作被拒绝 |
| testNonInteractive_bypassPermissions_autoAllows | #1 | 非交互模式下 bypassPermissions 仍然自动允许 |
| testExistingTestsPass_regression | 全部 | 358 项测试无回归 |

**测试方法：**

1. **风险级别测试** — 构造不同 `MockTool` + 不同 input 字典，验证 `riskLevel` 分类的正确性。

2. **提示格式测试** — 使用 `MockPermissionOutput` 捕获输出，验证包含风险标签、工具名、参数摘要。

3. **Always 选项测试** — 连续调用两次 `canUseTool`，第一次输入 `a`，第二次验证不再提示直接允许。

4. **非交互模式测试** — 使用 `isInteractive: false` 创建 `canUseTool`，验证写操作被拒绝且输出包含推荐使用 `--mode bypassPermissions` 的信息。

5. **回归测试** — 确保所有现有 358 项测试通过。由于 `createCanUseTool` 签名变化（添加 `isInteractive` 参数），需要更新现有测试中的调用点。使用默认参数 `isInteractive: true` 可以最小化改动。

### 参考

- [来源: _bmad-output/planning-artifacts/epics.md#Story 5.2]
- [来源: _bmad-output/planning-artifacts/prd.md#FR6.4]
- [来源: _bmad-output/planning-artifacts/architecture.md#FR6:权限→PermissionHandler.swift]
- [来源: Sources/OpenAgentCLI/PermissionHandler.swift — 现有实现，需要增强]
- [来源: Sources/OpenAgentCLI/AgentFactory.swift#L97-103 — canUseTool 集成点]
- [来源: Sources/OpenAgentCLI/ANSI.swift — 已有 red, yellow, dim, bold]
- [来源: Sources/OpenAgentCLI/REPLLoop.swift#L10-13 — InputReading 协议模式]
- [来源: Sources/OpenAgentCLI/OutputRenderer.swift#L45-48 — OutputRendering 协议]
- [来源: _bmad-output/implementation-artifacts/5-1-permission-mode-configuration.md — 前一故事]
- [来源: _bmad-output/implementation-artifacts/deferred-work.md — 延迟工作（单次提问模式 EOF 问题）]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/PermissionTypes.swift — CanUseToolFn, CanUseToolResult]

### 项目结构说明

- 所有更改在现有文件内完成，不创建新文件
- `PermissionHandler.swift` 增强遵循现有的代码风格（枚举 + 静态方法）
- `PermissionState` 类定义在 `PermissionHandler.swift` 内部，保持一文件一模块的约定
- `isInteractive` 参数使用默认值 `true`，确保向后兼容现有调用方
- 没有与统一项目结构的冲突或偏差

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Implemented `RiskLevel` enum (`.high`, `.medium`, `.low`) with `Equatable` conformance in PermissionHandler.swift
- Added `PermissionHandler.classifyRiskLevel(tool:input:)` public static method for risk classification
  - HIGH: Bash with destructive commands (rm -rf, rm -r, rm -f, rmdir, format, mkfs, dd, shred, wipe)
  - MEDIUM: Write tools, non-destructive Bash commands
  - LOW: Edit tools
- Added `PermissionState` class with thread-safe `NSLock` for session-level "always" option memory
- Enhanced prompt format: `[RISK TAG] ToolName` with indented parameter lines below
- ANSI color coding: red for HIGH, yellow for MEDIUM, dim for LOW
- Added `isInteractive: Bool = true` parameter to `createCanUseTool` (backward compatible)
- Non-interactive mode: denies write/plan operations with warning suggesting `--mode bypassPermissions`
- Added `a`/`always` option support with session-level tool approval memory
- Empty input defaults to deny with explicit message
- Updated `AgentFactory.createAgent(from:)` to pass `isInteractive` based on `args.prompt == nil && args.skillName == nil`
- All 383 tests pass (0 regressions), including 48 PermissionHandlerTests (27 new Story 5.2 tests + 21 existing Story 5.1 tests)

### File List

- `Sources/OpenAgentCLI/PermissionHandler.swift` — Modified: Added RiskLevel enum, PermissionState class, classifyRiskLevel method, enhanced prompt format with risk tags, isInteractive parameter, always option support, non-interactive mode degradation
- `Sources/OpenAgentCLI/AgentFactory.swift` — Modified: Added isInteractive calculation and passed to PermissionHandler.createCanUseTool

### Change Log

- 2026-04-21: Story 5.2 implementation complete. Added risk level classification, enhanced prompt format with ANSI colors, always option with session memory, empty input default deny, non-interactive mode degradation. 383 tests pass, 0 regressions.

### Review Findings

- [x] [Review][Patch] Extract duplicated non-interactive denial message to a helper [PermissionHandler.swift:133,156,172] -- FIXED during review
- [x] [Review][Patch] Extract duplicated isInteractive + alwaysAllowed check pattern [PermissionHandler.swift:131-142,154-165,170-181] -- FIXED during review
- [x] [Review][Patch] Move summarizeInput call into else branch to avoid wasted computation [PermissionHandler.swift:213] -- FIXED during review
