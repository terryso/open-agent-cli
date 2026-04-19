# Story 1.4: 交互式 REPL 循环

状态: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## 故事

作为一个用户，
我想要一个交互式提示符，可以持续地输入问题并获得回答，
以便我与 Agent 进行多轮对话。

## 验收标准

1. **假设** CLI 处于 REPL 模式（无位置参数 `prompt`）
   **当** CLI 启动完成
   **那么** 显示 `>` 提示符，等待用户输入

2. **假设** 我在 REPL 中输入了一条消息并按 Enter
   **当** Agent 正在处理
   **那么** 我看到实时的流式输出（通过 OutputRenderer）

3. **假设** Agent 完成响应
   **当** 流完成
   **那么** `>` 提示符重新出现，等待下一条消息

4. **假设** 我在 REPL 中输入 `/help`
   **当** 命令被处理
   **那么** 显示可用 REPL 命令列表

5. **假设** 我在 REPL 中输入 `/exit` 或 `/quit`
   **当** 命令被处理
   **那么** CLI 优雅退出

6. **假设** 我输入空行或仅包含空白字符
   **当** 输入被读取
   **那么** 被忽略，提示符重新出现

## 任务 / 子任务

- [x] 任务 1: 创建 `REPLLoop.swift` — REPL 循环核心 (AC: #1, #2, #3, #5, #6)
  - [x] 定义 `InputReading` 协议用于终端输入抽象（可测试性）
  - [x] 实现 `FileHandleInputReader` — 从 stdin 读取一行输入
  - [x] 实现 `REPLLoop` 结构体，持有 `agent: Agent`、`renderer: OutputRenderer`、`reader: InputReading`
  - [x] 实现 `start()` 方法：while 循环读取输入、分发命令、发送给 Agent
  - [x] 处理空行/纯空白输入：忽略，重新显示提示符
  - [x] 处理 `/exit` 和 `/quit` 命令：优雅退出循环
  - [x] 对用户输入调用 `agent.stream(input)` 并通过 `renderer.renderStream()` 渲染

- [x] 任务 2: 实现 `/help` 斜杠命令 (AC: #4)
  - [x] 在 REPLLoop 中实现 `handleSlashCommand(_ input: String)` 方法
  - [x] `/help` 输出所有可用 REPL 命令列表
  - [x] 未知斜杠命令显示 "Unknown command: /xxx" 和提示使用 /help

- [x] 任务 3: 更新 `CLI.swift` — 集成 REPLLoop (AC: #1, #2, #3)
  - [x] 替换 REPL 分支中的占位 `print("Agent created. REPL mode ready.")` 为 `REPLLoop` 调用
  - [x] 创建 OutputRenderer 和 InputReader 实例传递给 REPLLoop
  - [x] REPL 退出后调用 `try? await agent.close()` 清理资源

- [x] 任务 4: 创建 `REPLLoopTests.swift` (AC: #1, #2, #3, #4, #5, #6)
  - [x] 创建 `MockInputReader` 实现 `InputReading` 协议，返回预定义输入序列
  - [x] 测试 AC#1: REPL 启动后显示提示符
  - [x] 测试 AC#2: 输入消息后 Agent 收到正确的 stream 调用
  - [x] 测试 AC#3: Agent 响应完成后提示符重新出现
  - [x] 测试 AC#4: `/help` 命令输出命令列表
  - [x] 测试 AC#5: `/exit` 和 `/quit` 命令终止循环
  - [x] 测试 AC#6: 空行被忽略

## 开发备注

### 前一故事的关键学习

Story 1.3（流式输出渲染器）已完成，以下是已建立的模式和当前状态：

1. **OutputRenderer 已就绪** — `OutputRenderer` 支持通过 `renderStream(_ stream: AsyncStream<SDKMessage>)` 消费整个流。REPL 循环可以直接使用此方法渲染 Agent 响应。[来源: `Sources/OpenAgentCLI/OutputRenderer.swift#L107-111`]

2. **CLI.swift 当前 REPL 占位** — REPL 分支当前为 `print("Agent created. REPL mode ready.")` 和 `_ = agent`。需替换为 REPLLoop 实现。[来源: `Sources/OpenAgentCLI/CLI.swift#L47-50`]

3. **TextOutputStream 抽象已建立** — `AnyTextOutputStream` 使用 `@unchecked Sendable` + `NSLock` 保证线程安全。类似的模式可用于 `InputReading` 协议的 mock 实现。[来源: `Sources/OpenAgentCLI/OutputRenderer.swift#L11-28`]

4. **测试策略已验证** — 使用 mock 对象替换 I/O 进行测试。OutputRendererTests 使用 `MockTextOutputStream` 捕获输出。REPLLoopTests 应使用 `MockInputReader` 注入输入。[来源: Story 1.3 测试策略]

5. **全部 124 测试通过** — 本故事的实现不应破坏任何现有测试（97 基础 + 27 渲染器测试）。[来源: Story 1.3 完成备注]

6. **Agent SDK API 已确认可用** — `agent.stream(_:)` 返回 `AsyncStream<SDKMessage>`，`agent.close()` 异步关闭并保存会话。[来源: `open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift`]

### 架构合规性

本故事实现架构文档实现顺序中的**第五个组件**：
1. ~~`Version.swift` + `ANSI.swift`（常量）~~ — Story 1.1
2. ~~`ArgumentParser.swift`（CLI 参数 -> ParsedArgs）~~ — Story 1.1
3. ~~`OutputRenderer.swift`（SDKMessage -> 终端）~~ — Story 1.3
4. ~~`AgentFactory.swift`（从解析参数组装 Agent）~~ — Story 1.2
5. **`REPLLoop.swift`（将所有组件串联起来）** — 本故事

REPLLoop 是架构的核心集成组件——它将 ArgumentParser（模式判断）、AgentFactory（Agent 创建）和 OutputRenderer（输出渲染）连接在一起。

[来源: architecture.md#实现顺序]

### 关键约束：零 internal 访问

整个项目仅允许 `import OpenAgentSDK`。不得导入任何 internal 模块或使用 `@_implementationOnly`。如果发现 SDK 缺少 public API，使用 `// SDK-GAP:` 注释记录，不绕过。

[来源: prd.md#技术约束, architecture.md#执行指南]

### SDK API 参考 — REPL 所需

**核心 Agent API：**
```swift
import OpenAgentSDK

// 流式对话 — REPL 循环的主要 API
let stream: AsyncStream<SDKMessage> = agent.stream("Hello")
for await message in stream {
    renderer.render(message)
}

// 关闭 Agent — 退出 REPL 时调用
try await agent.close()

// 中断当前操作 — Ctrl+C 时调用（Story 5.3 范围，本故事暂不实现）
agent.interrupt()
```

[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L1315 (stream)]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L449 (close)]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L279 (interrupt)]

**Agent.close() 行为细节：**
- 中断任何活跃查询
- 如果配置了 SessionStore 且 persistSession 为 true，持久化会话
- 关闭 MCP 连接
- 重复调用会抛出 `SDKError.invalidConfiguration("Agent is already closed.")`
- 因此使用 `try? await agent.close()` 忽略重复关闭错误

[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#L449-485]

### REPLLoop 设计模式

遵循架构文档的基于协议的可测试性原则，REPLLoop 需要抽象输入：

```swift
import Foundation
import OpenAgentSDK

/// Protocol for reading terminal input, enabling testability.
protocol InputReading: Sendable {
    /// Read a line of input with the given prompt.
    /// Returns nil on EOF (Ctrl+D).
    func readLine(prompt: String) -> String?
}

/// Reads input from standard input via FileHandle.
struct FileHandleInputReader: InputReading {
    func readLine(prompt: String) -> String? {
        // Write prompt to stdout (no newline)
        FileHandle.standardOutput.write((prompt).data(using: .utf8) ?? Data())
        // Read line from stdin
        return FileHandle.standardInput.readLine()
    }
}

/// Interactive read-eval-print loop.
///
/// Reads user input, sends it to the Agent as a streaming query,
/// renders the response via OutputRenderer, and repeats.
struct REPLLoop {
    let agent: Agent
    let renderer: OutputRenderer
    let reader: InputReading

    func start() async {
        while let input = reader.readLine(prompt: "> ") {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

            // AC#6: Ignore empty lines
            guard !trimmed.isEmpty else { continue }

            // Slash commands
            if trimmed.hasPrefix("/") {
                if handleSlashCommand(trimmed) { break }
                continue
            }

            // AC#2, AC#3: Send to Agent and render stream
            let stream = agent.stream(trimmed)
            await renderer.renderStream(stream)
        }
    }

    /// Handle a slash command. Returns true if the REPL should exit.
    private func handleSlashCommand(_ input: String) -> Bool {
        let parts = input.split(separator: " ", maxSplits: 1)
        let command = parts[0].lowercased()

        switch command {
        case "/exit", "/quit":
            return true  // AC#5
        case "/help":
            printHelp()   // AC#4
        default:
            // Unknown command
            renderer.output.write("Unknown command: \(input). Type /help for available commands.\n")
        }
        return false
    }

    private func printHelp() {
        let help = """
        Available commands:
          /help          Show this help message
          /exit          Exit the REPL
          /quit          Exit the REPL
        """
        renderer.output.write("\(help)\n")
    }
}
```

### CLI.swift 集成点

当前 CLI.swift REPL 分支（第 47-50 行）：
```swift
} else {
    // REPL mode -- REPL loop is Story 1.4's scope.
    print("Agent created. REPL mode ready.")
    _ = agent
}
```

需替换为：
```swift
} else {
    // REPL mode: start interactive loop.
    let reader = FileHandleInputReader()
    let renderer = OutputRenderer()
    let repl = REPLLoop(agent: agent, renderer: renderer, reader: reader)
    await repl.start()
    try? await agent.close()
}
```

[来源: Sources/OpenAgentCLI/CLI.swift#L47-50]

### 不要做的事

1. **不要实现 Ctrl+C 中断处理** — 优雅中断是 Story 5.3 的范围。本故事的 REPL 只需要基本的输入/输出循环。`FileHandle.standardInput.readLine()` 本身不处理信号。
2. **不要实现会话管理** — 会话自动保存/恢复是 Epic 3 的范围（Story 3.1、3.2、3.3）。
3. **不要实现权限提示** — Story 5.2 的范围。
4. **不要实现额外的斜杠命令** — `/model`、`/mode`、`/cost`、`/clear`、`/sessions`、`/resume`、`/tools` 等命令是后续故事的范围。本故事仅实现 `/help`、`/exit`、`/quit`。
5. **不要修改 ArgumentParser** — ParsedArgs 已在 Story 1.1 中完整实现，REPL 模式判断基于 `args.prompt == nil`。
6. **不要修改 AgentFactory** — Agent 创建已在 Story 1.2 中完成。
7. **不要修改 OutputRenderer** — 渲染器已在 Story 1.3 中完成，直接使用即可。
8. **不要使用 readline 或第三方库** — 使用 Foundation 的 `FileHandle.standardInput` 读取输入。

### 项目结构说明

需要创建/修改的文件：
```
Sources/OpenAgentCLI/
  REPLLoop.swift               # 创建：REPL 循环 + InputReading 协议 + FileHandleInputReader
  CLI.swift                    # 修改：REPL 分支集成 REPLLoop

Tests/OpenAgentCLITests/
  REPLLoopTests.swift          # 创建：REPL 循环测试（使用 MockInputReader）
```

[来源: architecture.md#项目结构]

### 测试策略

**测试方法：** 使用 `MockInputReader` 注入预定义输入序列，验证 REPL 行为：

```swift
/// Mock input reader for testing.
final class MockInputReader: InputReading {
    var lines: [String?]
    var callCount = 0
    var lastPrompt: String?

    init(_ lines: [String?]) {
        self.lines = lines
    }

    func readLine(prompt: String) -> String? {
        lastPrompt = prompt
        guard callCount < lines.count else { return nil }
        let line = lines[callCount]
        callCount += 1
        return line
    }
}
```

**关键测试场景：**

1. **AC#1 + AC#3: 提示符显示** — `MockInputReader` 记录 `lastPrompt`，验证 prompt 为 `"> "`。每条消息处理后 prompt 重新出现。
2. **AC#2: 消息发送到 Agent** — 验证 `agent.stream()` 被调用且 `renderer.renderStream()` 消费了流。
3. **AC#4: `/help` 命令** — 输入 `/help`，验证输出包含命令列表文本。
4. **AC#5: `/exit` 退出** — 输入几条消息后输入 `/exit`，验证循环终止。
5. **AC#5: `/quit` 退出** — 同上，使用 `/quit`。
6. **AC#6: 空行忽略** — 输入空行、纯空格、纯 tab，验证不发送给 Agent。

**测试挑战：** Agent 是 class 类型，无法轻易 mock。由于 Agent 的 `stream()` 需要 LLM API，单元测试有两种方案：
- **方案 A（推荐）：** 测试 REPLLoop 的输入分发逻辑（斜杠命令、空行处理），不测试与 Agent 的实际交互。Agent 交互在集成/冒烟测试中验证。
- **方案 B：** 创建 Agent 使用无效 API key，仅测试 REPL 不崩溃（流返回错误结果，renderer 渲染错误）。

选择方案 A：MockInputReader 注入输入，MockOutputRenderer 或真实 OutputRenderer + MockTextOutputStream 捕获输出。测试输入分发、命令处理、退出逻辑。

### FileHandle.readLine() 注意事项

`FileHandle` 在 Swift Foundation 中有 `readLine()` 方法（iOS 16+ / macOS 13+），直接读取一行。注意：
- 返回 `String?`，EOF 时返回 nil（对应 Ctrl+D）
- 行末换行符被剥离
- 阻塞读取，直到用户按 Enter
- 不支持行编辑（无退格、无历史）— 这是可接受的 MVP 行为

### 性能注意事项

- **REPL 循环本身无性能要求** — 它只是一个 while 循环 + 输入等待
- **流式渲染已由 OutputRenderer 处理** — 无额外开销
- **内存** — REPLLoop 不持有状态，不累积消息。Agent 内部管理对话历史

[来源: prd.md#NFR1, architecture.md#性能考量]

### 参考资料

- [来源: _bmad-output/planning-artifacts/epics.md#Story 1.4]
- [来源: _bmad-output/planning-artifacts/prd.md#FR2.1, FR2.4]
- [来源: _bmad-output/planning-artifacts/architecture.md#REPLLoop, 实现顺序, 组件边界]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#stream()]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift#close()]
- [来源: Sources/OpenAgentCLI/CLI.swift#L47-50 (REPL 占位)]
- [来源: Sources/OpenAgentCLI/OutputRenderer.swift (renderStream)]
- [来源: _bmad-output/implementation-artifacts/1-3-streaming-output-renderer.md#前一故事学习]

## 开发代理记录

### 使用的代理模型

GLM-5.1

### 调试日志引用

- `FileHandle.readLine()` 在 Swift 6.2 / macOS 15 上不可用。改用 `Swift.readLine()` 内置函数。
- `MockInputReader` 需 `@unchecked Sendable` 注解以符合 Swift 6 严格并发检查（因 mutable stored properties）。

### 完成备注列表

- 实现了 `InputReading` 协议、`FileHandleInputReader`、`REPLLoop` 结构体
- REPLLoop 实现 while 循环读取输入、分发斜杠命令、发送给 Agent 并渲染流式输出
- `/help`、`/exit`、`/quit` 斜杠命令全部实现，大小写不敏感
- 未知斜杠命令显示错误消息并建议使用 /help
- 空行和纯空白输入被正确忽略
- CLI.swift REPL 分支已替换占位代码，集成 REPLLoop + agent.close()
- 22 个 REPLLoop 测试全部通过（覆盖所有 6 个 AC）
- 全部 146 测试通过（124 已有 + 22 新增），零回归

### 文件列表

- `Sources/OpenAgentCLI/REPLLoop.swift` — 创建：REPL 循环核心（InputReading 协议、FileHandleInputReader、REPLLoop 结构体）
- `Sources/OpenAgentCLI/CLI.swift` — 修改：REPL 分支集成 REPLLoop（替换占位代码）
- `Tests/OpenAgentCLITests/REPLLoopTests.swift` — 修改：MockInputReader 添加 @unchecked Sendable（修复 Swift 6 编译错误）

## 变更日志

- 2026-04-19: Story 1.4 实现完成 — 创建 REPLLoop.swift（InputReading 协议 + FileHandleInputReader + REPLLoop 结构体），集成到 CLI.swift REPL 分支，22 个测试覆盖全部 6 个验收标准，146 测试全部通过

### Review Findings

- [x] [Review][Patch] No error handling around Agent stream in REPL loop [Sources/OpenAgentCLI/REPLLoop.swift:60-62] — FIXED: wrapped agent.stream() + renderStream() in do/catch, error shown to user, loop continues
- [x] [Review][Patch] Dead code: unused makeMockStream function [Tests/OpenAgentCLITests/REPLLoopTests.swift:47-54] — FIXED: removed unused helper function
