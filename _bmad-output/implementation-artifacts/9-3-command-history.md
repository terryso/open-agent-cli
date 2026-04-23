# Story 9.3: 历史回溯

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为一个用户，
我想要用上下箭头翻阅之前输入的命令，
以便快速重复或修改之前的输入。

## Acceptance Criteria

### AC#1: 当前会话历史导航

**Given** 我在当前会话中已输入 3 条消息（"hello", "list files", "show cost"）
**When** 我按上箭头
**Then** 提示符显示 "show cost"
**When** 我再按上箭头
**Then** 显示 "list files"
**When** 我按下箭头
**Then** 显示 "show cost"

### AC#2: 历史中间修改不影响原始条目

**Given** 我在历史中间位置修改了内容
**When** 我按上箭头到某条历史，修改了内容，然后按回车发送
**Then** 发送修改后的内容
**And** 原始历史条目保持不变

### AC#3: 跨会话历史持久化

**Given** 我退出并重新启动 CLI
**When** 我按上箭头
**Then** 可以看到上次会话的历史输入

### AC#4: 历史文件自动创建

**Given** 历史文件 `~/.openagent/history` 不存在
**When** CLI 启动
**Then** 自动创建文件，从空历史开始

### AC#5: 历史条目上限（FIFO）

**Given** 历史文件超过 1000 条
**When** 新输入被记录
**Then** 最早的条目被移除（FIFO）

### AC#6: 历史文件损坏容错

**Given** 历史文件损坏或不可读
**When** CLI 启动
**Then** 显示警告但正常启动，从空历史开始

## Tasks / Subtasks

- [ ] Task 1: 添加 linenoise-swift SPM 依赖 (AC: #1-#6)
  - [ ] 在 `Package.swift` 的 `dependencies` 数组中添加 `.package(url: "https://github.com/andybest/linenoise-swift", branch: "master")`
  - [ ] 在 `OpenAgentCLI` target 的 `dependencies` 中添加 `.product(name: "LineNoise", package: "linenoise-swift")`
  - [ ] 运行 `swift package resolve` 确认依赖解析成功
  - [ ] 运行 `swift build` 确认编译通过

- [ ] Task 2: 创建 `LinenoiseInputReader.swift` (AC: #1-#6)
  - [ ] 创建 `Sources/OpenAgentCLI/LinenoiseInputReader.swift`
  - [ ] 实现 `InputReading` 协议，内部持有 `LineNoise` 实例
  - [ ] `readLine(prompt:)` 调用 `linenoise.getLine(prompt:)`，处理 throws 返回值
  - [ ] 捕获 `LinenoiseError.EOF` 返回 nil（对应 Ctrl+D）
  - [ ] 捕获 `LinenoiseError.CTRL_C` 返回 nil（REPL 层的 SignalHandler 已处理中断，但 linenoise 自己也会抛出；需协调）
  - [ ] 初始化时设置历史文件路径 `~/.openagent/history`，调用 `loadHistory(fromFile:)`
  - [ ] 每次成功读取后调用 `addHistory(_:)` 记录输入
  - [ ] 设置历史最大长度 `setHistoryMaxLength(1000)`（AC#5）
  - [ ] 在 deinit/init 时调用 `saveHistory(toFile:)` 保存历史
  - [ ] 加载历史失败时打印警告，继续正常启动（AC#6）
  - [ ] 保存历史失败时静默忽略（非阻塞）

- [ ] Task 3: 替换 CLI.swift 中的 FileHandleInputReader (AC: #3)
  - [ ] 在 `CLI.swift` REPL 分支中，将 `FileHandleInputReader()` 替换为 `LinenoiseInputReader()`
  - [ ] 在 `--skill` 后进入 REPL 的分支中同样替换（CLI.swift:127）
  - [ ] 确保 `FileHandleInputReader` 保留在源码中（非交互模式仍可使用）

- [ ] Task 4: 处理 Ctrl+C 与 SignalHandler 的协调 (AC: #1)
  - [ ] linenoise-swift 在 Ctrl+C 时抛出 `LinenoiseError.CTRL_C`
  - [ ] `LinenoiseInputReader.readLine(prompt:)` 需捕获此错误并返回 nil 或空字符串
  - [ ] 返回 nil 会导致 REPL 退出（EOF 语义），不符合预期行为
  - [ ] 方案：捕获 `LinenoiseError.CTRL_C` 时返回空字符串 `""`，REPLLoop 中已有空输入忽略逻辑（`guard !trimmed.isEmpty else { continue }`），这样 Ctrl+C 只是取消当前输入、重新显示 prompt
  - [ ] **注意**：当前 REPLLoop 已有 SignalHandler 机制处理 Ctrl+C 中断 Agent 流式输出。linenoise 的 Ctrl+C 发生在输入阶段（等待用户输入时），这两个是不同场景。SignalHandler 处理的是 Agent 流式中的中断，linenoise 处理的是输入行编辑中的中断。需要确保两者不冲突。

- [ ] Task 5: 编写单元测试 (AC: #1-#6)
  - [ ] 测试 `LinenoiseInputReader` 实现 `InputReading` 协议
  - [ ] 测试历史文件不存在时自动创建（AC#4）
  - [ ] 测试历史文件损坏时打印警告并正常工作（AC#6）
  - [ ] 测试历史持久化：添加条目后保存，重新加载后可检索（AC#3）
  - [ ] 测试 FIFO：添加超过 1000 条后最早条目被移除（AC#5）
  - [ ] 测试 Ctrl+C 处理返回空字符串而非 nil
  - [ ] 测试 EOF（Ctrl+D）返回 nil
  - [ ] 测试 REPLLoop 使用 `LinenoiseInputReader` 时正常工作（集成测试）

## Dev Notes

### 核心实现策略

此 Story 的核心是**引入 linenoise-swift 第三方库替代手写的 `FileHandleInputReader`**，为 REPL 提供行编辑、历史导航和持久化能力。关键变更：

1. `Package.swift` — 添加 linenoise-swift 依赖
2. `LinenoiseInputReader.swift` — 新建，实现 `InputReading` 协议，封装 LineNoise
3. `CLI.swift` — 两处替换 reader 实例化

`REPLLoop.swift` **不需要修改**——它只通过 `InputReading` 协议的 `readLine(prompt:)` 方法与 reader 交互。这正是协议抽象的价值。

### linenoise-swift 关键 API

linenoise-swift 是纯 Swift 实现的 readline 替代品，SPM 产品名为 `LineNoise`（注意大小写，不是 `linenoise-swift`）。

```swift
import LineNoise

let ln = LineNoise()

// 基本行读取
do {
    let line = try ln.getLine(prompt: "> ")
} catch LinenoiseError.EOF {
    // Ctrl+D
} catch LinenoiseError.CTRL_C {
    // Ctrl+C
}

// 历史管理
ln.addHistory("user input")
ln.setHistoryMaxLength(1000)
try ln.saveHistory(toFile: "/path/to/history")
try ln.loadHistory(fromFile: "/path/to/history")

// Tab 补全（Story 9.4 使用）
ln.setCompletionCallback { currentText in
    return ["completion1", "completion2"]
}

// 行编辑快捷键（内置）
// Ctrl+A: 跳到行首  Ctrl+E: 跳到行尾
// Ctrl+U: 删除整行   Ctrl+K: 删到行尾
// Ctrl+W: 删除前一个词
// 上/下箭头: 历史导航
```

### 关键实现细节

**1. SPM 依赖添加格式**

当前 `Package.swift` 依赖项：
```swift
dependencies: [
    .package(url: "https://github.com/terryso/open-agent-sdk-swift", branch: "main"),
],
```

添加 linenoise-swift：
```swift
dependencies: [
    .package(url: "https://github.com/terryso/open-agent-sdk-swift", branch: "main"),
    .package(url: "https://github.com/andybest/linenoise-swift", branch: "master"),
],
```

Target 依赖添加：
```swift
executableTarget(
    name: "OpenAgentCLI",
    dependencies: [
        .product(name: "OpenAgentSDK", package: "open-agent-sdk-swift"),
        .product(name: "LineNoise", package: "linenoise-swift"),
    ],
    ...
),
```

**重要**：SPM 产品名是 `LineNoise`（PascalCase），不是 `linenoise-swift`。常见错误是混淆仓库名和产品名。

**2. LinenoiseInputReader 实现**

```swift
import Foundation
import LineNoise

final class LinenoiseInputReader: InputReading, @unchecked Sendable {
    private let linenoise: LineNoise
    private let historyPath: String

    init() {
        self.linenoise = LineNoise()
        self.linenoise.setHistoryMaxLength(1000)

        // 确保目录存在
        let dir = NSHomeDirectory() + "/.openagent"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        self.historyPath = dir + "/history"

        // 加载历史（失败静默处理）
        do {
            try linenoise.loadHistory(fromFile: historyPath)
        } catch {
            // AC#6: 文件不存在或损坏 — 继续空历史
            // 不打印警告给用户（文件不存在是首次启动的正常情况）
        }
    }

    func readLine(prompt: String) -> String? {
        do {
            let line = try linenoise.getLine(prompt: prompt)
            if !line.isEmpty {
                linenoise.addHistory(line)
            }
            saveHistoryIfNeeded()
            return line
        } catch LinenoiseError.CTRL_C {
            // Ctrl+C: 返回空字符串，REPLLoop 忽略空输入并重新显示 prompt
            return ""
        } catch {
            // EOF 或其他错误
            return nil
        }
    }

    private func saveHistoryIfNeeded() {
        do {
            try linenoise.saveHistory(toFile: historyPath)
        } catch {
            // 保存失败不影响使用
        }
    }
}
```

**3. Ctrl+C 处理策略**

linenoise-swift 在用户按 Ctrl+C 时抛出 `LinenoiseError.CTRL_C`。`LinenoiseInputReader` 应捕获此错误并返回空字符串 `""`。原因：

- 返回 `nil` 会让 REPLLoop 认为是 EOF，导致退出（不符合预期）
- 返回 `""` 后，REPLLoop 已有 `guard !trimmed.isEmpty else { continue }` 逻辑（REPLLoop.swift:124），会跳过空输入并重新显示 prompt
- 这使得 Ctrl+C 在输入阶段表现为"取消当前输入"，符合用户预期

**注意**：这与 Story 9.2 中 `ModeHolder` 使用的 `forceColor: true` 有关。linenoise 使用自己的 terminal output 写 prompt，ANSI 颜色码会被正确传递（linenoise 只是原样输出 prompt 字符串到终端）。

**4. 历史文件路径**

使用 `~/.openagent/history`。目录 `~/.openagent` 已在 ConfigLoader 等组件中使用。需要在 init 时确保目录存在（`FileManager.default.createDirectory`）。

**5. 保存时机**

每次成功读取输入后立即保存历史（增量保存）。这确保即使 CLI 非正常退出（如 kill -9），已输入的历史不会丢失。保存失败静默忽略。

**6. linenoise-swift 的 swift-tools-version 兼容性**

linenoise-swift 使用 `swift-tools-version:4.0`（非常旧的格式），但 SPM 向后兼容。此项目使用 `swift-tools-version:6.1`，不会有问题。`LineNoise` 库本身没有 external dependencies（test target 有 Nimble，但不影响库编译）。

**7. 非 TTY 模式的自动回退**

linenoise-swift 内置三种模式（`LineNoise.Mode`）：
- `.supportedTTY` — 正常交互终端（支持行编辑、历史）
- `.unsupportedTTY` — 如 dumb terminal（自动回退到 Swift readLine）
- `.notATTY` — 管道输入等

当在非交互环境（如测试、管道）中使用时，linenoise 自动降级。但 **测试中应使用 `MockInputReader`**，不直接使用 `LinenoiseInputReader`。REPLLoopTests 已使用 `MockInputReader`，不受影响。

**8. ANSI prompt 颜色兼容性**

Story 9.2 添加的彩色 prompt（`ANSI.coloredPrompt(forMode:modeHolder.mode, forceColor:true)`）会生成包含 ANSI escape codes 的字符串。linenoise-swift 的 `getLine(prompt:)` 将 prompt 原样写入 stdout，ANSI 码会被终端正确解释。 linenoise 内部使用 `prompt.count` 计算光标位置——这可能导致光标定位偏差，因为 ANSI escape sequences 的字符数不计入显示宽度。

**缓解措施**：linenoise-swift 的 `EditState` 使用 `prompt.count` 来定位光标。如果 prompt 包含 ANSI 码（如 `\u{001B}[32m`），`count` 会包含这些不可见字符，导致光标向右偏移。解决方案有两个：
- 方案A（推荐）：在 `LinenoiseInputReader` 中 strip ANSI 码后的长度传给 linenoise，但 linenoise API 不支持这种自定义
- 方案B（实际可行）：linenoise 的 `editLine` 方法中 prompt 被原样输出，然后 `EditState(prompt: prompt)` 用 `prompt.count` 作为偏移。由于 `> ` 只有 2 个可见字符但 ANSI 码增加了额外字符，光标会偏右。**实测影响**：光标在输入时可能向右多移几个位置，但编辑功能仍可用。这个偏移在 Story 9.4（Tab 补全）之前影响有限。
- 方案C（彻底修复）：fork linenoise-swift 或提交 PR 修复 `EditState` 中的 prompt 长度计算，使其只计算可见字符。但这超出本 Story 范围。

**建议**：先实现功能，在 Dev Notes 中记录此已知限制。如果光标偏移影响用户体验，在后续 Story 中处理。

### 不需要修改的文件

- `REPLLoop.swift` — 只通过 `InputReading` 协议交互，协议接口不变
- `ANSI.swift` — 彩色 prompt 生成的 ANSI 码对 linenoise 透明
- `OutputRenderer.swift` — 输出逻辑不涉及输入读取
- `ArgumentParser.swift` — 无新参数
- `PermissionHandler.swift` — 权限逻辑不变

### 与后续 Story 的关系

- **Story 9.4（Tab 补全）** 将在 `LinenoiseInputReader` 上调用 `linenoise.setCompletionCallback(...)`。本 Story 应确保 `LinenoiseInputReader` 暴露内部的 `linenoise` 实例或提供注册回调的方法。
- **Story 9.5（多行输入）** 将在 `REPLLoop` 层实现多行状态机，linenoise 的 `getLine` 每次返回一行。本 Story 不影响。

### Project Structure Notes

```
Sources/OpenAgentCLI/
  LinenoiseInputReader.swift  -- 新建 (~60 行)，实现 InputReading 协议
  CLI.swift                   -- 修改 2 处 reader 实例化
  Package.swift               -- 添加 linenoise-swift 依赖

Tests/OpenAgentCLITests/
  CommandHistoryTests.swift   -- 新建测试文件 (8-12 个测试)

注意：FileHandleInputReader.swift 保留在源码中
  （它定义在 REPLLoop.swift 文件内，非独立文件）
  实际上 InputReading 协议和 FileHandleInputReader 都定义在 REPLLoop.swift 中
  FileHandleInputReader 保留供非交互模式使用（虽然当前非交互模式不走 REPL）
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 9, Story 9.3]
- [Source: Sources/OpenAgentCLI/REPLLoop.swift:6-14 — InputReading 协议定义]
- [Source: Sources/OpenAgentCLI/REPLLoop.swift:18-29 — FileHandleInputReader 现有实现]
- [Source: Sources/OpenAgentCLI/REPLLoop.swift:97-108 — REPLLoop init 接受 InputReading]
- [Source: Sources/OpenAgentCLI/CLI.swift:127 — skill REPL 分支的 reader 实例化]
- [Source: Sources/OpenAgentCLI/CLI.swift:179 — REPL 模式分支的 reader 实例化]
- [Source: Package.swift — 当前依赖配置]
- [Source: https://github.com/andybest/linenoise-swift — linenoise-swift 库]

### Previous Story Learnings (9.1, 9.2)

- 735 unit tests 全量通过，0 回归
- Story 9.1 添加了 `CLI.swift:189-193` 欢迎信息（使用 `ANSI.dim()` 包裹）
- Story 9.2 添加了 `ModeHolder` class wrapper 模式（与 `AgentHolder`、`CostTracker` 一致）
- Story 9.2 彩色 prompt 通过 `ANSI.coloredPrompt(forMode:forceColor:true)` 生成
- `REPLLoop` 是 struct，不可变语义，使用 class wrapper 处理可变状态
- `InputReading` 协议只有 `readLine(prompt:) -> String?` 一个方法，非常简单
- 单元测试使用 `MockInputReader` 模拟输入，`StringOutput` capture 模式验证输出
- `parsedArgs` 已通过 init 传入 REPLLoop，可直接用于获取初始 mode
- ANSI.swift 中颜色方法格式一致：`"\u{001B}[XXm\(text)\u{001B}[0m"`

### Git Intelligence (Recent Commits)

```
58e516c feat: add colored REPL prompt based on permission mode — Story 9.2
66047e1 feat: add REPL welcome screen — Story 9.1
```

- Story 9.2 修改了 `ANSI.swift`（添加 `blue()` + `coloredPrompt(forMode:forceColor:)`）和 `REPLLoop.swift`（添加 `ModeHolder`、动态 prompt）
- Story 9.1 修改了 `CLI.swift`（添加欢迎信息输出，调整 toolNames 计算顺序）
- 两个 Story 都保持了 `InputReading` 协议不变，确认协议抽象层的稳定性

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
