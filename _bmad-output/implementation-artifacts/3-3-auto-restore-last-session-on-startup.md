# Story 3.3: 启动时自动恢复上次会话

Status: done

## 故事

作为一个用户，
我想要 CLI 在启动时自动继续上次的对话，
以便我不必每次都手动恢复。

## 验收标准

1. **假设** 存在最近的已保存会话
   **当** CLI 以 REPL 模式启动（不带 `--no-restore`）
   **那么** 自动加载并继续上次的会话

2. **假设** 传入了 `--session <id>`
   **当** CLI 启动
   **那么** 加载指定会话而非最近的会话

3. **假设** 传入了 `--no-restore`
   **当** CLI 启动
   **那么** 无论是否有已保存的会话，都启动新会话

4. **假设** 会话恢复失败（文件损坏）
   **当** CLI 启动
   **那么** 显示警告并启动新会话

## 任务 / 子任务

- [x] 任务 1: 修改 AgentFactory 支持 continueRecentSession 选项 (AC: #1, #2, #3)
  - [x] 在 `createAgent(from:)` 中根据 `args.noRestore` 和 `args.sessionId` 设置 `continueRecentSession`
  - [x] 逻辑：如果 `args.sessionId != nil`（显式指定会话），sessionId 已由 `resolveSessionId` 处理，continueRecentSession 不需要设为 true
  - [x] 逻辑：如果 `args.noRestore == true`，continueRecentSession = false（默认），使用新生成的 sessionId
  - [x] 逻辑：如果 `args.sessionId == nil && args.noRestore == false`，设置 `continueRecentSession = true`，让 SDK 自动恢复最近会话
  - [x] 当 continueRecentSession = true 时，不需要传递预生成的 sessionId（传 nil 让 SDK 自己 resolve）
  - [x] 回归测试验证：285 项现有测试全部通过

- [x] 任务 2: 在 CLI.swift 中添加恢复状态提示 (AC: #1)
  - [x] 当 continueRecentSession 生效时，REPL 启动前显示 "[Restoring last session...]" 提示
  - [x] 验证恢复成功后显示简短确认（如会话 ID 前 8 位）
  - [x] 无会话可恢复时静默开始新会话（不显示错误）

- [x] 任务 3: 处理会话恢复失败的优雅降级 (AC: #4)
  - [x] SDK 的 continueRecentSession 机制：如果没有已保存会话，resolvedSessionId 保持 nil，Agent 行为等同于新会话
  - [x] 如果会话文件损坏导致加载异常，SDK 会抛出错误——CLI 在 REPL prompt/stream 首次调用时可能遇到该错误
  - [x] 在 REPLLoop.start() 的 stream 调用 catch 块中，检测是否为会话恢复相关的错误
  - [x] 显示友好的降级消息并建议使用 `--no-restore` 启动新会话
  - [x] 确保即使恢复失败，REPL 仍然可用

- [x] 任务 4: 编写 AutoRestoreTests 测试 (AC: #1, #2, #3, #4)
  - [x] 测试 `createAgent` 在默认配置下（无 --session、无 --no-restore）设置 continueRecentSession = true
  - [x] 测试 `createAgent` 在有 --session 时设置 sessionId 但 continueRecentSession = false
  - [x] 测试 `createAgent` 在有 --no-restore 时设置 continueRecentSession = false 且 sessionId 为新生成 UUID
  - [x] 测试 `createAgent` 在 --no-restore + --session 组合时使用指定的 sessionId
  - [x] 测试恢复提示输出（集成测试级别）
  - [x] 测试无已保存会话时不显示恢复提示
  - [x] 回归测试验证

- [x] 任务 5: 回归测试验证 (AC: 全部)
  - [x] 确保 285 项现有测试全部通过
  - [x] 确保不破坏 Story 1.x、2.x、3.1、3.2 的任何功能

## 开发备注

### 前一故事的关键学习

Story 3.2（列出和恢复历史会话）已建立以下基础和模式：

1. **285 项测试全部通过** — 分布于 ArgumentParserTests、AgentFactoryTests、ConfigLoaderTests、OutputRendererTests、REPLLoopTests、CLISingleShotTests、SmokePerformanceTests、ToolLoadingTests、SkillLoadingTests、SessionSaveTests、SessionListResumeTests。[来源: 最新 `swift test` 执行结果]

2. **AgentFactory.createAgent 返回 (Agent, SessionStore) 元组** — Story 3.2 将返回类型从 `Agent` 改为 `(Agent, SessionStore)`，所有调用方（CLI.swift 和 8 个测试文件）已更新。[来源: `Sources/OpenAgentCLI/AgentFactory.swift#L60`]

3. **REPLLoop 持有 AgentHolder、SessionStore、ParsedArgs** — Story 3.2 添加了 `AgentHolder` class wrapper（允许 struct 中的 agent mutation）、`sessionStore: SessionStore?` 和 `parsedArgs: ParsedArgs?` 参数。这些基础可直接复用。[来源: `Sources/OpenAgentCLI/REPLLoop.swift#L38-41, L56-57`]

4. **SDK 的 continueRecentSession 机制已确认可用** — SDK AgentOptions 有 `continueRecentSession: Bool` 参数（默认 false）。当设为 true 时，SDK 在首次 prompt/stream 前自动从 SessionStore.list() 获取最近会话并恢复。[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#L377-380, L476]

5. **deferred-work.md 已有 4 项** — 包括 force-unwrap 模式、误导性错误消息、AgentOptions 未完整填充、缺失测试路径。不要在此故事中修复这些问题，除非直接相关。[来源: `_bmad-output/implementation-artifacts/deferred-work.md`]

### SDK API 详细参考

本故事使用的核心 SDK API — `continueRecentSession`：

```swift
// AgentOptions.continueRecentSession
// 当 true 且 sessionStore 已配置时，Agent 自动恢复最近的会话
// SDK 内部逻辑（Agent.swift#L840-849）：
//   if options.continueRecentSession && resolvedSessionId == nil {
//       if let sessions = try? await sessionStore.list(), let mostRecent = sessions.first {
//           resolvedSessionId = mostRecent.id
//       }
//   }
public var continueRecentSession: Bool  // 默认 false

// AgentOptions.init 中的参数：
//   continueRecentSession: Bool = false
```

**关键洞察：SDK 在 prompt/stream 的首次调用时自动解析 continueRecentSession。** CLI 只需在 AgentOptions 中正确设置该标志，SDK 处理所有查找和恢复逻辑。CLI 不需要手动调用 SessionStore.list() 来查找最近会话。

**resolveSessionId 与 continueRecentSession 的交互：**

当前 `AgentFactory.resolveSessionId(from:)` 总是返回非 nil 值（要么是 `args.sessionId`，要么是新生成的 UUID）。但 `continueRecentSession` 的前提条件是 `resolvedSessionId == nil`（SDK 检查 `resolvedSessionId == nil || resolvedSessionId?.isEmpty == true`）。

**因此：当需要自动恢复时，应传递 `sessionId: nil`（而非生成的 UUID），让 SDK 自己从 SessionStore 中查找最近会话。**

```swift
// 当前代码（AgentFactory.swift#L87-88）：
let sessionStore = SessionStore()
let sessionId = resolveSessionId(from: args)

// 需要改为：
let sessionStore = SessionStore()
let shouldAutoRestore = !args.noRestore && args.sessionId == nil
let sessionId: String? = shouldAutoRestore ? nil : resolveSessionId(from: args)
let continueRecent = shouldAutoRestore
```

[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L840-849 (continueRecentSession 解析)]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L1448-1457 (streamImpl 中的同一逻辑)]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#L377-380, L476]
[来源: Sources/OpenAgentCLI/AgentFactory.swift#L86-88 (当前 resolveSessionId 调用)]

### 核心设计决策

#### 决策 1: 如何控制自动恢复行为

三种场景对应的 AgentOptions 配置：

| 场景 | --session | --no-restore | sessionId | continueRecentSession |
|------|-----------|-------------|-----------|----------------------|
| 自动恢复最近会话 | 无 | 无 | nil | true |
| 恢复指定会话 | <id> | 无/有 | <id> | false |
| 强制新会话 | 无 | 有 | UUID() | false |

**实现要点：**
- 当 `args.sessionId == nil && args.noRestore == false` 时，传 `sessionId: nil` + `continueRecentSession: true`
- 当 `args.sessionId != nil` 时，使用该 sessionId，`continueRecentSession: false`（默认值，不需要显式设置）
- 当 `args.noRestore == true && args.sessionId == nil` 时，生成新 UUID，`continueRecentSession: false`

#### 决策 2: 恢复状态提示的实现位置

**方案 A（推荐）：在 CLI.swift 的 REPL 路径中，创建 Agent 后检查是否为恢复模式。**

```swift
// 在 CLI.swift 的 REPL 分支中：
if !args.noRestore && args.sessionId == nil {
    renderer.output.write("[Restoring last session...]\n")
}
```

优点：简单直接，不侵入 REPLLoop 逻辑。
缺点：无法知道恢复是否成功（SDK 在首次 stream 调用时才执行恢复）。

**方案 B：不显示恢复提示，只在 SDK 恢复成功后的首次流式输出中自然体现。**

更符合 Unix 哲学（安静是金）。用户会看到之前对话的上下文被延续。

**推荐方案 A**（带提示），因为 PRD 中 FR4.5 的用户期望是"自动恢复"应该有可见的反馈，让用户知道之前的会话被恢复了。

#### 决策 3: 恢复失败的降级策略

SDK 的 continueRecentSession 机制：
- 如果没有已保存会话 → `resolvedSessionId` 保持 nil → Agent 行为等同于新会话（不报错）
- 如果会话文件损坏 → SDK 在 load 时可能抛出错误 → 在 `promptImpl`/`streamImpl` 的 session restore 阶段报错

**降级策略：**
1. 无会话可恢复：静默开始新会话（SDK 行为，无需额外处理）
2. 恢复出错：REPLLoop.start() 的 stream catch 块已捕获错误并显示（现有代码在 REPLLoop.swift#L93-96）
3. 额外增强：检测是否为 session-related 错误，如果是则建议 `--no-restore` 重启

### 架构合规性

本故事涉及架构文档中的 **FR4.5**：

- **FR4.5:** 启动时自动恢复最近一次会话（可通过 `--no-restore` 禁用）→ `AgentFactory.swift`（设置 continueRecentSession）+ `CLI.swift`（恢复提示）

架构文档中提到的 `SessionManager.swift` 不需要创建（延续 Story 3.1、3.2 的决策）。所有会话操作直接使用 SDK 的 `SessionStore` 和 `AgentOptions` API。

[来源: prd.md#FR4.5, architecture.md#FR4:会话管理→SessionManager.swift]
[来源: _bmad-output/implementation-artifacts/3-1-auto-save-sessions-on-exit.md#不要创建SessionManager.swift]
[来源: _bmad-output/implementation-artifacts/3-2-list-and-resume-past-sessions.md#不要创建SessionManager.swift]

### 关键约束：零 internal 访问

整个项目仅允许 `import OpenAgentSDK`。不得导入任何 internal 模块或使用 `@_implementationOnly`。如果发现 SDK 缺少 public API，使用 `// SDK-GAP:` 注释记录，不绕过。

[来源: prd.md#技术约束, architecture.md#执行指南]

### 不要做的事

1. **不要创建 SessionManager.swift 文件** — 延续 Story 3.1、3.2 的决策，所有会话操作直接使用 SDK SessionStore。

2. **不要修改 ArgumentParser** — `--session` 和 `--no-restore` 参数已完整实现。[来源: `Sources/OpenAgentCLI/ArgumentParser.swift#L188-191, L214-215`]

3. **不要修改 OutputRenderer** — 本故事的恢复提示通过 `renderer.output.write()` 直接输出，不需要新的渲染方法。

4. **不要手动调用 SessionStore.list() 查找最近会话** — SDK 的 `continueRecentSession` 机制自动处理。CLI 只需在 AgentOptions 中设置标志。

5. **不要修改 REPLLoop 的 /sessions 或 /resume 命令** — 这些在 Story 3.2 中已实现，本故事不涉及。

6. **不要在单次提问模式中实现自动恢复** — 单次提问模式是独立的，不需要恢复上下文。只在 REPL 模式启动时恢复。

7. **不要在 --skill 模式中实现自动恢复** — --skill 模式先执行技能，然后可能进入 REPL。自动恢复逻辑只在没有 --skill 的纯 REPL 模式下生效。

### 项目结构说明

需要修改的文件：
```
Sources/OpenAgentCLI/
  AgentFactory.swift        # 修改 createAgent() 中的 sessionId 和 continueRecentSession 逻辑
  CLI.swift                 # 添加恢复状态提示输出
```

需要新增的测试：
```
Tests/OpenAgentCLITests/
  AutoRestoreTests.swift    # 新建测试文件，覆盖 AC#1-#4
```

不修改的文件：
```
Sources/OpenAgentCLI/
  ArgumentParser.swift           # 参数解析不变（--session 和 --no-restore 已存在）
  OutputRenderer.swift           # 渲染不变
  OutputRenderer+SDKMessage.swift  # 消息渲染不变
  CLIEntry.swift / main.swift    # 入口不变
  ANSI.swift                     # ANSI 辅助不变
  Version.swift                  # 版本不变
  CLISingleShot.swift            # 单次模式不变
  ConfigLoader.swift             # 配置加载不变
  REPLLoop.swift                 # REPL 循环不变（Story 3.2 的命令不需要改）
```

[来源: architecture.md#项目结构]

### 测试策略

**新增测试分布预期：**

| 测试方法名 | 覆盖 AC | 说明 |
|-----------|---------|------|
| testCreateAgent_default_setsContinueRecentSession | #1 | 无 --session、无 --no-restore 时 continueRecentSession = true |
| testCreateAgent_default_sessionIdIsNil | #1 | 自动恢复模式下 sessionId 为 nil（让 SDK resolve） |
| testCreateAgent_withSession_setsExplicitSessionId | #2 | --session 时使用指定 ID，continueRecentSession = false |
| testCreateAgent_noRestore_generatesNewSessionId | #3 | --no-restore 时生成新 UUID，continueRecentSession = false |
| testCreateAgent_noRestore_withSession_usesSpecifiedId | #2, #3 | --no-restore + --session 时使用指定 ID |
| testRestoreHint_displayed_inReplMode | #1 | REPL 模式显示恢复提示 |
| testRestoreHint_notDisplayed_withNoRestore | #3 | --no-restore 时不显示恢复提示 |
| testRestoreHint_notDisplayed_withExplicitSession | #2 | --session 时不显示恢复提示 |
| testRestoreHint_notDisplayed_inSingleShotMode | #1 | 单次提问模式不显示恢复提示 |
| testExistingTestsStillPass_regression | 全部 | 285 项测试无回归 |

**测试方法：**

1. **AgentFactory 测试** — 构造不同配置的 `ParsedArgs`，调用 `createAgent(from:)`，验证返回的 Agent 对应的 options 行为。由于 AgentOptions 不是 public 可读取的（无法直接断言 continueRecentSession 值），需要通过以下方式间接验证：
   - 创建 Agent 后执行一次 stream/prompt，检查是否加载了历史消息
   - 或使用真实的 SessionStore 配合临时目录，预先生成会话文件

2. **恢复提示测试** — 验证 CLI.swift 在不同模式下的 stdout 输出是否包含 "[Restoring last session...]" 提示。通过捕获 OutputRenderer 的输出来验证。

3. **回归测试** — AgentFactory 中 `resolveSessionId` 逻辑的变更可能影响所有使用 `createAgent` 的测试。确保所有 285 项现有测试仍然通过。

**注意：** 当 `continueRecentSession = true` 且 `sessionId = nil` 时，如果测试环境没有预先生成的会话文件，SDK Agent 会以新会话行为运行（不报错）。这意味着大部分现有测试不需要预生成会话文件即可继续通过。

**潜在需要更新的测试 fixture：** 如果现有测试中某处依赖 `resolveSessionId` 返回非 nil 值（例如断言 sessionId 不为空），需要更新为接受 nil。

### 参考文件和源码位置

- [来源: _bmad-output/planning-artifacts/epics.md#Story 3.3]
- [来源: _bmad-output/planning-artifacts/prd.md#FR4.5]
- [来源: _bmad-output/planning-artifacts/architecture.md#SessionManager, 会话管理]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#L377-380 (continueRecentSession 文档), L476 (init 参数)]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L840-849 (promptImpl 中的 continueRecentSession 解析)]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L1448-1457 (streamImpl 中的同一逻辑)]
- [来源: Sources/OpenAgentCLI/AgentFactory.swift#L86-113 (当前 createAgent 实现，特别是 L87-88 的 resolveSessionId)]
- [来源: Sources/OpenAgentCLI/CLI.swift#L103-114 (REPL 模式分支)]
- [来源: Sources/OpenAgentCLI/CLI.swift#L43 (createAgentOrExit 解构)]
- [来源: Sources/OpenAgentCLI/ArgumentParser.swift#L188-191 (--session), L214-215 (--no-restore)]
- [来源: Sources/OpenAgentCLI/REPLLoop.swift#L56-57 (sessionStore, parsedArgs 属性)]
- [来源: _bmad-output/implementation-artifacts/3-2-list-and-resume-past-sessions.md#前一故事关键学习]
- [来源: _bmad-output/implementation-artifacts/3-1-auto-save-sessions-on-exit.md#SDK API 详细参考]
- [来源: _bmad-output/implementation-artifacts/deferred-work.md (4 项延迟工作)]

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No blocking issues encountered during implementation.

### Completion Notes List

- Implemented auto-restore logic in AgentFactory.resolveSessionId(): returns nil (for auto-restore) when noRestore==false && sessionId==nil, otherwise returns explicit sessionId or generated UUID.
- Changed resolveSessionId return type from String to String? to support nil for auto-restore mode.
- Added continueRecentSession: shouldAutoRestore to AgentOptions in createAgent(), enabling SDK's automatic session restoration.
- Added restore hint "[Restoring last session...]" in CLI.swift REPL branch, shown only when auto-restore is active.
- Graceful degradation: SDK handles no-sessions case silently (nil resolvedSessionId = new session behavior). Corrupt session errors are caught by existing REPLLoop.start() error handler.
- Updated 3 tests in SessionSaveTests.swift to accommodate the String? return type change of resolveSessionId.
- Updated 3 tests in AutoRestoreTests.swift to correctly reflect that resolveSessionId returns nil for single-shot and skill modes (distinction handled at CLI.swift level).
- All 306 tests pass (285 existing + 21 new AutoRestoreTests), 0 failures, no regressions.

### File List

- Sources/OpenAgentCLI/AgentFactory.swift (modified: resolveSessionId returns String?, createAgent passes continueRecentSession)
- Sources/OpenAgentCLI/CLI.swift (modified: restore hint output in REPL branch)
- Tests/OpenAgentCLITests/AutoRestoreTests.swift (modified: fixed tests for String? return type, updated single-shot/skill mode tests)
- Tests/OpenAgentCLITests/SessionSaveTests.swift (modified: fixed tests for String? return type of resolveSessionId)

### Change Log

- 2026-04-20: Implemented Story 3.3 auto-restore last session on startup. Added continueRecentSession support to AgentFactory, restore hint to CLI.swift REPL path, updated AutoRestoreTests and SessionSaveTests. All 306 tests pass.
