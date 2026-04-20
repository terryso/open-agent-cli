# Story 3.1: 退出时自动保存会话

Status: done

## 故事

作为一个用户，
我想要在退出 CLI 时自动保存对话，
以便我稍后可以接着上次的进度继续。

## 验收标准

1. **假设** CLI 在 REPL 模式下运行，且会话持久化已启用（默认）
   **当** 我输入 `/exit` 或 Ctrl+D
   **那么** 当前会话通过 SDK 的 SessionStore 保存

2. **假设** 会话保存失败（如磁盘已满）
   **当** 保存操作出错
   **那么** 显示警告但 CLI 仍然正常退出

3. **假设** CLI 以 `--no-restore` 启动
   **当** 配置会话时
   **那么** 自动恢复被禁用，但自动保存仍然有效

## 任务 / 子任务

- [x] 任务 1: 增强 AgentFactory 以配置 SessionStore 和 sessionId (AC: #1, #3)
  - [x] 在 `createAgent(from:)` 中创建 `SessionStore()` 实例
  - [x] 为每个新会话生成唯一 `sessionId`（UUID）
  - [x] 将 `sessionStore` 和 `sessionId` 传入 `AgentOptions`
  - [x] 设置 `persistSession = true`（默认值，确保自动保存）
  - [x] 处理 `--no-restore` 标志：不影响保存行为，只影响恢复（Story 3.3 的范围）

- [x] 任务 2: 确保 CLI 退出路径正确调用 agent.close() (AC: #1)
  - [x] 验证 REPL 模式退出路径（`/exit`、`/quit`、Ctrl+D → EOF）调用 `agent.close()`
  - [x] 验证单次提问模式退出路径调用 `agent.close()`
  - [x] 验证 `--skill` 模式退出路径调用 `agent.close()`
  - [x] 确认 SDK 的 `agent.close()` 触发 SessionStore 自动保存

- [x] 任务 3: 处理会话保存失败的优雅降级 (AC: #2)
  - [x] 在 CLI 层捕获 `agent.close()` 抛出的异常
  - [x] 显示用户友好的警告信息（如 "Warning: Failed to save session: <reason>"）
  - [x] 确保 CLI 仍然正常退出（退出码 0），不因保存失败而崩溃

- [x] 任务 4: 编写 AgentFactory 会话配置测试 (AC: #1, #3)
  - [x] 测试 `createAgent` 在默认配置下 Agent 创建成功（SessionStore 已注入）
  - [x] 测试 `computeToolPool` 在有 session 配置时行为不变（回归测试）
  - [x] 测试 `--no-restore` 不影响 Agent 创建（persistSession 仍为 true）

- [x] 任务 5: 编写 CLI 退出路径集成测试 (AC: #1, #2)
  - [x] 测试 REPL `/exit` 路径：验证 `agent.close()` 被调用
  - [x] 测试单次提问路径：验证 `agent.close()` 在输出后被调用
  - [x] 测试保存失败时显示警告但不崩溃

- [x] 任务 6: 回归测试验证 (AC: 全部)
  - [x] 确保 248 项现有测试全部通过
  - [x] 确保不破坏 Story 1.x、2.x 的任何功能

## 开发备注

### 前一故事的关键学习

Story 2.3（技能加载与调用）已建立以下模式：

1. **248 项测试全部通过** — 分布于 ArgumentParserTests、AgentFactoryTests、ConfigLoaderTests、OutputRendererTests、REPLLoopTests、CLISingleShotTests、SmokePerformanceTests、ToolLoadingTests、SkillLoadingTests。[来源: 最新 `swift test` 执行结果]

2. **AgentFactory 是单一桥梁** — `AgentFactory.createAgent(from:)` 是 `ParsedArgs` 和 SDK `Agent` 之间的唯一转换点。所有新配置字段必须在此添加。[来源: `Sources/OpenAgentCLI/AgentFactory.swift`]

3. **CLI.swift 是顶层调度器** — 负责路由到 REPL 或单次模式，不含业务逻辑。所有退出路径在此汇聚。[来源: `Sources/OpenAgentCLI/CLI.swift`]

4. **REPLLoop 通过 protocol 实现可测试性** — `InputReading` protocol 允许注入 mock 输入。[来源: `Sources/OpenAgentCLI/REPLLoop.swift`]

5. **deferred-work.md 已有 4 项** — 包括 force-unwrap 模式、误导性错误消息、AgentOptions 未完整填充、缺失测试路径。不要在此故事中修复这些问题，除非直接相关。[来源: `_bmad-output/implementation-artifacts/deferred-work.md`]

### SDK API 详细参考

本故事使用以下 SDK public API：

```swift
// SessionStore — 基于 actor 的线程安全会话持久化
// 默认路径: ~/.open-agent-sdk/sessions/{sessionId}/transcript.json
public actor SessionStore {
    public init(sessionsDir: String? = nil)

    // 保存会话（包含消息和元数据）
    public func save(
        sessionId: String,
        messages: [[String: Any]],
        metadata: PartialSessionMetadata
    ) throws

    // 加载会话
    public func load(sessionId: String, limit: Int? = nil, offset: Int? = nil) throws -> SessionData?

    // 列出所有会话（按 updatedAt 降序）
    public func list(limit: Int? = nil, includeWorktrees: Bool = false) throws -> [SessionMetadata]
}

// AgentOptions 中的会话相关字段
public struct AgentOptions {
    public var sessionStore: SessionStore?       // 设置后 Agent 自动保存/恢复
    public var sessionId: String?                // 会话唯一标识符
    public var persistSession: Bool              // 默认 true，控制自动保存
    public var continueRecentSession: Bool       // 默认 false，恢复最近会话
}

// Agent.close() — 关闭 Agent 时自动保存会话
// 当 sessionStore != nil && sessionId != nil && persistSession == true 时，
// Agent 在 close() 时自动将对话历史保存到 SessionStore。
// 同时，Agent 在每次 prompt/stream 完成后也会自动保存。
public func close() async throws
```

[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Stores/SessionStore.swift]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#L284-L295, L377-L394]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L449-L480 (close 方法)]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L1268-L1279 (prompt 后自动保存)]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L2091-L2097 (stream 后自动保存)]

### 关键洞察：SDK 已实现会话自动保存逻辑

SDK 的 Agent 已经内置了完整的会话自动保存机制：

1. **每次 prompt/stream 完成后自动保存** — Agent 在 `promptImpl` 和 `streamImpl` 完成时，如果 `sessionStore != nil && sessionId != nil && persistSession == true`，会自动将对话历史保存到 SessionStore。[来源: Agent.swift#L1268-L1279, #L2091-L2097]

2. **close() 时的保存是兜底** — `agent.close()` 只在没有先前保存的情况下写入会话标记（空消息）。实际对话历史已在每次查询完成后保存。[来源: Agent.swift#L463-L480]

3. **错误路径也会保存** — 即使查询出错，Agent 也会保存已有的消息。[来源: Agent.swift#L1045-L1053]

**因此 CLI 只需在 `AgentOptions` 中正确设置 `sessionStore` 和 `sessionId`，SDK 会自动处理所有保存逻辑。** CLI 不需要手动调用 SessionStore.save()。

### 实现策略

#### 任务 1: AgentFactory 增强

**关键决策：在 AgentOptions 组装时注入 SessionStore 和 sessionId。**

当前 `AgentFactory.createAgent(from:)` 未设置 `sessionStore`、`sessionId`、`persistSession`。需要添加：

```swift
// 在 AgentFactory.createAgent(from:) 中：
let sessionStore = SessionStore()  // 使用默认路径 ~/.open-agent-sdk/sessions/
let sessionId = args.sessionId ?? UUID().uuidString

let options = AgentOptions(
    // ... 现有参数 ...
    sessionStore: sessionStore,
    sessionId: sessionId,
    persistSession: true,  // 始终启用保存
    continueRecentSession: false  // Story 3.3 的范围
)
```

**注意：** 如果 `args.sessionId` 已提供（通过 `--session <id>`），使用该 ID 恢复已有会话。否则生成新的 UUID。

**`--no-restore` 不影响此故事：** 该标志只控制启动时是否恢复最近会话（Story 3.3），不影响退出时的保存行为。`persistSession` 始终为 `true`。

**同时需要返回 sessionId** — CLI 可能需要知道当前的 sessionId（用于日志或调试），但 SDK Agent 内部会自动使用它。方案：让 `createAgent` 返回包含 Agent 和 sessionId 的元组，或通过其他方式暴露。

**推荐方案：新增 `AgentFactory.resolveSessionId(from:)` 方法**，在创建 Agent 之前确定 sessionId：

```swift
/// 解析会话 ID：使用 --session 参数或生成新的 UUID。
static func resolveSessionId(from args: ParsedArgs) -> String {
    return args.sessionId ?? UUID().uuidString
}
```

#### 任务 2: 验证退出路径

当前 CLI.swift 中已有的 `agent.close()` 调用点：

1. **REPL 模式**（正常路径）: `try? await agent.close()` — 在 `repl.start()` 之后。[CLI.swift:113]
2. **单次提问模式**: `try? await agent.close()` — 在结果输出之后、exit 之前。[CLI.swift:101]
3. **`--skill` 无 prompt 路径**: `try? await agent.close()` — 在 `repl.start()` 之后。[CLI.swift:74]

**所有三个退出路径都已调用 `agent.close()`！** 这意味着 SDK 的自动保存逻辑已在现有代码路径中被触发。

**但有一个问题：** 当前使用 `try? await agent.close()`，这会静默吞掉保存错误。需要改为显式处理：

```swift
do {
    try await agent.close()
} catch {
    let warning = "Warning: Failed to save session: \(error.localizedDescription)"
    FileHandle.standardError.write((warning + "\n").data(using: .utf8)!)
}
```

#### 任务 3: 保存失败的优雅降级

SDK 的 `SessionStore.save()` 可能因以下原因失败：
- 磁盘空间不足
- 权限不足（无法创建 ~/.open-agent-sdk/sessions/ 目录）
- JSON 序列化失败（极端情况）

SDK 在 `close()` 中不会因保存失败而抛出致命错误。但为了安全，CLI 应在 `agent.close()` 的 catch 块中处理：
- 输出警告到 stderr
- 继续正常退出（退出码 0）
- 不中断退出流程

### 架构合规性

本故事涉及架构文档中的 **FR4.1**：

- **FR4.1:** 默认启用会话持久化：每次对话自动保存 → `SessionManager.swift`（架构文档中的命名）

**注意：** 架构文档提到了 `SessionManager.swift`，但本实现不需要创建新文件。会话管理完全委托给 SDK 的 `SessionStore` 和 `AgentOptions`。CLI 只需在 `AgentFactory` 中注入配置即可。不需要独立的 `SessionManager.swift`。

[来源: prd.md#FR4.1, architecture.md#FR4:会话管理→SessionManager.swift]

**验证：** 架构文档中说"SessionManager — 通过 SDK SessionStore 自动保存/恢复"，而我们的实现方式是通过 AgentOptions 注入 SessionStore，效果一致。这是最简单、最正确的方案，因为 SDK Agent 已经内置了完整的自动保存逻辑。

### 关键约束：零 internal 访问

整个项目仅允许 `import OpenAgentSDK`。不得导入任何 internal 模块或使用 `@_implementationOnly`。如果发现 SDK 缺少 public API，使用 `// SDK-GAP:` 注释记录，不绕过。

[来源: prd.md#技术约束, architecture.md#执行指南]

### 不要做的事

1. **不要创建 SessionManager.swift 文件** — 架构文档中提到的 `SessionManager.swift` 不需要创建。SDK 的 Agent 已内置完整的自动保存逻辑（在 prompt/stream 完成后 + close() 时）。CLI 只需在 AgentOptions 中注入 SessionStore。

2. **不要手动调用 SessionStore.save()** — SDK Agent 在每次查询完成和 close() 时自动保存。CLI 不需要直接操作 SessionStore。

3. **不要修改 ArgumentParser** — `--session` 和 `--no-restore` 参数已完整实现。[来源: `Sources/OpenAgentCLI/ArgumentParser.swift#L188-191, L214-215`]

4. **不要修改 OutputRenderer** — 本故事不涉及渲染逻辑变更。

5. **不要实现会话恢复逻辑** — `continueRecentSession` 和 `--no-restore` 的处理属于 Story 3.3（启动时自动恢复上次会话）。

6. **不要实现 /sessions 和 /resume 命令** — 这些属于 Story 3.2（列出和恢复历史会话）。

7. **不要修改 REPLLoop** — REPL 的退出路径（`/exit`、`/quit`）返回 `true` 后由 CLI.swift 调用 `agent.close()`，无需在 REPLLoop 中添加保存逻辑。

8. **不要处理 SIGTERM 信号保存** — Story 5.3（优雅中断处理）的范围。当前只需确保正常退出路径保存。

### 项目结构说明

需要修改的文件：
```
Sources/OpenAgentCLI/
  AgentFactory.swift        # 修改 createAgent() 注入 SessionStore 和 sessionId
  CLI.swift                 # 修改 agent.close() 调用方式（try? → 显式错误处理）
```

需要新增的测试：
```
Tests/OpenAgentCLITests/
  SessionSaveTests.swift    # 新建测试文件，覆盖 AC#1-#3
```

不修改的文件：
```
Sources/OpenAgentCLI/
  ArgumentParser.swift       # 参数解析不变（--session 和 --no-restore 已存在）
  OutputRenderer.swift       # 渲染不变
  OutputRenderer+SDKMessage.swift  # 消息渲染不变
  CLIEntry.swift / main.swift  # 入口不变
  ANSI.swift                 # ANSI 辅助不变
  Version.swift              # 版本不变
  CLISingleShot.swift        # 单次模式不变
  ConfigLoader.swift         # 配置加载不变
  REPLLoop.swift             # REPL 循环不变
```

[来源: architecture.md#项目结构]

### 测试策略

**新增测试分布预期：**

| 测试方法名 | 覆盖 AC | 说明 |
|-----------|---------|------|
| testCreateAgent_injectsSessionStore | #1 | AgentOptions 包含 SessionStore 和 sessionId |
| testCreateAgent_generatesUUID_whenNoSessionId | #1 | 无 --session 时自动生成 UUID |
| testCreateAgent_usesProvidedSessionId | #1 | 有 --session 时使用提供的 ID |
| testCreateAgent_persistSessionIsTrue | #1, #3 | persistSession 始终为 true |
| testCreateAgent_noRestoreFlag_doesNotAffectSave | #3 | --no-restore 不影响 persistSession |
| testCLICloseHandlesSaveError_graceful | #2 | close() 失败时显示警告但不崩溃 |
| testExistingTestsStillPass_regression | 全部 | 248 项测试无回归 |

**测试方法：**

1. **AgentFactory 测试** — 构造 `ParsedArgs`，调用 `createAgent(from:)`，验证返回的 Agent 的 options 包含正确的 session 配置。由于 Agent 的 options 不是 public 属性，需要通过行为验证（如使用临时 SessionStore 目录检查文件是否被创建）。

2. **CLI 退出路径测试** — 需要 mock Agent 的 close 方法来模拟保存失败。可以通过创建临时目录的 SessionStore 并设置只读权限来触发真实错误。

3. **回归测试** — 确保所有 248 项现有测试仍然通过，特别是 AgentFactoryTests 中构造 ParsedArgs 的测试 fixture 需要检查是否需要更新（因为 sessionId 可能从 nil 变为非 nil）。

**重要：更新测试 fixture** — 现有 AgentFactoryTests、ToolLoadingTests、SkillLoadingTests 等测试中构造 ParsedArgs 时 `sessionId: nil`。改为非 nil 后，这些测试 fixture 可能需要更新为 `sessionId: UUID().uuidString` 或某个固定值。

### 参考资料

- [来源: _bmad-output/planning-artifacts/epics.md#Story 3.1]
- [来源: _bmad-output/planning-artifacts/prd.md#FR4.1]
- [来源: _bmad-output/planning-artifacts/architecture.md#SessionManager, 会话存储]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Stores/SessionStore.swift#init, save, load, list]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/SessionTypes.swift#SessionMetadata, PartialSessionMetadata]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#L284-L295 (sessionStore, sessionId)]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#L391-L394 (persistSession)]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L449-L480 (close 方法中的保存逻辑)]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L1268-L1279 (prompt 后自动保存)]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L2091-L2097 (stream 后自动保存)]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L1045-L1053 (错误路径保存)]
- [来源: _bmad-output/implementation-artifacts/2-3-skills-loading-and-invocation.md#前一故事关键学习]
- [来源: Sources/OpenAgentCLI/AgentFactory.swift (当前 createAgent 实现)]
- [来源: Sources/OpenAgentCLI/CLI.swift (当前 CLI 调度和退出路径)]
- [来源: Sources/OpenAgentCLI/ArgumentParser.swift#L188-191 (--session), L214-215 (--no-restore)]

## 开发代理记录

### 使用的代理模型

Claude Opus 4.7 (via GLM-5.1)

### 调试日志引用

无调试问题。

### 完成备注列表

- Task 1: Added `SessionStore()` instantiation and `resolveSessionId(from:)` helper to AgentFactory. SessionStore uses default path `~/.open-agent-sdk/sessions/`. sessionId uses `--session` arg if provided, otherwise generates UUID. `persistSession` always set to `true`. `--no-restore` has no effect on save behavior.
- Task 2: All three exit paths (REPL mode, single-shot mode, --skill mode) already called `agent.close()`. Replaced `try? await agent.close()` with `await closeAgentSafely(agent)` in all three locations.
- Task 3: Added `closeAgentSafely(_:)` async method to CLI that wraps `agent.close()` in do/catch, printing warning to stderr on failure. CLI always exits normally regardless of save failures.
- Task 4 & 5: All 23 ATDD tests in SessionSaveTests.swift pass (pre-existing test file from red phase).
- Task 6: All 271 tests pass (248 existing + 23 new SessionSaveTests). Zero regressions. Zero failures.

### 文件列表

#### Modified files:
- Sources/OpenAgentCLI/AgentFactory.swift — Added SessionStore injection, sessionId resolution, resolveSessionId helper, persistSession=true to AgentOptions
- Sources/OpenAgentCLI/CLI.swift — Replaced try? await agent.close() with await closeAgentSafely(agent) in all exit paths; added closeAgentSafely method for graceful error handling

#### Existing test file (pre-created in ATDD red phase):
- Tests/OpenAgentCLITests/SessionSaveTests.swift — 23 tests covering AC#1-#3 (all passing after implementation)

### Review Findings

- [x] [Review][Patch] Dead code: unused tempDir variables in two test methods [SessionSaveTests.swift:68-69, 122-123] — fixed: removed dead code and misleading comments
- [x] [Review][Defer] Force-unwrap on .data(using: .utf8)! in closeAgentSafely error path [CLI.swift:138] — deferred, pre-existing pattern (already in deferred-work.md)
- [x] [Review][Defer] testCreateAgent_sessionSavedToDisk_afterClose doesn't verify actual disk write — deferred, SDK AgentOptions doesn't expose custom sessionsDir; test verifies close() succeeds without error
