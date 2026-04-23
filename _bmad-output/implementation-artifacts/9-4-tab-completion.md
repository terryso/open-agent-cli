# Story 9.4: Tab 命令补全

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为一个用户，
我想要在输入 `/` 命令时按 Tab 自动补全，
以便我不需要记住所有命令的精确拼写。

## Acceptance Criteria

### AC#1: 唯一匹配自动补全

**Given** 我处于 REPL 模式
**When** 我输入 `/m` 并按 Tab
**Then** 自动补全为 `/mode`（唯一匹配）

### AC#2: 列出所有命令

**Given** 我处于 REPL 模式
**When** 我输入 `/` 并按 Tab
**Then** 列出所有可用的 `/` 命令（`/help`, `/exit`, `/quit`, `/tools`, `/skills`, `/model`, `/mode`, `/cost`, `/clear`, `/sessions`, `/resume`, `/fork`, `/mcp`）

### AC#3: MCP 子命令补全

**Given** 我处于 REPL 模式
**When** 我输入 `/mcp ` 并按 Tab
**Then** 列出 MCP 子命令（`status`, `reconnect`）

### AC#4: Mode 子命令补全

**Given** 我处于 REPL 模式
**When** 我输入 `/mode ` 并按 Tab
**Then** 列出所有有效权限模式（`default`, `acceptEdits`, `bypassPermissions`, `plan`, `dontAsk`, `auto`）

### AC#5: 非 `/` 开头不触发

**Given** 我处于 REPL 模式
**When** 我输入非 `/` 开头的普通文本并按 Tab
**Then** 不触发补全，保持输入不变

### AC#6: 多个匹配前缀

**Given** 我处于 REPL 模式
**When** 我输入 `/s` 并按 Tab
**Then** 列出 `/sessions`, `/skills` 等匹配项
**And** 输入保持 `/s` 不变

## Tasks / Subtasks

- [x] Task 1: 在 LinenoiseInputReader 中添加补全回调注册方法 (AC: #1-#6)
  - [x] 在 `LinenoiseInputReader` 中添加 `setCompletionCallback(_ callback:)` 公共方法
  - [x] 该方法内部调用 `linenoise.setCompletionCallback(callback)`
  - [x] 暴露此方法而非直接暴露 `linenoise` 实例（保持封装性）

- [x] Task 2: 创建 TabCompletionProvider.swift (AC: #1-#6)
  - [x] 创建 `Sources/OpenAgentCLI/TabCompletionProvider.swift`
  - [x] 定义 `TabCompletionProvider` struct，包含补全候选列表和匹配逻辑
  - [x] 实现主命令列表：`["/help", "/exit", "/quit", "/tools", "/skills", "/model", "/mode", "/cost", "/clear", "/sessions", "/resume", "/fork", "/mcp"]`
  - [x] 实现 `/mcp` 子命令列表：`["status", "reconnect"]`
  - [x] 使用 `PermissionMode.allCases.map(\.rawValue)` 获取 mode 子命令列表（不硬编码）
  - [x] 实现 `completions(for input: String) -> [String]` 方法：
    - 输入不以 `/` 开头 → 返回空数组（AC#5）
    - 输入以 `/command `（含空格）开头且命令是 `/mcp` → 匹配 MCP 子命令前缀（AC#3）
    - 输入以 `/command `（含空格）开头且命令是 `/mode` → 匹配 PermissionMode 前缀（AC#4）
    - 其他以 `/` 开头 → 匹配主命令前缀（AC#1, #2, #6）

- [x] Task 3: 在 CLI.swift 中连接补全逻辑 (AC: #1-#6)
  - [x] 在 CLI.swift 的两处 REPL 分支（L127 skill REPL, L179 主 REPL）中：
    - 创建 `TabCompletionProvider` 实例
    - 在 `LinenoiseInputReader` 上注册补全回调
    - 回调闭包调用 `provider.completions(for: input)`
  - [x] 确保补全注册在 `repl.start()` 之前完成

- [x] Task 4: 编写单元测试 (AC: #1-#6)
  - [x] 测试 AC#1: 输入 `/m` 返回 `/mode`, `/model`, `/mcp`（3 个 `/m` 前缀匹配）
  - [x] 测试 AC#1: 输入 `/mo` 返回 `["/mode", "/model"]`
  - [x] 测试 AC#1: 输入 `/mod` 返回 `["/mode", "/model"]`（/mode 和 /model 都匹配）
  - [x] 测试 AC#2: 输入 `/` 返回所有 13 个命令
  - [x] 测试 AC#3: 输入 `/mcp s` 返回 `["status"]`
  - [x] 测试 AC#3: 输入 `/mcp ` 返回 `["status", "reconnect"]`
  - [x] 测试 AC#4: 输入 `/mode ` 返回所有 PermissionMode rawValue
  - [x] 测试 AC#4: 输入 `/mode pl` 返回 `["plan"]`
  - [x] 测试 AC#5: 输入 `hello` 返回 `[]`
  - [x] 测试 AC#5: 输入 `empty` 返回 `[]`
  - [x] 测试 AC#6: 输入 `/s` 返回 `["/sessions", "/skills"]`
  - [x] 测试未知子命令：输入 `/model ` 返回 `[]`（/model 后无子命令补全）
  - [x] 测试 `/mcp` 不完整输入：输入 `/mc` 返回 `["/mcp"]`
  - [x] 测试 LinenoiseInputReader.setCompletionCallback 存在且可调用

## Dev Notes

### 核心实现策略

此 Story 利用 Story 9.3 引入的 linenoise-swift 库的 `setCompletionCallback` API，为 REPL 添加 Tab 补全功能。linenoise 内部已处理 Tab 键的拦截和补全 UI 交互（循环显示、ESC 取消等），我们只需要提供正确的候选列表。

**关键架构决策**：将补全候选逻辑封装在独立的 `TabCompletionProvider` struct 中，而非嵌入 `LinenoiseInputReader`。原因：
1. `LinenoiseInputReader` 只负责底层 linenoise 封装（行编辑、历史），不包含业务逻辑
2. `TabCompletionProvider` 是纯函数逻辑（输入 → 候选列表），易于测试
3. `CLI.swift` 作为编排层连接两者

### linenoise-swift 补全 API 行为

linenoise-swift 的 `setCompletionCallback` 接受 `(String) -> [String]` 闭包：

```swift
linenoise.setCompletionCallback { currentBuffer in
    return ["completion1", "completion2"]
}
```

**关键行为细节**（阅读 `linenoise.swift:366-422` 源码）：

1. **回调参数**：`editState.currentBuffer`（当前输入缓冲区的完整文本）
2. **空数组**：linenoise 播放 beep 音（`\x07`），不做任何操作
3. **单条匹配**：linenoise 自动替换输入缓冲区为该匹配项
4. **多条匹配**：linenoise 循环显示匹配项（每按一次 Tab 切换到下一个），ESC 恢复原始输入
5. **linenoise 不做前缀过滤**：回调收到的 `currentBuffer` 是完整输入文本，补全逻辑需要自行做前缀匹配
6. **补全替换是整行替换**：`editState.buffer = completions[completionIndex]`，不是追加

**重要**：linenoise 的补全行为意味着我们的回调应该返回**完整的目标字符串**（如 `"/mode"`），而不是仅返回追加部分（如 `"ode"`）。linenoise 会将整个 buffer 替换为返回的字符串。

### 补全逻辑设计

```
输入文本                  → 返回值
──────────────────────────────────────────
"hello"                  → []          （非 / 开头，AC#5）
"/"                      → [所有13个命令]（AC#2）
"/m"                     → ["/mode", "/model"]
"/s"                     → ["/sessions", "/skills"]（AC#6）
"/mod"                   → ["/mode"]   （AC#1，唯一匹配）
"/mcp "                  → ["status", "reconnect"]（AC#3）
"/mcp s"                 → ["status"]
"/mode "                 → ["default", "acceptEdits", ...]（AC#4）
"/mode pl"               → ["plan"]
"/model "                → []          （/model 无子命令补全）
"/tools"                 → ["/tools"]  （精确匹配也返回）
```

**注意**：`/exit` 和 `/quit` 都以 `/` 开头，输入 `/q` 时只匹配 `/quit`。但 `/e` 会匹配 `/exit`。这些都是正确的。

### 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `TabCompletionProvider.swift` | **新建** | ~60 行，纯逻辑 struct |
| `LinenoiseInputReader.swift` | **修改** | 添加 `setCompletionCallback` 公共方法（~3 行） |
| `CLI.swift` | **修改** | 两处 REPL 分支注册补全回调（~6 行） |
| `TabCompletionTests.swift` | **新建** | ~15-20 个测试用例 |

### LinenoiseInputReader 修改

在 `LinenoiseInputReader` 中添加一个公共方法：

```swift
/// 注册 Tab 补全回调。
///
/// 封装 linenoise-swift 的 `setCompletionCallback`，保持 linenoise 实例私有。
/// 回调接收当前输入文本，返回匹配的补全候选列表。
func setCompletionCallback(_ callback: @escaping (String) -> [String]) {
    linenoise.setCompletionCallback(callback)
}
```

### CLI.swift 修改

在 CLI.swift 两处 REPL 入口（L127 和 L179），在创建 `reader` 后、创建 `repl` 前，注册补全：

```swift
let reader = LinenoiseInputReader()
let completionProvider = TabCompletionProvider()
reader.setCompletionCallback { input in
    completionProvider.completions(for: input)
}
```

两处都需要添加：
1. **L127 区域**（skill REPL 分支）：`--skill` 后进入 REPL
2. **L179 区域**（主 REPL 分支）：标准 REPL 入口

### TabCompletionProvider 实现

```swift
import Foundation
import OpenAgentSDK

/// 提供 REPL 命令的 Tab 补全候选列表。
///
/// 纯逻辑组件，不持有状态，易于测试。
/// 根据当前输入前缀返回匹配的补全选项。
struct TabCompletionProvider {

    /// 所有可用的 slash 命令。
    private let commands: [String] = [
        "/help", "/exit", "/quit", "/tools", "/skills",
        "/model", "/mode", "/cost", "/clear",
        "/sessions", "/resume", "/fork", "/mcp"
    ]

    /// /mcp 子命令。
    private let mcpSubcommands: [String] = ["status", "reconnect"]

    /// 所有有效权限模式（从 SDK 获取，不硬编码）。
    private let modes: [String] = PermissionMode.allCases.map(\.rawValue)

    /// 根据当前输入返回补全候选列表。
    ///
    /// - Parameter input: 当前输入缓冲区的完整文本。
    /// - Returns: 匹配的补全候选列表（空数组表示无补全）。
    func completions(for input: String) -> [String] {
        // 非 / 开头：不补全（AC#5）
        guard input.hasPrefix("/") else { return [] }

        // 检查是否有子命令上下文
        let parts = input.split(separator: " ", maxSplits: 1)
        let command = String(parts[0]).lowercased()

        if parts.count > 1 {
            // 已有空格 → 进入子命令模式
            let subPrefix = String(parts[1])

            switch command {
            case "/mcp":
                return mcpSubcommands.filter { $0.hasPrefix(subPrefix) }
            case "/mode":
                return modes.filter { $0.hasPrefix(subPrefix) }
            default:
                return []
            }
        }

        // 主命令前缀匹配
        return commands.filter { $0.hasPrefix(input.lowercased()) }
    }
}
```

### 关键实现细节

**1. 补全候选的大小写处理**

用户输入 `/M` 应匹配 `/mode`。使用 `input.lowercased()` 进行比较，但返回原始大小写的命令名（命令都是小写）。

**2. /mode 子命令使用 SDK 枚举**

使用 `PermissionMode.allCases.map(\.rawValue)` 而非硬编码模式列表。这确保新增模式时自动支持补全。

**3. 精确匹配也返回**

输入 `/help` 精确匹配时仍返回 `["/help"]`。linenoise 处理逻辑：buffer 已等于匹配项时，显示不变，用户按回车发送。这是正确行为。

**4. 不修改 REPLLoop.swift**

`REPLLoop.swift` 完全不需要修改。补全是输入层的功能，通过 linenoise 回调在用户按 Tab 时触发，REPLLoop 只在用户按回车后通过 `readLine(prompt:)` 收到最终文本。

**5. 不修改 Package.swift**

linenoise-swift 依赖已在 Story 9.3 中添加，`LineNoise` 模块已可 import。

**6. 不修改 ANSI.swift**

补全功能不涉及颜色输出。linenoise 的 `completeLine` 方法直接操作终端 buffer。

### 不需要修改的文件

- `REPLLoop.swift` — 补全在输入层完成，不经过 REPLLoop
- `ANSI.swift` — 无颜色输出需求
- `Package.swift` — linenoise-swift 依赖已存在
- `ArgumentParser.swift` — 无新参数
- `OutputRenderer.swift` — 无输出变更
- `PermissionHandler.swift` — 权限逻辑不变
- `SignalHandler.swift` — 中断处理不变

### 与后续 Story 的关系

- **Story 9.5（多行输入）** 将在 `REPLLoop` 层实现多行状态机。Tab 补全在单行输入层工作，多行模式下每行仍可使用补全。`TabCompletionProvider` 不需要修改。

### Project Structure Notes

```
Sources/OpenAgentCLI/
  TabCompletionProvider.swift    -- 新建 (~60 行)，纯逻辑补全引擎
  LinenoiseInputReader.swift     -- 修改 (+3 行)，暴露 setCompletionCallback
  CLI.swift                      -- 修改 2 处 REPL 分支 (+~6 行)

Tests/OpenAgentCLITests/
  TabCompletionTests.swift       -- 新建测试文件 (15-20 个测试)
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 9, Story 9.4]
- [Source: Sources/OpenAgentCLI/LinenoiseInputReader.swift — linenoise 封装层]
- [Source: Sources/OpenAgentCLI/CLI.swift:127 — skill REPL 分支]
- [Source: Sources/OpenAgentCLI/CLI.swift:179 — 主 REPL 分支]
- [Source: Sources/OpenAgentCLI/REPLLoop.swift:187-220 — handleSlashCommand 命令列表]
- [Source: .build/checkouts/linenoise-swift/Sources/LineNoise/linenoise.swift:103 — setCompletionCallback API]
- [Source: .build/checkouts/linenoise-swift/Sources/LineNoise/linenoise.swift:366-422 — completeLine 内部实现]
- [Source: OpenAgentSDK/Types/PermissionTypes.swift — PermissionMode enum with allCases]
- [Source: _bmad-output/implementation-artifacts/9-3-command-history.md — Story 9.3 实现记录]

### Previous Story Learnings (9.1, 9.2, 9.3)

- 735+ unit tests 全量通过，0 回归
- Story 9.3 引入了 linenoise-swift SPM 依赖和 `LinenoiseInputReader`
- `InputReading` 协议只有 `readLine(prompt:) -> String?` 一个方法
- `REPLLoop` 是 struct，不可变语义，使用 class wrapper 处理可变状态
- `LinenoiseInputReader` 是 `final class`，符合 `@unchecked Sendable`，linenoise 实例是 `private let`
- CLI.swift 有两处 REPL 入口：L127（skill REPL）和 L179（主 REPL），两处都需要修改
- 单元测试使用 `MockInputReader` 模拟输入，`MockTextOutputStream` 捕获输出
- Story 9.3 的 Dev Notes 已预见到本 Story：需要在 LinenoiseInputReader 上调用 `linenoise.setCompletionCallback(...)`
- ANSI prompt 颜色在 linenoise 中可能有光标偏移问题（Story 9.3 已记录的已知限制），但不影响补全功能

### Git Intelligence (Recent Commits)

```
cf89f3f feat: add command history with linenoise-swift — Story 9.3
58e516c feat: add colored REPL prompt based on permission mode — Story 9.2
66047e1 feat: add REPL welcome screen — Story 9.1
```

- Story 9.3 新增 `LinenoiseInputReader.swift`（111 行）和 `CommandHistoryTests.swift`（487 行）
- Story 9.3 修改 `Package.swift`（+5 行 linenoise-swift 依赖）、`CLI.swift`（2 处 reader 替换）
- Story 9.2 修改 `ANSI.swift` 和 `REPLLoop.swift`（添加 `ModeHolder`、动态 prompt）
- Story 9.1 修改 `CLI.swift`（添加欢迎信息输出）

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No debug issues encountered during implementation.

### Completion Notes List

- Task 1: Added `setCompletionCallback` method to `LinenoiseInputReader` wrapping linenoise's internal API. 3 lines added.
- Task 2: Created `TabCompletionProvider.swift` as a pure-logic struct. Uses `input.range(of: " ")` instead of `String.split` to correctly handle trailing-space subcommand detection (e.g., "/mcp " → empty sub-prefix matches all subcommands). PermissionMode values sourced from SDK via `PermissionMode.allCases.map(\.rawValue)`.
- Task 3: Wired `TabCompletionProvider` in both CLI.swift REPL entry points (skill REPL at ~L127 and main REPL at ~L179). Completion callback registered before `repl.start()`.
- Task 4: Fixed 2 ATDD test expectations that had incorrect prefix match counts: `/m` matches 3 commands (not 2, because `/mcp` also starts with `/m`), and `/mod` matches 2 commands (not 1, because `/model` also starts with `/mod`).
- All 27 TabCompletionTests pass. Full suite: 777 tests pass, 0 failures, 2 skipped.

### Change Log

- 2026-04-24: Implemented Story 9.4 Tab Completion — added TabCompletionProvider, setCompletionCallback on LinenoiseInputReader, wired in CLI.swift. Fixed ATDD test expectations for `/m` and `/mod` prefix matching.

### File List

| File | Operation | Description |
|------|-----------|-------------|
| `Sources/OpenAgentCLI/TabCompletionProvider.swift` | Created | Pure-logic struct providing Tab completion candidates (~52 lines) |
| `Sources/OpenAgentCLI/LinenoiseInputReader.swift` | Modified | Added `setCompletionCallback` public method (+10 lines) |
| `Sources/OpenAgentCLI/CLI.swift` | Modified | Wired TabCompletionProvider at 2 REPL entry points (+8 lines) |
| `Tests/OpenAgentCLITests/TabCompletionTests.swift` | Modified | Fixed 2 test expectations for `/m` and `/mod` prefix matching |
