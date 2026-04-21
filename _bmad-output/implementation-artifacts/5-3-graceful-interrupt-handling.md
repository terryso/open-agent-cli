# Story 5.3: 优雅的中断处理

Status: review

## 故事

作为一个用户，
我想要在 Agent 响应过程中按下 Ctrl+C 中断它而不丢失会话，
以便我可以重定向或停止失控的任务。

## 验收标准

1. **假设** Agent 正在流式传输响应
   **当** 我按下 Ctrl+C
   **那么** 通过 `agent.interrupt()` 中断当前 Agent 操作
   **并且** REPL 提示符 `>` 重新出现

2. **假设** Agent 正在等待权限提示（`canUseTool` 回调中）
   **当** 我按下 Ctrl+C
   **那么** 操作被取消，REPL 继续（提示符重新出现）

3. **假设** 我在 1 秒内按了两次 Ctrl+C
   **当** 处于 REPL 模式
   **那么** CLI 立即退出

4. **假设** 收到 SIGTERM 信号
   **当** CLI 正在运行
   **那么** 会话被保存（通过 `agent.close()`），进程干净退出

## 任务 / 子任务

- [x] 任务 1: 实现 SIGINT/SIGTERM 信号处理器 (AC: #1, #3, #4)
  - [x] 创建 `SignalHandler.swift`，封装 Darwin/Glibc 信号注册
  - [x] 使用 `sigaction` 注册 SIGINT 和 SIGTERM 处理器
  - [x] SIGINT 处理器：记录时间戳，检查双击间隔，设置标志位
  - [x] SIGTERM 处理器：设置退出标志位
  - [x] 提供 `SignalHandler.check() -> SignalEvent` 查询接口

- [x] 任务 2: 集成中断逻辑到 REPLLoop (AC: #1, #2)
  - [x] 在 `REPLLoop` 中持有 Agent 引用（已有 `agentHolder`），用于调用 `agent.interrupt()`
  - [x] 在流消费循环中检测 SIGINT 标志，调用 `agent.interrupt()`
  - [x] 中断后输出 `^C` 标记
  - [x] 继续外层 REPL while 循环，`>` 提示符重新出现

- [x] 任务 3: 实现双击 Ctrl+C 快速退出 (AC: #3)
  - [x] 记录 SIGINT 计数和时间戳
  - [x] 若 2 次 SIGINT 在 check() 调用前累积（或间隔 < 1 秒），返回 .forceExit
  - [x] REPL 循环检测 .forceExit 时 return 退出
  - [x] CLI.run() 中 closeAgentSafely() 保存会话

- [x] 任务 4: 实现 SIGTERM 优雅退出 (AC: #4)
  - [x] SIGTERM 处理器设置 sigtermFlag 标志
  - [x] REPL 循环 preCheck 和 stream 循环中检测 .terminate
  - [x] CLI.run() 中 closeAgentSafely() 保存会话后退出进程

- [x] 任务 5: 处理权限提示中的中断 (AC: #2)
  - [x] 权限提示等待输入时，Ctrl+C 导致 readLine 返回 nil（自然行为）
  - [x] PermissionHandler.promptUser() 返回 `.deny("No input received")`（已有实现）
  - [x] 验证此路径的测试通过（testPermissionPrompt_readLineNil_returnsDeny）

- [x] 任务 6: 集成到 CLI.swift 启动流程 (AC: #1, #3, #4)
  - [x] 在 CLI.run() 中配置加载后注册信号处理器
  - [x] 在退出路径中确保 closeAgentSafely() 被调用（已有）

- [x] 任务 7: 编写测试 (AC: #1, #2, #3, #4)
  - [x] 测试 SIGINT 标志设置后 REPL 循环中断行为
  - [x] 测试双击 Ctrl+C 的快速退出逻辑
  - [x] 测试 SIGTERM 触发优雅退出
  - [x] 测试中断后 REPL 提示符重新出现（不退出）
  - [x] 测试权限提示中的中断处理
  - [x] 回归测试：全部 396 项测试通过（383 原有 + 13 新增）

## 开发备注

### 前一故事的关键学习

Story 5.2（交互式权限提示）完成后的项目状态：

1. **383 项测试全部通过** — 所有现有测试稳定，包括 PermissionHandlerTests（48 项）

2. **PermissionHandler.swift 已增强** — 新增：
   - `RiskLevel` 枚举（`.high`, `.medium`, `.low`）
   - `PermissionState` 类（线程安全的 `NSLock` 保护）
   - `classifyRiskLevel(tool:input:)` 风险分类方法
   - 增强的提示格式（风险标签 + 分行参数 + `y/n/a` 选项）
   - `isInteractive: Bool` 参数控制非交互模式降级
   - [来源: `Sources/OpenAgentCLI/PermissionHandler.swift`]

3. **AgentFactory.swift 更新** — 传递 `isInteractive` 参数：
   ```swift
   let isInteractive = args.prompt == nil && args.skillName == nil
   let canUseTool = PermissionHandler.createCanUseTool(
       mode: permMode, reader: reader, renderer: permRenderer, isInteractive: isInteractive
   )
   ```
   - [来源: `Sources/OpenAgentCLI/AgentFactory.swift#L97-105`]

4. **REPLLoop.swift 当前结构** — 无信号处理：
   - `start()` 方法中 `while let input = reader.readLine(prompt: "> ")` 循环
   - `agentHolder.agent.stream(trimmed)` + `renderer.renderStream(stream)` 消费流
   - 没有任何 SIGINT/SIGTERM 处理 — 按 Ctrl+C 会直接杀死进程
   - [来源: `Sources/OpenAgentCLI/REPLLoop.swift#L76-98`]

5. **CLI.swift 退出流程** — `closeAgentSafely()` 方法：
   ```swift
   private static func closeAgentSafely(_ agent: Agent) async {
       do {
           try await agent.close()
       } catch {
           let warning = "Warning: Failed to save session: \(error.localizedDescription)"
           FileHandle.standardError.write((warning + "\n").data(using: .utf8)!)
       }
   }
   ```
   - [来源: `Sources/OpenAgentCLI/CLI.swift#L143-150`]

### SDK API 详细参考

本故事使用的核心 SDK API：

```swift
// Agent.interrupt() — 中断当前查询
// SDK 注释：取消内部的 _streamTask。如果当前没有运行查询，则不做任何操作。
agent.interrupt()  // 无返回值，无异常抛出

// Agent.close() — 永久关闭 Agent
// SDK 注释：中断活跃查询、持久化会话、关闭 MCP 连接。
// 后续所有 prompt/stream 调用返回错误。
try await agent.close()

// AsyncStream<SDKMessage> — 流式查询的返回类型
let stream = agent.stream(prompt)
for await message in stream {
    renderer.render(message)
}
// 当 interrupt() 被调用时，stream 的 Task 被取消，
// for await 循环正常退出（不抛异常）
```

**关键行为：**
- `agent.interrupt()` 设置内部 `_interrupted = true` 并调用 `_streamTask?.cancel()`
- Swift cooperative cancellation 意味着 `AsyncStream` 的 `for await` 循环会在下一个 suspension point 正常结束
- `interrupt()` 不抛异常，不返回值 — 是安全的幂等操作
- `close()` 内部会先调用 `interrupt()`，然后持久化会话

[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L270-282]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L440-469]

### 核心设计决策

#### 决策 1: 信号处理器架构

创建独立的 `SignalHandler` 类型，封装平台特定的信号注册逻辑：

```swift
/// Signal event types that the REPL loop can react to.
enum SignalEvent {
    case none          // No signal received
    case interrupt     // SIGINT (Ctrl+C) — interrupt current operation
    case forceExit     // Double SIGINT within 1s — force quit
    case terminate     // SIGTERM — graceful shutdown
}

/// Registers SIGINT/SIGTERM handlers and provides a thread-safe query interface.
///
/// Uses `sigaction` for reliable signal handling on both Darwin and Linux.
/// Signal handlers only set volatile flags — all real work happens in the
/// REPL loop's cooperative polling via `check()`.
enum SignalHandler {
    /// Register signal handlers. Call once at CLI startup.
    static func register()

    /// Check current signal state and consume the event.
    /// Returns .none if no signal is pending.
    static func check() -> SignalEvent

    /// Reset interrupt state (after handling an interrupt).
    static func clearInterrupt()
}
```

**为什么用 `sigaction` 而不是 `signal()`：**
- `sigaction` 在所有 POSIX 平台上行为一致
- `signal()` 在不同 Unix 实现中语义不同（是否自动恢复默认处理器）
- Swift 的 `Darwin` 模块在 macOS 上直接提供 `sigaction`，Linux 上通过 `Glibc`

**为什么用 volatile 标志而非直接在信号处理器中调用 SDK：**
- 信号处理器中只能安全地调用 async-safe 函数（不能调用任何 SDK 方法）
- 设置标志 + REPL 循环中轮询是标准模式
- `sig_atomic_t`（C 类型）或 Swift 的 `UnsafeMutablePointer<Int>` 用于标志位

#### 决策 2: SIGINT 处理 — 中断 vs 退出

```
第一次 Ctrl+C:
  → 检测到 SIGINT 标志
  → 调用 agent.interrupt()
  → renderStream 的 for await 循环正常结束
  → 输出 "^C\n"
  → 继续外层 REPL while 循环
  → ">" 提示符重新出现

第二次 Ctrl+C（1秒内）:
  → 检测到 forceExit 标志
  → break 退出 REPL while 循环
  → CLI.run() 中 closeAgentSafely() 保存会话
  → 进程正常退出（exit code 0）
```

**实现方式：** 在 SIGINT handler 中记录时间戳。`SignalHandler.check()` 对比前后两次 SIGINT 的时间差来决定返回 `.interrupt` 还是 `.forceExit`。

#### 决策 3: renderStream 中的中断检测

当前 `renderStream` 是 `OutputRenderer` 的方法，只消费 `AsyncStream`。中断需要发生在 REPLLoop 层面。

**方案：** REPLLoop 不直接调用 `renderer.renderStream(stream)`，而是自己遍历流，在每个消息之间检查中断标志：

```swift
// REPLLoop.start() 中的流消费
let stream = agentHolder.agent.stream(trimmed)
for await message in stream {
    let event = SignalHandler.check()
    if event == .interrupt || event == .forceExit {
        agentHolder.agent.interrupt()
        renderer.output.write("^C\n")
        if event == .forceExit { return }  // break REPL loop
        break  // break inner stream loop, continue REPL while loop
    }
    renderer.render(message)
}
```

这样不需要修改 `OutputRenderer`，中断逻辑完全在 REPLLoop 中。

#### 决策 4: 权限提示中的 Ctrl+C

当 Agent 等待权限回调时（`canUseTool` 闭包中的 `reader.readLine()`），Ctrl+C 产生 SIGINT。由于 `FileHandleInputReader.readLine()` 使用 `Swift.readLine()`，SIGINT 会导致 `readLine()` 返回 `nil`（EOF 行为）。

当前 `PermissionHandler.promptUser()` 中已有：
```swift
guard let response = reader.readLine(prompt: "") else {
    return .deny("No input received")
}
```

这意味着 Ctrl+C 在权限提示中会返回 `.deny("No input received")`，Agent 收到拒绝通知，然后继续生成响应。REPL 循环会正常继续。

**需要改进的地方：** SIGINT 处理器会在 `readLine()` 返回 nil 后被 SignalHandler.check() 检测到。需要确保在权限回调返回后，REPL 循环也检查中断标志，避免 Agent 被拒绝后继续生成新内容。

#### 决策 5: 跨平台信号处理

```swift
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// sigaction 在两个平台上都可用
var sa = sigaction()
sa.__sigaction_u.__sa_handler = { sig in
    // 设置标志位
}
sigaction(SIGINT, &sa, nil)
sigaction(SIGTERM, &sa, nil)
```

### 架构合规性

本故事涉及架构文档中的 **FR2.6** 和 **NFR2.5**：

- **FR2.6:** 支持中断当前操作：Ctrl+C 优雅中断不退出 REPL (P1) → `REPLLoop.swift`, `CLI.swift`
- **NFR2.5:** Ctrl+C 优雅退出（保存会话，清理资源）→ `CLI.swift`

架构文档中的信号处理规范：
- SIGINT → 中断，SIGTERM → 保存 + 退出
- 1 秒内第二次 Ctrl+C → 强制退出

[来源: _bmad-output/planning-artifacts/epics.md#Story 5.3]
[来源: _bmad-output/planning-artifacts/prd.md#FR2.6]
[来源: _bmad-output/planning-artifacts/prd.md#NFR2.5]
[来源: _bmad-output/planning-artifacts/architecture.md#流程模式-信号处理]

### 关键约束：零 internal 访问

整个项目仅允许 `import OpenAgentSDK`。不得导入任何 internal 模块或使用 `@_implementationOnly`。如果发现 SDK 缺少 public API，使用 `// SDK-GAP:` 注释记录，不绕过。

[来源: prd.md#技术约束, architecture.md#执行指南]

### 不要做的事

1. **不要修改 OutputRenderer 或 OutputRendering 协议** — 中断逻辑在 REPLLoop 中通过直接检查信号标志实现，不需要修改渲染器。

2. **不要在信号处理器中直接调用 SDK 方法** — 信号处理器中只能设置原子标志。所有实际操作（interrupt、close、print）都在主线程的 REPL 循环中执行。

3. **不要使用 Swift Concurrency 的 `Task.cancel()` 作为唯一的取消机制** — 虽然 `agent.interrupt()` 内部使用了 Task.cancel，但 REPLLoop 需要自己的信号机制来触发这个调用。

4. **不要创建复杂的线程同步** — 使用简单的 volatile 标志（`sig_atomic_t`）足够，因为信号处理器只写，REPL 循环只读。

5. **不要忽略 Linux 兼容性** — 使用 `#if canImport(Darwin)` / `#if canImport(Glibc)` 条件编译确保跨平台。

6. **不要修改 PermissionHandler 的核心逻辑** — 权限提示中的 Ctrl+C 行为已经自然处理（readLine 返回 nil → deny）。只需确保中断标志被正确设置。

7. **不要引入第三方信号处理库** — 使用 Foundation + Darwin/Glibc 的 `sigaction`。

### 项目结构说明

需要创建的文件：
```
Sources/OpenAgentCLI/
  SignalHandler.swift            # 新建：SIGINT/SIGTERM 信号处理
```

需要修改的文件：
```
Sources/OpenAgentCLI/
  REPLLoop.swift                 # 修改：集成中断检测到流消费循环
  CLI.swift                      # 修改：注册信号处理器，处理 SIGTERM 退出
```

需要创建的测试：
```
Tests/OpenAgentCLITests/
  SignalHandlerTests.swift       # 新建：信号处理器测试
  REPLLoopTests.swift            # 修改：添加中断行为测试（如果文件已存在则扩展）
```

不修改的文件：
```
Sources/OpenAgentCLI/
  ArgumentParser.swift           # 参数解析不变
  AgentFactory.swift             # Agent 创建不变
  PermissionHandler.swift        # 权限逻辑不变（Ctrl+C 在 readLine 层面自然处理）
  OutputRenderer.swift           # 渲染器不变
  OutputRenderer+SDKMessage.swift # SDKMessage 渲染不变
  MCPConfigLoader.swift          # MCP 配置不变
  CLISingleShot.swift            # 单次模式不变
  ConfigLoader.swift             # 配置加载不变
  ANSI.swift                     # ANSI 辅助不变
  Version.swift                  # 版本不变
  main.swift                     # 入口不变
```

[来源: architecture.md#项目结构]

### 测试策略

**新增测试分布预期：**

| 测试方法名 | 覆盖 AC | 说明 |
|-----------|---------|------|
| testSignalHandler_registersHandlers | #1, #3, #4 | 注册后 SIGINT/SIGTERM 处理器生效 |
| testSignalHandler_singleSIGINT_returnsInterrupt | #1 | 单次 SIGINT → `.interrupt` |
| testSignalHandler_doubleSIGINT_returnsForceExit | #3 | 1秒内两次 SIGINT → `.forceExit` |
| testSignalHandler_slowDoubleSIGINT_returnsInterrupt | #3 | 间隔 > 1s 的两次 SIGINT → 两次 `.interrupt` |
| testSignalHandler_SIGTERM_returnsTerminate | #4 | SIGTERM → `.terminate` |
| testSignalHandler_clearInterrupt_resetsState | #1 | 清除后返回 `.none` |
| testREPLLoop_interrupt_resumesPrompt | #1 | 中断后 REPL 继续循环，提示符重新出现 |
| testREPLLoop_forceExit_exitsREPL | #3 | 双击 Ctrl+C 退出 REPL |
| testREPLLoop_terminate_savesSession | #4 | SIGTERM 触发会话保存后退出 |
| testREPLLoop_interruptDuringPermissionPrompt | #2 | 权限提示中 Ctrl+C 取消操作 |
| testExistingTestsPass_regression | 全部 | 383 项测试无回归 |

**测试方法：**

1. **SignalHandler 测试** — 直接调用 `raise(SIGINT)` / `raise(SIGTERM)` 发送信号，然后 `SignalHandler.check()` 验证返回值。注意测试中需要在断言前注册处理器。

2. **REPLLoop 中断测试** — 使用 `MockInputReader` 预设输入序列 + 在特定时机调用 `raise(SIGINT)` 或直接设置 `SignalHandler` 的内部状态。验证 REPL 循环继续（不退出）且输出包含 `^C`。

3. **回归测试** — 确保所有现有 383 项测试通过。新增的 `SignalHandler.swift` 和 `REPLLoop.swift` 修改不应影响现有行为。

### 参考

- [来源: _bmad-output/planning-artifacts/epics.md#Story 5.3]
- [来源: _bmad-output/planning-artifacts/prd.md#FR2.6, NFR2.5]
- [来源: _bmad-output/planning-artifacts/architecture.md#流程模式-信号处理]
- [来源: Sources/OpenAgentCLI/REPLLoop.swift — 需要添加中断检测]
- [来源: Sources/OpenAgentCLI/CLI.swift — 需要注册信号处理器]
- [来源: Sources/OpenAgentCLI/OutputRenderer.swift#L109-113 — renderStream 方法]
- [来源: Sources/OpenAgentCLI/PermissionHandler.swift — 权限提示中的 readLine]
- [来源: Sources/OpenAgentCLI/AgentFactory.swift — Agent 创建]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L279-282 — agent.interrupt()]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L449-469 — agent.close()]
- [来源: _bmad-output/implementation-artifacts/5-2-interactive-permission-prompts.md — 前一故事]

### 项目结构说明

- 新建 `SignalHandler.swift` 遵循一文件一类型的约定
- `SignalHandler` 使用 `enum`（无实例，只有静态方法），与项目中 `ANSI`、`CLI` 等类型保持一致
- 信号处理器修改不影响现有组件的接口
- 跨平台代码使用 `#if canImport(Darwin)` / `#if canImport(Glibc)` 条件编译
- 没有与统一项目结构的冲突或偏差

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (GLM-5.1)

### Debug Log References

- Double-press detection: initial implementation used single lastSigintTime comparison which incorrectly triggered forceExit on first SIGINT (elapsed=0 from epoch). Fixed by introducing sigintCount + prevSigintTime pattern.
- Test isolation: REPLLoopInterruptTests.testREPLLoop_interrupt_resumesPrompt failed when run with full suite due to state leaking from SignalHandlerTests. Fixed by adding setUp/tearDown with clearInterrupt() in REPLLoopInterruptTests.
- Signal injection timing: SignalMockInputReader originally injected signal before incrementing callCount, causing signal to arrive at wrong read cycle. Fixed to inject after callCount increment (1-indexed semantics).

### Completion Notes List

- SignalHandler.swift implemented with sigaction-based signal registration, cross-platform Darwin/Glibc support, nonisolated(unsafe) for Swift concurrency compliance
- Double-press detection uses sigintCount (accumulates SIGINTs from handler) + prevSigintTime (tracks previously consumed SIGINT timestamp) for reliable detection
- REPLLoop.swift: replaced renderStream() call with manual AsyncStream iteration that checks SignalHandler.check() between messages; added preCheck between readLine calls for idle-state interrupt handling; added postCheck after stream completes
- CLI.swift: added SignalHandler.register() call after config loading
- Permission prompt Ctrl+C handling already works naturally (readLine returns nil -> .deny), verified with testPermissionPrompt_readLineNil_returnsDeny
- All 396 tests pass (383 existing + 13 new), zero regressions
- Build completes with zero warnings

### File List

- Sources/OpenAgentCLI/SignalHandler.swift (新建)
- Sources/OpenAgentCLI/REPLLoop.swift (修改)
- Sources/OpenAgentCLI/CLI.swift (修改)
- Tests/OpenAgentCLITests/SignalHandlerTests.swift (修改 - 已有 ATDD 红灯测试，补充测试基础设施)
- Tests/OpenAgentCLITests/REPLLoopInterruptTests.swift (修改 - 已有 ATDD 红灯测试，修复测试 mock 和隔离性)
