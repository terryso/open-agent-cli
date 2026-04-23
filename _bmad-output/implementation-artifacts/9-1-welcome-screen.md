# Story 9.1: 欢迎界面

Status: done

## Story

作为一个用户，
我想要在 CLI 启动时看到当前配置概要，
以便我一眼就知道当前模型、工具和权限设置。

## Acceptance Criteria

### AC#1: 默认 REPL 启动显示欢迎信息

**Given** CLI 以默认设置启动 REPL 模式
**When** REPL 就绪（`>` 提示符出现前）
**Then** 显示欢迎信息，包含：
  - CLI 版本（`CLIVersion.current`）
  - 当前模型名
  - 已加载工具数量
  - 当前权限模式

**示例输出：**
```
openagent v1.0.0 | model: glm-5.1 | tools: 10 | mode: default
```

### AC#2: --quiet 模式不显示欢迎信息

**Given** CLI 以 `--quiet` 模式启动
**When** REPL 就绪
**Then** 不显示欢迎信息

### AC#3: --output json 模式不显示欢迎信息

**Given** CLI 以 `--output json` 模式启动
**When** REPL 就绪
**Then** 不显示欢迎信息

### AC#4: 单次提问模式不显示欢迎信息

**Given** CLI 以单次提问模式启动（带位置参数）
**When** 执行查询
**Then** 不显示欢迎信息

## Tasks / Subtasks

- [x] Task 1: 在 CLI.swift REPL 启动路径添加欢迎信息输出 (AC: #1)
  - [x] 在 `CLI.swift:177` REPL 模式分支中，`REPLLoop.start()` 之前，添加 `renderWelcome()` 调用
  - [x] 欢迎信息格式：`openagent {version} | model: {model} | tools: {count} | mode: {mode}`
  - [x] 使用 `OutputRenderer.output.write()` 输出（保持与现有代码一致）
  - [x] 使用 `ANSI.dim()` 包裹欢迎行，使其视觉上不干扰主输出

- [x] Task 2: 添加条件守卫，确保欢迎信息仅在交互 REPL 模式显示 (AC: #2, #3, #4)
  - [x] 检查 `!args.quiet && args.output != "json"` — 已有此模式（CLI.swift:75）
  - [x] 单次提问模式（`args.prompt != nil`）不走 REPL 分支，天然排除
  - [x] 欢迎信息放在 `"[Restoring last session...]\n"` 之后——恢复提示优先

- [x] Task 3: 编写单元测试 (AC: #1-#4)
  - [x] 测试默认 REPL 模式显示包含版本、模型、工具数、模式的欢迎行
  - [x] 测试 `--quiet` 模式不输出欢迎信息
  - [x] 测试 `--output json` 模式不输出欢迎信息
  - [x] 使用 `StringOutput` capture 模式验证输出内容

- [x] Task 4: 验证与现有输出不冲突 (cross-cutting)
  - [x] 确认欢迎信息不会与 MCP/Hooks 配置提示（CLI.swift:76-85）冲突
  - [x] 确认欢迎信息在 session restore 提示之后显示
  - [x] 运行 `swift test` 确认无回归

## Dev Notes

### 插入位置分析

**CLI.swift:177-193** 是 REPL 模式的入口点：

```swift
} else if args.skillName == nil {
    // REPL mode
    let reader = FileHandleInputReader()
    let renderer = OutputRenderer(quiet: args.quiet)

    // Show restore hint when auto-restore is active
    if !args.noRestore && args.sessionId == nil {
        renderer.output.write("[Restoring last session...]\n")
    }

    // <<< 欢迎信息应插入此处 >>>

    let toolNames = AgentFactory.computeToolPool(...)
    let repl = REPLLoop(...)
    await repl.start()
    await closeAgentSafely(agent)
}
```

欢迎信息放在 restore 提示之后、REPLLoop 创建之前最合理。工具数量 `toolNames.count` 在计算后即可用于欢迎信息。

### 数据来源

| 信息 | 来源 | 可用位置 |
|------|------|---------|
| CLI 版本 | `CLIVersion.current` | 全局 |
| 模型名 | `args.model` | CLI.swift |
| 工具数量 | `toolNames.count` | CLI.swift:188 |
| 权限模式 | `args.mode` | CLI.swift |
| quiet 标志 | `args.quiet` | CLI.swift |
| output 模式 | `args.output` | CLI.swift |

### 实现策略

欢迎信息是一个简单的格式化字符串输出，不需要新建文件或类。直接在 `CLI.swift` 的 REPL 分支中添加几行即可：

```swift
// Welcome screen (Story 9.1)
if !args.quiet && args.output != "json" {
    let welcomeLine = "openagent \(CLIVersion.current) | model: \(args.model) | tools: \(toolNames.count) | mode: \(args.mode)\n"
    renderer.output.write(ANSI.dim(welcomeLine))
}
```

注意：`toolNames` 需要在欢迎信息之前计算。当前代码中 `toolNames` 在 restore 提示之后才计算。需要将 `computeToolPool` 调用提前到欢迎信息之前，或者将欢迎信息放在 `toolNames` 计算之后。推荐后者——调整代码顺序，先计算 `toolNames`，再输出 restore 提示和欢迎信息。

### ANSI 样式选择

使用 `ANSI.dim()` 包裹整行欢迎信息，与 `[system]` 消息的视觉权重类似——信息性但不抢眼。这与 epics.md 中"欢迎界面"的定位（用户价值：中）匹配。

### 不需要修改的文件

- `REPLLoop.swift` — 欢迎信息在 REPL 启动前显示，不涉及 REPL 循环逻辑
- `OutputRenderer.swift` — 直接使用 `renderer.output.write()`，不需要新的渲染方法
- `Version.swift` — 已有 `CLIVersion.current`
- `ANSI.swift` — 已有 `dim()` 方法

### Project Structure Notes

```
Sources/OpenAgentCLI/
  CLI.swift              -- 唯一需要修改的源文件（添加欢迎信息输出 + 调整 toolNames 计算顺序）

Tests/OpenAgentCLITests/
  WelcomeScreenTests.swift  -- 新建测试文件（或添加到 CLIIntegrationTests.swift）
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 9, Story 9.1]
- [Source: _bmad-output/planning-artifacts/next-phase-backlog.md — 9.1 欢迎界面]
- [Source: Sources/OpenAgentCLI/CLI.swift:177-193 — REPL 模式入口点]
- [Source: Sources/OpenAgentCLI/CLI.swift:75-85 — 现有 MCP/Hooks 启动提示模式]
- [Source: Sources/OpenAgentCLI/Version.swift — CLIVersion.current]
- [Source: Sources/OpenAgentCLI/ANSI.swift — dim() 方法]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (GLM-5.1)

### Debug Log References

- 660 unit tests pass, 0 failures
- 1 pre-existing E2E flake (testMultiTurn_toolCallVisibility) unrelated to this story

### Completion Notes List

- AC#1: Welcome line displays version (`CLIVersion.current`), model (`args.model`), tool count (`toolNames.count`), mode (`args.mode`) in format `openagent {v} | model: {m} | tools: {c} | mode: {m}`
- AC#2: Guarded by `!args.quiet` — welcome suppressed in quiet mode
- AC#3: Guarded by `args.output != "json"` — welcome suppressed in JSON output mode
- AC#4: Single-shot mode enters the `if let prompt` branch at CLI.swift:137, never reaches the REPL branch — naturally excluded
- Implementation: 5 lines added to CLI.swift (lines 189-193), no new files needed
- ANSI.dim() wrapping applied for subtle visual weight
- toolNames computation moved before welcome output to provide tool count
- Welcome displays after session restore hint, before REPLLoop creation

### File List

- `Sources/OpenAgentCLI/CLI.swift` — Added welcome screen output in REPL mode branch (lines 189-193)
- `Tests/OpenAgentCLITests/WelcomeScreenTests.swift` — 11 ATDD specification tests (NEW)
- `_bmad-output/implementation-artifacts/9-1-welcome-screen.md` — Updated status, tasks, dev agent record
- `_bmad-output/implementation-artifacts/atdd-checklist-9-1.md` — ATDD checklist (NEW)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — Updated 9-1 status

### Change Log

- 2026-04-23: Story 9-1 implementation complete. Added welcome screen to CLI.swift REPL startup path, 11 ATDD tests, 660 unit tests pass with 0 regressions.
