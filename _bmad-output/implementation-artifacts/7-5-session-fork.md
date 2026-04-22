# Story 7.5: 会话分叉

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为一个高级用户，
我想要从当前节点分叉对话，
以便我可以探索替代方案而不丢失原始上下文。

## Acceptance Criteria

1. **假设** 我处于带有对话历史的 REPL 会话中
   **当** 我输入 `/fork`
   **那么** 从当前对话状态创建一个新的分支会话

2. **假设** 分叉完成
   **当** 我继续对话
   **那么** 新会话从此处开始拥有独立的后续历史

3. **假设** 分叉成功完成
   **当** 显示确认信息
   **那么** 显示新会话的短 ID 和 "Session forked" 提示

4. **假设** 当前没有会话存储可用（SessionStore 为 nil）
   **当** 我输入 `/fork`
   **那么** 显示错误信息 "No session storage available."

5. **假设** 当前没有活跃会话（sessionId 为 nil）
   **当** 我输入 `/fork`
   **那么** 显示错误信息 "No active session to fork."

6. **假设** 分叉操作失败（如磁盘写入错误）
   **当** SessionStore.fork() 抛出错误
   **那么** 显示错误信息，原始会话不受影响

## Tasks / Subtasks

- [x] Task 1: 在 REPLLoop 中添加 `/fork` 命令处理 (AC: #1, #2, #3, #4, #5, #6)
  - [x] 在 `handleSlashCommand` 的 switch 中添加 `"/fork"` case
  - [x] 实现 `handleFork()` 方法
  - [x] 验证 SessionStore 可用性（AC#4）
  - [x] 验证当前 sessionId 存在（AC#5）
  - [x] 调用 `sessionStore.fork(sourceSessionId:)` 创建分叉
  - [x] 将 agent 切换到新分叉的会话（保持继续对话）
  - [x] 显示确认信息包含新会话短 ID（AC#3）

- [x] Task 2: 更新 `/help` 输出 (AC: #1)
  - [x] 在 `printHelp()` 中添加 `/fork` 命令说明

- [x] Task 3: 添加测试覆盖 (AC: #1-#6)
  - [x] 测试：handleFork 成功时分叉会话并显示确认
  - [x] 测试：SessionStore 为 nil 时显示错误
  - [x] 测试：sessionId 为 nil 时显示错误
  - [x] 测试：fork 抛出错误时显示错误信息
  - [x] 测试：/help 输出包含 /fork 命令

## Dev Notes

### SDK API 分析

本故事使用的 SDK API 均已存在且完整实现：

1. **`SessionStore.fork(sourceSessionId:newSessionId:upToMessageIndex:)`**
   - 位置：`.build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Stores/SessionStore.swift` 第 231 行
   - 参数：
     - `sourceSessionId: String` — 要分叉的源会话 ID
     - `newSessionId: String? = nil` — 可选的新会话 ID，默认自动生成 UUID
     - `upToMessageIndex: Int? = nil` — 可选的消息截断索引，默认复制全部消息
   - 返回：`String?` — 新会话 ID，源不存在时返回 nil
   - 抛出：`SDKError.sessionError` — 当 upToMessageIndex 越界或 newSessionId 无效时

2. **`Agent.getSessionId() -> String?`**
   - 位置：`.build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift` 第 264 行
   - 返回当前 agent 的 session ID，无会话时返回 nil

3. **`AgentOptions.forkSession: Bool`**
   - 位置：`.build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift` 第 385 行
   - 默认 `false`，设为 `true` 时 agent 会在首次查询前自动分叉
   - **注意：** 本故事不使用此选项。`/fork` 是 REPL 命令，需要直接调用 `SessionStore.fork()` + 创建新 agent，而非通过 `AgentOptions.forkSession`

### 当前实现分析

#### REPLLoop.swift — 需要修改

**`handleSlashCommand` 方法（第 176 行）：** 需要添加 `"/fork"` case。

**新增 `handleFork()` 方法：** 核心逻辑如下：

```swift
// 伪代码
private func handleFork() async {
    // 1. 检查 SessionStore 可用性
    guard let store = sessionStore else {
        renderer.output.write("No session storage available.\n")
        return
    }

    // 2. 获取当前 session ID
    guard let currentSessionId = agentHolder.agent.getSessionId() else {
        renderer.output.write("No active session to fork.\n")
        return
    }

    // 3. 调用 SessionStore.fork()
    let forkedId: String
    do {
        guard let id = try store.fork(sourceSessionId: currentSessionId) else {
            renderer.output.write("Error: Source session not found.\n")
            return
        }
        forkedId = id
    } catch {
        renderer.output.write("Error forking session: \(error.localizedDescription)\n")
        return
    }

    // 4. 创建新 Agent 使用 forkedId 作为 sessionId
    //    复用 /resume 的模式：从 parsedArgs 创建新 Agent
    guard let args = parsedArgs else {
        renderer.output.write("Cannot fork: configuration not available.\n")
        return
    }

    let forkArgs = ParsedArgs(/* 同 resumeArgs 模式，但 sessionId = forkedId */)

    do {
        let (newAgent, _) = try await AgentFactory.createAgent(from: forkArgs)
        // 保存当前 agent 会话
        do {
            try await agentHolder.agent.close()
        } catch {
            renderer.output.write("Warning: failed to save current session (\(error.localizedDescription)).\n")
        }
        // 切换到分叉的会话
        agentHolder.agent = newAgent
        let shortId = String(forkedId.prefix(8))
        renderer.output.write("Session forked. New session: \(shortId)...\n")
    } catch {
        renderer.output.write("Error creating forked session: \(error.localizedDescription)\n")
    }
}
```

**`printHelp()` 方法（第 209 行）：** 添加 `/fork` 到帮助列表。

#### 不需要修改的文件

- **AgentFactory.swift** — 无需修改。createAgent 已支持 sessionId 参数。
- **ArgumentParser.swift** — 无需修改。没有新的 CLI 标志。
- **CLI.swift** — 无需修改。分叉是 REPL 内部操作。
- **ConfigLoader.swift** — 无需修改。
- **OutputRenderer.swift** — 无需修改。

### /fork 与 /resume 的实现模式对比

`/fork` 的实现应复用 `/resume`（第 364-452 行）已建立的模式：

| 步骤 | /resume | /fork |
|------|---------|-------|
| 1. 验证 SessionStore | `guard let store = sessionStore` | 相同 |
| 2. 获取目标 session ID | 从用户输入解析 | 调用 `store.fork()` 生成 |
| 3. 构建新 ParsedArgs | `sessionId = 目标ID` | `sessionId = forkedId` |
| 4. 创建新 Agent | `AgentFactory.createAgent(from: resumeArgs)` | 相同 |
| 5. 关闭旧 Agent | `agentHolder.agent.close()` | 相同 |
| 6. 替换 Agent | `agentHolder.agent = newAgent` | 相同 |
| 7. 显示确认 | "Resumed session XXX..." | "Session forked. New session: XXX..." |

**关键区别：** /fork 需要在创建新 Agent 之前调用 `store.fork()` 来生成新会话，而 /resume 直接使用用户提供的已有 session ID。

### CostTracker 在 /fork 后的行为

分叉后 CostTracker 不会重置。这是合理的：
- 分叉保留原始对话历史，用户可能希望看到累计成本
- 如果用户需要重置成本，可以使用 `/clear` 命令

### 关键约束

1. **零 internal 访问** — 仅使用 `import OpenAgentSDK`
2. **零第三方依赖** — 不引入外部库
3. **不修改 SDK** — 如遇 SDK 限制，记录为 `// SDK-GAP:` 注释
4. **SessionStore.fork() 是同步方法** — 注意它是 `throws` 而非 `async throws`，不需要 await
5. **分叉后原会话不受影响** — 旧 Agent 被 close()，新 Agent 使用 forkedId
6. **ParsedArgs 必须可用** — 需要 `parsedArgs` 不为 nil 才能创建新 Agent

### 不要做的事

1. **不要使用 AgentOptions.forkSession** — 那个选项是在 Agent 创建时自动分叉，而 `/fork` 是 REPL 运行时操作
2. **不要修改 AgentFactory** — 已有 createAgent 支持 sessionId
3. **不要修改 ArgumentParser** — 没有新 CLI 标志
4. **不要在分叉后重置 CostTracker** — 保持成本累计的连续性
5. **不要为 fork 添加 upToMessageIndex 参数** — AC 不要求消息截断功能，保持 /fork 简单（复制全部消息）

### 前一故事的关键学习

Story 7.4（多提供商支持）完成后的关键信息：

1. **`explicitlySet` 机制已就绪** — 可以精确区分"用户未传此参数"和"用户传了默认值"
2. **ParsedArgs 构造在 /resume 中已有成熟模式** — 直接复用该模式
3. **AgentHolder 模式** — 使用 class 包装 Agent，允许在 struct 的 non-mutating 方法中替换 agent 实例
4. **全量回归测试通过** — 开发完成后需确认所有现有测试仍通过

### 项目结构说明

本故事修改 1 个现有文件，不创建新文件：

```
Sources/OpenAgentCLI/
  REPLLoop.swift            # 修改：添加 /fork 命令处理

Tests/OpenAgentCLITests/
  REPLLoopTests.swift       # 修改：添加 /fork 相关测试
```

### 测试策略

**测试环境：** REPLLoopTests 需要验证 `/fork` 命令。使用 mock InputReading 和 mock OutputRenderer。

**新增测试分布预期：**

| 测试方法名 | 覆盖 AC | 说明 |
|-----------|---------|------|
| testFork_success_displaysConfirmation | #1, #3 | 成功分叉，显示新会话 ID |
| testFork_noSessionStore_showsError | #4 | SessionStore 为 nil 时报错 |
| testFork_noActiveSession_showsError | #5 | sessionId 为 nil 时报错 |
| testFork_forkThrows_showsError | #6 | SessionStore.fork() 抛出错误 |
| testFork_forkReturnsNil_showsError | #1 | 源会话不存在时返回 nil |
| testHelp_includesForkCommand | #1 | /help 输出包含 /fork |

**注意：** 由于 `/fork` 涉及创建真实 Agent（通过 AgentFactory），单元测试需要 mock SessionStore。检查 REPLLoopTests 现有测试模式确定 mock 策略。

### SDK API 参考

本故事使用以下 SDK API：

- `SessionStore.fork(sourceSessionId:newSessionId:upToMessageIndex:) throws -> String?`
  - 分叉会话，返回新会话 ID
  - 源不存在返回 nil
  - upToMessageIndex 越界时抛出 SDKError
- `Agent.getSessionId() -> String?`
  - 返回当前 session ID，无会话时返回 nil
- `AgentOptions.sessionId: String?` — 通过 ParsedArgs 传递
- `AgentFactory.createAgent(from:)` — 复用已有工厂方法

无新 SDK API 需要引入。无 SDK-GAP 预期。

### 架构合规性

本故事涉及架构文档中的 **FR4.4**：

- **FR4.4:** 通过 `/fork` 命令从当前会话分叉 (P2)

**FR 覆盖映射：**
- FR4.4 -> Epic 7, Story 7.5 (本故事)

**架构模式遵循：**
- "薄编排层" — CLI 仅调用 SessionStore.fork() + 创建新 Agent，不实现分叉逻辑
- "SDK 之上的薄 CLI" — 分叉操作由 SDK SessionStore 执行
- "基于协议的分离" — REPLLoop 通过 SessionStore 协议与存储层交互

[Source: epics.md#Story 7.5]
[Source: prd.md#FR4.4]
[Source: architecture.md#SDK 边界 — "CLI 仅在单一点接触 SDK"]

### 延迟工作

- **截断分叉** — SessionStore.fork() 支持 `upToMessageIndex` 参数，可在未来扩展为 `/fork <message-index>` 语法
- **分叉后自动切换提示** — 可添加选项，让用户选择分叉后是否立即切换到新会话还是继续原会话
- **分叉列表** — 在会话元数据中记录分叉来源，支持 `/sessions` 中显示分叉关系

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.5]
- [Source: _bmad-output/planning-artifacts/prd.md#FR4.4]
- [Source: _bmad-output/planning-artifacts/architecture.md#SDK 边界]
- [Source: Sources/OpenAgentCLI/REPLLoop.swift — handleSlashCommand(), handleResume(), printHelp()]
- [Source: Sources/OpenAgentCLI/AgentFactory.swift — createAgent(from:)]
- [Source: .build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Stores/SessionStore.swift — fork()]
- [Source: .build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift — getSessionId()]
- [Source: .build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift — forkSession]
- [Source: _bmad-output/implementation-artifacts/7-4-multi-provider-support.md — 前一故事]

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- Dev Notes 中的伪代码提到 SessionStore.fork() 是同步方法（`throws` 而非 `async throws`），但实际上 SessionStore 是 actor，所以 fork() 需要 `await`。编译时发现此问题并修正。

### Completion Notes List

- Task 1: 在 REPLLoop.handleSlashCommand 中添加 "/fork" case，实现 handleFork() 方法。该方法验证 SessionStore 和 sessionId 可用性，调用 store.fork() 创建分叉会话，创建新 Agent 并切换到分叉会话，显示确认信息。
- Task 2: 在 printHelp() 中添加 "/fork" 命令说明行。
- Task 3: SessionForkTests.swift 中的测试已存在（ATDD 红阶段预写），修复了 testFork_success_displaysConfirmation 测试中使用自定义 tempDir SessionStore 的错误（改为使用默认 SessionStore()，与 AgentFactory 保存位置一致）。
- 所有 572 个测试通过，零回归。
- Dev Notes 中的伪代码有一处小错误：SessionStore 是 actor，fork() 需要 await 而非单纯的 try。

### File List

- Sources/OpenAgentCLI/REPLLoop.swift — 修改：添加 /fork 命令处理和 handleFork() 方法，更新 printHelp()
- Tests/OpenAgentCLITests/SessionForkTests.swift — 修改：修复 testFork_success_displaysConfirmation 测试使用默认 SessionStore

### Change Log

- 2026-04-22: 实现会话分叉功能 (/fork 命令)，覆盖所有 6 个验收标准，7 个测试全部通过，572 个全量测试零回归

### Review Findings

- [x] [Review][Patch] Strengthen weak assertion in testFork_success_displaysConfirmation [Tests/OpenAgentCLITests/SessionForkTests.swift:175-177] -- Fixed: second assertion now verifies "new session" appears in output instead of tautological check
- [x] [Review][Defer] Missing `stdin` and `explicitlySet` in ParsedArgs copy [Sources/OpenAgentCLI/REPLLoop.swift:369-399] -- deferred, pre-existing issue (same in handleResume)
- [x] [Review][Defer] No cleanup of forked session on AgentFactory failure [Sources/OpenAgentCLI/REPLLoop.swift:401-416] -- deferred, acceptable behavior (orphan session is a valid resumable session)
