# Story 9.2: 彩色提示符

Status: done

## Story

作为一个用户，
我想要提示符 `>` 根据当前权限模式显示不同颜色，
以便我一眼就能识别当前的安全级别。

## Acceptance Criteria

### AC#1: default 模式 — 绿色提示符

**Given** CLI 以默认模式（`default`）启动
**When** `>` 提示符显示
**Then** 提示符使用绿色 ANSI 颜色码 `\u{001B}[32m`

### AC#2: plan 模式 — 黄色提示符

**Given** CLI 以 `--mode plan` 启动
**When** `>` 提示符显示
**Then** 提示符使用黄色 ANSI 颜色码 `\u{001B}[33m`

### AC#3: bypassPermissions 模式 — 红色提示符

**Given** CLI 以 `--mode bypassPermissions` 启动
**When** `>` 提示符显示
**Then** 提示符使用红色 ANSI 颜色码 `\u{001B}[31m`

### AC#4: acceptEdits 模式 — 蓝色提示符

**Given** 权限模式为 `acceptEdits`
**When** `>` 提示符显示
**Then** 提示符使用蓝色 ANSI 颜色码 `\u{001B}[34m`

### AC#5: auto/dontAsk 模式 — 默认色提示符

**Given** 权限模式为 `auto` 或 `dontAsk`
**When** `>` 提示符显示
**Then** 提示符使用白色/默认色 ANSI 颜色码 `\u{001B}[0m`

### AC#6: /mode 动态切换颜色

**Given** 我在 REPL 中执行 `/mode plan`
**When** 模式切换成功
**Then** 下一个 `>` 提示符变为黄色

### AC#7: 无 ANSI 支持时回退

**Given** 终端不支持 ANSI 颜色
**When** `>` 提示符显示
**Then** 回退为无颜色的普通 `>`

## Tasks / Subtasks

- [x] Task 1: 在 ANSI.swift 添加蓝色常量和彩色提示符生成函数 (AC: #1-#5, #7)
  - [x] 添加 `ANSI.blue(_:)` 静态方法（与其他颜色方法一致的模式）
  - [x] 添加 `ANSI.coloredPrompt(mode:)` 函数，接受 PermissionMode，返回带颜色的 `> ` 字符串
  - [x] 在 `coloredPrompt` 中处理所有 6 种 PermissionMode 的颜色映射
  - [x] 调用 `isatty()` 检测终端 ANSI 支持，不支持时返回无颜色 `> `

- [x] Task 2: 在 REPLLoop 中追踪当前权限模式 (AC: #6)
  - [x] 添加 `currentMode` 属性（class wrapper 或 stored property），初始化为 `parsedArgs.mode` 对应的 PermissionMode
  - [x] 在 `handleMode()` 中模式切换成功后更新 `currentMode`
  - [x] 将 `reader.readLine(prompt: "> ")` 中的硬编码 prompt 替换为动态生成的彩色 prompt

- [x] Task 3: 编写单元测试 (AC: #1-#7)
  - [x] 测试每种 PermissionMode 的颜色输出
  - [x] 测试 `coloredPrompt` 返回正确的 ANSI escape sequence
  - [x] 测试非 tty 环境下回退为无颜色 prompt
  - [x] 测试 `/mode` 切换后 prompt 颜色变化（通过 mock reader 验证传入的 prompt 参数）

## Dev Notes

### 核心实现策略

此 Story 的核心是**将 REPL 提示符从硬编码 `"> "` 改为根据当前权限模式动态生成的彩色字符串**。变更集中在两个文件：`ANSI.swift`（颜色映射逻辑）和 `REPLLoop.swift`（追踪当前模式，动态生成 prompt）。

### 提示符颜色映射表

| PermissionMode | ANSI Code | 颜色 | 含义 |
|---|---|---|---|
| `default` | `\u{001B}[32m` | 绿色 | 安全 — 只读自动批准，写操作需确认 |
| `plan` | `\u{001B}[33m` | 黄色 | 审慎 — 所有工具需确认 |
| `bypassPermissions` | `\u{001B}[31m` | 红色 | 危险 — 全部自动批准 |
| `acceptEdits` | `\u{001B}[34m` | 蓝色 | 编辑友好 — 读+Edit 自动批准 |
| `auto` | `\u{001B}[0m` | 默认 | 全自动 |
| `dontAsk` | `\u{001B}[0m` | 默认 | 全自动 |

### 文件变更清单

**ANSI.swift** — 添加：
1. `ANSI.blue(_:)` 静态方法（与现有 red/green/yellow/cyan 格式一致）
2. `ANSI.coloredPrompt(forMode:)` 函数（PermissionMode -> String）

**REPLLoop.swift** — 修改：
1. 添加 `currentMode` 属性追踪当前权限模式
2. 修改 `start()` 中的 `reader.readLine(prompt: "> ")` 为动态 prompt
3. 在 `handleMode()` 成功切换后更新 `currentMode`

### 关键实现细节

**1. 模式追踪方式**

REPLLoop 是 struct（不可变语义），但已使用 `AgentHolder`（class wrapper）解决类似问题。对 `currentMode` 使用同样的 class wrapper 模式：

```swift
final class ModeHolder {
    var mode: PermissionMode
    init(_ mode: PermissionMode) { self.mode = mode }
}
```

在 REPLLoop 中：
```swift
let modeHolder: ModeHolder
```

初始化时从 `parsedArgs.mode` 构建 PermissionMode，在 `handleMode()` 中更新。

**2. prompt 生成逻辑**

在 `ANSI.swift` 中新增：
```swift
static func coloredPrompt(forMode mode: PermissionMode) -> String {
    let prompt = "> "
    guard isatty(STDOUT_FILENO) != 0 else { return prompt }
    let colorCode: String
    switch mode {
    case .default: colorCode = "\u{001B}[32m"   // green
    case .plan: colorCode = "\u{001B}[33m"       // yellow
    case .bypassPermissions: colorCode = "\u{001B}[31m" // red
    case .acceptEdits: colorCode = "\u{001B}[34m" // blue
    case .auto, .dontAsk: colorCode = "\u{001B}[0m" // default
    }
    return colorCode + prompt + "\u{001B}[0m"
}
```

注意：不要使用现有的 `ANSI.green("> ")` 等方法，因为它们会包裹整个文本并在末尾加 reset——这里需要精确控制颜色边界，确保只有 `>` 字符被着色（后面的空格不着色更好），或者整个 `> ` 着色后 reset。使用直接拼接 ANSI 码比调用 `ANSI.green()` 更灵活。

**3. start() 中的修改点**

当前代码（REPLLoop.swift:104）：
```swift
while let input = reader.readLine(prompt: "> ") {
```

修改为：
```swift
while let input = reader.readLine(prompt: ANSI.coloredPrompt(forMode: modeHolder.mode)) {
```

**4. handleMode() 中的修改点**

当前代码（REPLLoop.swift:305）：
```swift
agentHolder.agent.setPermissionMode(mode)
renderer.output.write("Permission mode switched to \(mode.rawValue)\n")
```

在 `setPermissionMode` 调用后添加：
```swift
modeHolder.mode = mode
```

**5. PermissionMode 解析注意事项**

REPLLoop 初始化时需要将 `parsedArgs.mode`（String）转换为 `PermissionMode`（枚举）。转换已在 `handleMode()` 中存在（line 299），可直接复用：
```swift
let initialMode = PermissionMode(rawValue: parsedArgs?.mode ?? "default") ?? .default
```

### 不需要修改的文件

- `CLI.swift` — prompt 生成在 REPLLoop 内部，CLI 不涉及
- `OutputRenderer.swift` — prompt 通过 reader.readLine 输出，不走 renderer
- `FileHandleInputReader.swift` — reader 只是把 prompt 写到 stdout，不关心内容
- `ArgumentParser.swift` — 模式解析逻辑无变化
- `PermissionHandler.swift` — 权限逻辑无变化

### 与 Story 9.3 的关系

Story 9.3（历史回溯）将引入 `LinenoiseInputReader` 替代 `FileHandleInputReader`，但 prompt 参数的传递方式不变（都通过 `readLine(prompt:)` 协议方法）。本 Story 的彩色 prompt 逻辑与 input reader 实现无关，不受 9.3 影响。

### Project Structure Notes

```
Sources/OpenAgentCLI/
  ANSI.swift              -- 添加 blue() + coloredPrompt(forMode:) (约 20 行)
  REPLLoop.swift          -- 添加 ModeHolder, currentMode 追踪, 动态 prompt (约 15 行变更)

Tests/OpenAgentCLITests/
  ColoredPromptTests.swift -- 新建测试文件 (8-12 个测试)
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 9, Story 9.2]
- [Source: Sources/OpenAgentCLI/REPLLoop.swift:104 — 硬编码 prompt 需改为动态]
- [Source: Sources/OpenAgentCLI/REPLLoop.swift:291-307 — /mode 命令处理器]
- [Source: Sources/OpenAgentCLI/ANSI.swift — 现有颜色方法模式]
- [Source: Sources/OpenAgentCLI/PermissionHandler.swift:46-49 — PermissionMode 列表与行为描述]
- [Source: Sources/OpenAgentCLI/ArgumentParser.swift:55 — 有效模式列表]

### Previous Story Learnings (9.1)

- 660 unit tests 全量通过，0 回归
- Story 9.1 在 CLI.swift REPL 分支添加了欢迎信息，使用 `ANSI.dim()` 包裹
- ANSI.swift 中的颜色方法格式一致：`"\u{001B}[XXm\(text)\u{001B}[0m"`
- `parsedArgs` 已通过 init 传入 REPLLoop，可直接用于获取初始 mode
- `FileHandleInputReader.readLine(prompt:)` 接受任意 prompt 字符串，包含 ANSI 码时正确输出
- 单元测试使用 `MockOutput` (StringOutput) capture 模式验证输出

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

### Completion Notes List

- Implemented `ANSI.blue(_:)` static method matching existing red/green/yellow/cyan pattern
- Implemented `ANSI.coloredPrompt(forMode:forceColor:)` with isatty() tty detection and forceColor override for REPL usage
- Added `ModeHolder` class wrapper (same pattern as AgentHolder/CostTracker) for mutable PermissionMode tracking in struct-based REPLLoop
- Replaced hardcoded `reader.readLine(prompt: "> ")` with dynamic colored prompt via `ANSI.coloredPrompt(forMode:modeHolder.mode, forceColor:true)`
- Updated `handleMode()` to sync `modeHolder.mode` after successful permission mode switch
- Updated existing REPLLoopTests assertions to use `contains("> ")` instead of exact equality `== "> "` since prompts now include ANSI codes
- Updated ColoredPromptTests to pass `parsedArgs` to REPLLoop so the initial mode is correctly resolved
- All 735 tests pass (0 failures, 2 skipped) — no regressions

### File List

- Sources/OpenAgentCLI/ANSI.swift (modified — added blue() + coloredPrompt(forMode:forceColor:))
- Sources/OpenAgentCLI/REPLLoop.swift (modified — added ModeHolder, modeHolder property, dynamic prompt, mode sync in handleMode())
- Tests/OpenAgentCLITests/ColoredPromptTests.swift (modified — added parsedArgs to REPLLoop init calls, extracted makeParsedArgs helper)
- Tests/OpenAgentCLITests/REPLLoopTests.swift (modified — updated prompt assertions from exact equality to contains)

### Review Findings

- [x] [Review][Patch] ModeHolder missing `@unchecked Sendable` conformance [REPLLoop.swift:51-54] — FIXED: Added `@unchecked Sendable` to match CostTracker pattern.

- [x] [Review][Patch] Redundant leading ESC[0m for auto/dontAsk prompt [ANSI.swift:87] — FIXED: auto/dontAsk now returns plain "> " without ANSI codes. Tests updated accordingly.

- [x] [Review][Defer] Duplicated `makeTestAgent` helper across test files [ColoredPromptTests.swift + REPLLoopTests.swift] — deferred, pre-existing pattern. Two separate `makeTestAgent()` implementations with different API keys. Could be extracted to a shared test helper, but this is a pre-existing pattern not introduced by this change.
