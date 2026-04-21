# Story 6.2: 专业工具与工具过滤

Status: done

## Story

作为一个用户，
我想要加载专业工具并控制哪些工具可用，
以便我可以根据任务定制 Agent 的能力。

## Acceptance Criteria

1. **假设** 传入了 `--tools specialist`
   **当** 创建 Agent
   **那么** 加载 Worktree、Plan、Cron、TodoWrite、LSP、Config、RemoteTrigger、MCP Resource 工具

2. **假设** 传入了 `--tool-deny "Bash,Write"`
   **当** Agent 创建其工具池
   **那么** Bash 和 Write 工具被排除

3. **假设** 传入了 `--tool-allow "Read,Grep,Glob"`
   **当** Agent 创建其工具池
   **那么** 仅有 Read、Grep 和 Glob 工具可用

## Tasks / Subtasks

- [x] Task 1: 修复 `mapToolTier` 中的 specialist 层级工具加载 (AC: #1)
  - [x] 验证 `mapToolTier("specialist")` 当前返回 `getAllBaseTools(tier: .specialist)` 是否包含所有 14 个专业工具
  - [x] 确认 SDK `.specialist` 层级返回：EnterWorktree, ExitWorktree, EnterPlanMode, ExitPlanMode, CronCreate, CronDelete, CronList, TodoWrite, LSP, Config, RemoteTrigger, ListMcpResources, ReadMcpResource
  - [x] 如有差异，修改 `mapToolTier` 确保正确加载

- [x] Task 2: 验证和增强 `computeToolPool` 的工具过滤逻辑 (AC: #2, #3)
  - [x] 验证 `assembleToolPool` 已接收 `allowed` 和 `disallowed` 参数
  - [x] 验证 `filterTools` 在 dedup 之后正确应用
  - [x] 确认 `--tool-allow` 和 `--tool-deny` 在 specialist 层级下也正确工作
  - [x] 验证 `--tool-allow` 和 `--tool-deny` 互斥行为（deny 优先）

- [x] Task 3: 验证 AgentOptions 的 allowedTools/disallowedTools 传递 (AC: #2, #3)
  - [x] 确认 `AgentOptions` 中的 `allowedTools` 和 `disallowedTools` 字段与 `assembleToolPool` 的过滤不重复
  - [x] 确认 SDK 的 Agent 内部也使用这两个字段进行运行时过滤
  - [x] 如果发现双重过滤，决定是否移除 `assembleToolPool` 中的过滤或保留（防御性编程）

- [x] Task 4: 添加测试覆盖 (AC: #1, #2, #3)
  - [x] 测试：`--tools specialist` 加载所有 14 个专业工具
  - [x] 测试：`--tools all` 加载 core + specialist 所有工具
  - [x] 测试：`--tool-deny "Bash,Write"` 正确排除指定工具
  - [x] 测试：`--tool-allow "Read,Grep,Glob"` 正确限制为指定工具
  - [x] 测试：`--tool-allow` 和 `--tool-deny` 同时使用时 deny 优先
  - [x] 测试：空字符串的 `--tool-allow` 或 `--tool-deny` 不影响工具池
  - [x] 回归测试：全部现有测试通过

## Dev Notes

### 前一故事的关键学习

Story 6.1（钩子系统集成）完成后的项目状态：

1. **413 项测试全部通过** — 所有现有测试稳定
2. **AgentFactory.createAgent 已改为 `async throws`** — 所有调用点已适配
3. **HookConfigLoader.swift 已创建** — 遵循 MCPConfigLoader 模式
4. **CLI.swift 已更新** — 显示 `[Hooks configured]` 启动提示
5. **ArgumentParser 已包含 `--tool-allow` 和 `--tool-deny`** — `ParsedArgs` 中 `toolAllow: [String]?` 和 `toolDeny: [String]?` 字段已定义，参数解析已实现
6. **AgentFactory 已使用 `toolAllow` 和 `toolDeny`** — 传递到 `AgentOptions` 和 `assembleToolPool`

### 核心发现：大部分功能已实现

经过详细分析，本故事涉及的大部分功能已经在之前的迭代中实现：

**已实现的部分：**
- `ArgumentParser.swift` 已有 `--tool-allow` 和 `--tool-deny` 参数解析（第 204-211 行）
- `ParsedArgs` 已有 `toolAllow: [String]?` 和 `toolDeny: [String]?` 字段（第 30-31 行）
- `AgentFactory.computeToolPool` 已将 `allowed`/`disallowed` 传递给 `assembleToolPool`（第 168-174 行）
- `AgentFactory.createAgent` 已将 `toolAllow`/`toolDeny` 传递到 `AgentOptions`（第 134-135 行）
- SDK `assembleToolPool` 已实现 dedup + filter（第 149-177 行）
- SDK `filterTools` 已实现 allow/deny 过滤逻辑（第 112-132 行）
- SDK `getAllBaseTools(tier: .specialist)` 已返回 14 个专业工具

**需要验证和补充的部分：**
- `mapToolTier("specialist")` 返回 `getAllBaseTools(tier: .specialist)` — 需确认是否包含 Agent 工具
- `mapToolTier` 中 `"specialist"` 分支只返回 specialist 层工具，没有包含 core 层工具 — 需确认这是否是预期行为
- `computeToolPool` 中 `includeAgentTool` 条件包含 `"specialist"` — 需验证
- 双重过滤：`assembleToolPool` 和 `AgentOptions` 都进行了 allow/deny 过滤 — 需确认无问题

### SDK API 详细参考

本故事涉及的核心 SDK API：

```swift
// ToolTier 枚举
public enum ToolTier: String, Sendable, CaseIterable {
    case core
    case advanced
    case specialist
}

// getAllBaseTools — 按层级获取工具
public func getAllBaseTools(tier: ToolTier) -> [ToolProtocol]

// specialist 层级返回的工具（14 个）：
// - createEnterWorktreeTool()   → "EnterWorktree"
// - createExitWorktreeTool()    → "ExitWorktree"
// - createEnterPlanModeTool()   → "EnterPlanMode"
// - createExitPlanModeTool()    → "ExitPlanMode"
// - createCronCreateTool()      → "CronCreate"
// - createCronDeleteTool()      → "CronDelete"
// - createCronListTool()        → "CronList"
// - createTodoWriteTool()       → "TodoWrite"
// - createLSPTool()             → "LSP"
// - createConfigTool()          → "Config"
// - createRemoteTriggerTool()   → "RemoteTrigger"
// - createListMcpResourcesTool() → "ListMcpResources"
// - createReadMcpResourceTool()  → "ReadMcpResource"
// （共 13 个，不是 14 个——验证时需确认实际数量）

// filterTools — 工具过滤
public func filterTools(
    tools: [ToolProtocol],
    allowed: [String]?,
    disallowed: [String]?
) -> [ToolProtocol]

// assembleToolPool — 组装完整工具池（dedup + filter）
public func assembleToolPool(
    baseTools: [ToolProtocol],
    customTools: [ToolProtocol]?,
    mcpTools: [ToolProtocol]?,
    allowed: [String]?,
    disallowed: [String]?
) -> [ToolProtocol]

// AgentOptions 中的工具过滤字段
public var allowedTools: [String]?     // 白名单
public var disallowedTools: [String]?  // 黑名单（优先于 allowedTools）
```

[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/ToolRegistry.swift]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#allowedTools]

### 当前代码分析

#### `mapToolTier` 当前行为（AgentFactory.swift 第 181-194 行）

```swift
static func mapToolTier(_ tier: String) -> [ToolProtocol] {
    switch tier {
    case "core":
        return getAllBaseTools(tier: .core)
    case "advanced":
        return getAllBaseTools(tier: .core) + getAllBaseTools(tier: .advanced)
    case "specialist":
        return getAllBaseTools(tier: .specialist)  // 只有 specialist，不含 core
    case "all":
        return getAllBaseTools(tier: .core) + getAllBaseTools(tier: .specialist)
    default:
        return getAllBaseTools(tier: .core)
    }
}
```

**关键观察：**
- `"specialist"` 只加载 specialist 层工具，不包含 core 工具
- `"all"` 加载 core + specialist（跳过 advanced，因为 advanced 返回空数组）
- `"advanced"` 加载 core + advanced（advanced 返回空数组，等于只有 core）
- PRD FR3.3 说 `--tools specialist` 加载 specialist 层工具，没有说同时包含 core

#### `computeToolPool` 中的 Agent 工具逻辑

```swift
let includeAgentTool = args.tools == "advanced" || args.tools == "all" || args.tools == "specialist"
if includeAgentTool {
    customTools = (customTools ?? []) + [createAgentTool()]
}
```

**当 `--tools specialist` 时**，Agent 工具会被包含。这是合理的，因为 specialist 模式下的任务更可能需要子代理。

#### 双重过滤分析

`computeToolPool` 中：
```swift
return assembleToolPool(
    baseTools: baseTools,
    customTools: customTools,
    mcpTools: nil,
    allowed: args.toolAllow,      // 过滤 1：在 assembleToolPool 内
    disallowed: args.toolDeny
)
```

`createAgent` 中：
```swift
let options = AgentOptions(
    ...
    allowedTools: args.toolAllow,      // 过滤 2：SDK Agent 运行时
    disallowedTools: args.toolDeny,
    ...
)
```

SDK 的 Agent 在内部也会用 `allowedTools`/`disallowedTools` 做运行时过滤。这意味着 `assembleToolPool` 的过滤是编译时（组装工具池时），而 `AgentOptions` 的过滤是运行时（发送给 LLM 之前）。双重过滤是安全的，不冲突。

### 架构合规性

本故事涉及架构文档中的 **FR3.3, FR3.4**：

- **FR3.3:** 通过 `--tools specialist` 加载 Specialist 层工具 (P1) → `AgentFactory.mapToolTier`, `getAllBaseTools(tier: .specialist)`
- **FR3.4:** 通过 `--tool-allow` / `--tool-deny` 白名单/黑名单控制 (P1) → `ArgumentParser`（已有），`assembleToolPool`（已有），`AgentOptions`（已有）

[来源: _bmad-output/planning-artifacts/epics.md#Story 6.2]
[来源: _bmad-output/planning-artifacts/prd.md#FR3.3, FR3.4]
[来源: _bmad-output/planning-artifacts/architecture.md#FR3]

### 关键约束：零 internal 访问

整个项目仅允许 `import OpenAgentSDK`。不得导入任何 internal 模块或使用 `@_implementationOnly`。如果发现 SDK 缺少 public API，使用 `// SDK-GAP:` 注释记录，不绕过。

[来源: prd.md#技术约束, architecture.md#执行指南]

### 不要做的事

1. **不要重新实现工具过滤逻辑** — SDK 已有 `filterTools` 和 `assembleToolPool`，直接使用即可。

2. **不要修改 ArgumentParser** — `--tool-allow`、`--tool-deny`、`--tools specialist` 已全部实现，无需修改。

3. **不要修改 OutputRenderer** — 工具过滤是工具池组装时的行为，不影响渲染。

4. **不要修改 REPLLoop** — 工具过滤在 Agent 创建时完成，REPL 不需要改动。

5. **不要在 `mapToolTier("specialist")` 中添加 core 工具** — PRD FR3.3 只说加载 specialist 层工具。如果用户需要 core + specialist，应使用 `--tools all`。

6. **不要修改 CLI.swift** — 工具过滤已集成到 AgentFactory 中，CLI 层无需改动。

7. **不要修改 SessionManager、PermissionHandler、HookConfigLoader、MCPConfigLoader** — 这些组件与工具过滤无关。

### 项目结构说明

本故事主要是**验证和测试**工作，预计不需要创建新的源文件。主要工作是编写测试来验证已有功能。

需要创建的测试：
```
Tests/OpenAgentCLITests/
  SpecialistToolFilterTests.swift    # 新建：专业工具和过滤测试
```

可能需要修改的文件：
```
Tests/OpenAgentCLITests/
  ToolLoadingTests.swift             # 可能修改：添加 specialist 层级测试
  AgentFactoryTests.swift            # 可能修改：添加工具过滤测试
```

不需要修改的文件（功能已实现）：
```
Sources/OpenAgentCLI/
  ArgumentParser.swift               # --tools, --tool-allow, --tool-deny 已实现
  AgentFactory.swift                 # mapToolTier, computeToolPool 已实现
  CLI.swift                          # 无需改动
  REPLLoop.swift                     # 无需改动
  OutputRenderer.swift               # 无需改动
  OutputRenderer+SDKMessage.swift    # 无需改动
  PermissionHandler.swift            # 无需改动
  SessionManager.swift               # 无需改动
  MCPConfigLoader.swift              # 无需改动
  HookConfigLoader.swift             # 无需改动
  CLISingleShot.swift                # 无需改动
  ConfigLoader.swift                 # 无需改动
  ANSI.swift                         # 无需改动
  Version.swift                      # 无需改动
  main.swift                         # 无需改动
```

[来源: architecture.md#项目结构]

### 测试策略

**新增测试分布预期：**

| 测试方法名 | 覆盖 AC | 说明 |
|-----------|---------|------|
| testSpecialistTier_loadsAllSpecialistTools | #1 | 验证 specialist 层级加载所有专业工具 |
| testSpecialistTier_includesAgentTool | #1 | 验证 specialist 层级包含 createAgentTool |
| testAllTier_loadsCoreAndSpecialistTools | #1 | 验证 all 层级包含 core + specialist |
| testToolDeny_excludesSpecifiedTools | #2 | 验证 --tool-deny 正确排除工具 |
| testToolDeny_multipleTools | #2 | 验证 --tool-deny 排除多个工具 |
| testToolAllow_restrictsToSpecifiedTools | #3 | 验证 --tool-allow 限制工具池 |
| testToolAllow_multipleTools | #3 | 验证 --tool-allow 指定多个工具 |
| testToolAllowAndDeny_denyTakesPrecedence | #2, #3 | 验证 deny 优先于 allow |
| testToolDeny_withSpecialistTools | #2 | 验证在 specialist 层级下过滤正常 |
| testToolAllow_withSpecialistTools | #3 | 验证在 specialist 层级下限制正常 |
| testEmptyToolAllow_noFiltering | #2 | 空 allow 不影响工具池 |
| testEmptyToolDeny_noFiltering | #3 | 空 deny 不影响工具池 |
| testExistingTestsPass_regression | 全部 | 413 项测试无回归 |

**测试方法：**

1. **工具层级测试** — 调用 `AgentFactory.mapToolTier("specialist")` 验证返回的工具数量和名称。使用 `Set(map { $0.name })` 进行集合比较。

2. **computeToolPool 测试** — 构造不同 `ParsedArgs` 组合，验证 `computeToolPool` 返回的工具池包含/不包含预期工具。

3. **过滤逻辑测试** — 测试 `--tool-allow`、`--tool-deny` 的各种组合场景，包括边界情况。

4. **回归测试** — 确保所有 413 项现有测试继续通过。

### 参考

- [来源: _bmad-output/planning-artifacts/epics.md#Story 6.2]
- [来源: _bmad-output/planning-artifacts/prd.md#FR3.3, FR3.4]
- [来源: _bmad-output/planning-artifacts/architecture.md#FR3]
- [来源: Sources/OpenAgentCLI/AgentFactory.swift — mapToolTier, computeToolPool]
- [来源: Sources/OpenAgentCLI/ArgumentParser.swift — toolAllow, toolDeny, tools 解析]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/ToolRegistry.swift — getAllBaseTools, filterTools, assembleToolPool]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift — AgentOptions.allowedTools, AgentOptions.disallowedTools]
- [来源: _bmad-output/implementation-artifacts/6-1-hook-system-integration.md — 前一故事]

### 项目结构说明

- 无新源文件需要创建（功能已在前序故事中实现）
- 新建 `SpecialistToolFilterTests.swift` 遵循一文件一测试类的约定
- 无与统一项目结构的冲突或偏差

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- All 26 SpecialistToolFilterTests pass (0 failures)
- Full regression suite: 439 tests pass (0 failures)
- No source code modifications required — all functionality already implemented

### Completion Notes List

- Verified `mapToolTier("specialist")` returns all 13 specialist tools (EnterWorktree, ExitWorktree, EnterPlanMode, ExitPlanMode, CronCreate, CronDelete, CronList, TodoWrite, LSP, Config, RemoteTrigger, ListMcpResources, ReadMcpResource) — AC#1 satisfied
- Verified specialist tier does NOT include core tools (per PRD FR3.3, users who need both should use --tools all) — AC#1 satisfied
- Verified `computeToolPool` with --tools specialist includes Agent tool for sub-agent delegation — AC#1 satisfied
- Verified `--tool-deny "Bash,Write"` correctly excludes Bash and Write from tool pool — AC#2 satisfied
- Verified `--tool-allow "Read,Grep,Glob"` restricts pool to only those 3 tools — AC#3 satisfied
- Verified deny takes precedence over allow when both are specified — AC#2 + AC#3 edge case
- Verified empty allow/deny arrays do not affect tool pool — edge case
- Verified tool filtering works with specialist, core, and all tiers
- Confirmed dual filtering (assembleToolPool compile-time + AgentOptions runtime) is safe and non-conflicting — Task 3
- Story 6.2 was primarily a verification and testing story — no source code changes were needed

### File List

New files:
- Tests/OpenAgentCLITests/SpecialistToolFilterTests.swift (26 test methods covering AC#1, #2, #3)

No source files modified (all functionality was already implemented in prior stories).

### Review Findings

Code review completed 2026-04-21. Three adversarial review layers applied (Blind Hunter, Edge Case Hunter, Acceptance Auditor).

- [x] [Review][Patch] Brittle exact-count assertions in deny tests [SpecialistToolFilterTests.swift:174,190,462] — Fixed: replaced hardcoded counts with dynamic `unfilteredPool.count - N` assertions
- [x] [Review][Patch] testToolAllow_withSpecialistTools uses isSubset instead of exact equality [SpecialistToolFilterTests.swift:269] — Fixed: changed to XCTAssertEqual for exact match
- [x] [Review][Defer] Duplicated makeArgs helper in SpecialistToolFilterTests and ToolLoadingTests — deferred, pre-existing pattern for test isolation
- [x] [Review][Defer] testSpecialistTier_hasExpectedCount uses weak >= 13 assertion — deferred, intentional for forward compatibility with SDK additions
- 2 findings dismissed as noise (unnecessary async throws convention, already-covered test scenario)
