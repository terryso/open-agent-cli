# Story 9.5: 多行输入

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为一个用户，
我想要用 `\` 续行或 `"""` 包裹输入多行文本，
以便我可以方便地粘贴代码或多段提示词。

## Acceptance Criteria

### AC#1: 反斜杠续行

**Given** 我处于 REPL 模式
**When** 我输入 `这是一个长问题 \` 并按回车
**Then** 提示符变为 `...>`
**And** 我可以继续输入下一行
**When** 输入完整内容后按回车（无 `\` 结尾）
**Then** 所有行合并为一个完整输入发送给 Agent

### AC#2: 三引号多行模式

**Given** 我处于 REPL 模式
**When** 我输入 `"""` 并按回车
**Then** 提示符变为 `...>`，进入多行模式
**When** 我输入多行内容后再输入 `"""` 并按回车
**Then** `"""` 之间的所有内容（包括换行）作为一个完整输入发送

### AC#3: Ctrl+C 取消多行输入

**Given** 我处于多行模式（`...>` 提示符）
**When** 我按 Ctrl+C
**Then** 取消当前多行输入，回到 `>` 提示符

### AC#4: 末尾空白容忍

**Given** 我处于 REPL 模式
**When** 我输入以 `\` 结尾但后面有空白字符（如 `hello \  `）
**Then** 忽略末尾空白，正确识别为续行

## Tasks / Subtasks

- [x] Task 1: 在 REPLLoop 中添加多行状态机 (AC: #1, #2, #3, #4)
  - [x] 在 `start()` 方法的 while 循环中，将单行输入逻辑替换为多行感知逻辑
  - [x] 添加 continuation prompt 生成：基于当前 mode 颜色的 `...>` 提示符
  - [x] 实现 `\` 续行检测：`trimmed.hasSuffix("\\")` 但需先 rstrip 空白再检查
  - [x] 实现 `"""` 多行模式：独立一行的 `"""` 进入多行，再次 `"""` 退出
  - [x] 累积行缓冲：使用 `[String]` 收集所有续行内容
  - [x] 合并发送：续行时去掉每行末尾的 `\`，用换行符连接；`"""` 模式保留原始换行

- [x] Task 2: 添加 continuation prompt 颜色支持 (AC: #1, #2)
  - [x] 在 `ANSI.swift` 中添加 `coloredContinuationPrompt(forMode:forceColor:)` 方法
  - [x] 与 `coloredPrompt` 使用相同颜色映射，但显示 `...>` 而非 `> `

- [x] Task 3: 处理 Ctrl+C 取消多行 (AC: #3)
  - [x] 在多行模式下，`readLine` 返回空字符串（Ctrl+C 信号）时清空缓冲区并退出多行模式
  - [x] 输出 `^C` 并回到主 `>` 提示符

- [x] Task 4: 编写单元测试 (AC: #1, #2, #3, #4)
  - [x] 测试 AC#1: 反斜杠续行——MockInputReader 返回 `"hello \\"` → `"world"`，验证发送 `"hello\nworld"`
  - [x] 测试 AC#1: 多段续行——3 段续行后终止，验证合并正确
  - [x] 测试 AC#2: `"""` 多行模式——输入 `"""` + 多行 + `"""`，验证发送完整内容含换行
  - [x] 测试 AC#3: Ctrl+C 取消——多行模式下返回空字符串，验证缓冲清空
  - [x] 测试 AC#4: 末尾空白容忍——`"hello \\  "` (反斜杠后有空白)，验证识别为续行
  - [x] 测试续行中非空白空行——中间行是空字符串（直接回车），应继续累积
  - [x] 测试空 `"""` 模式——`"""` 紧跟 `"""`，发送空字符串（被 guard 过滤）

## Dev Notes

### 核心架构决策：在 REPLLoop 层实现多行状态机

linenoise 是行导向的——每次 `readLine(prompt:)` 返回一行文本。多行逻辑**必须**在 REPLLoop 层实现，而不是修改 `LinenoiseInputReader`。这符合已有的关注点分离：

- `LinenoiseInputReader` — 底层行编辑、历史、Tab 补全
- `REPLLoop` — 业务逻辑（命令处理、多行状态机、流式渲染）
- `TabCompletionProvider` — 补全候选计算

### 多行状态机设计

在 `start()` 方法的 while 循环中，将现有的单行处理替换为状态机：

```swift
func start() async {
    var multilineBuffer: [String] = []
    var inMultiline = false
    var inTripleQuote = false

    while let rawInput = reader.readLine(prompt: currentPrompt(inMultiline: inMultiline || inTripleQuote)) {
        // Ctrl+C handling (readLine returns "" on Ctrl+C via LinenoiseInputReader)
        if rawInput.isEmpty {
            if inMultiline || inTripleQuote {
                renderer.output.write("^C\n")
                multilineBuffer = []
                inMultiline = false
                inTripleQuote = false
                continue  // Back to main prompt
            }
            // Normal empty line at main prompt
            continue
        }

        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)

        // --- Triple-quote mode ---
        if inTripleQuote {
            if trimmed == "\"\"\"" {
                // End triple-quote mode
                let fullInput = multilineBuffer.joined(separator: "\n")
                multilineBuffer = []
                inTripleQuote = false
                guard !fullInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                // Process fullInput as normal (slash command or agent query)
                await processInput(fullInput)
            } else {
                multilineBuffer.append(rawInput)  // Preserve original indentation
            }
            continue
        }

        // --- Backslash continuation ---
        if inMultiline {
            let rstripped = rawInput.trimmingCharacters(in: .whitespaces)
            if rstripped.hasSuffix("\\") {
                // Continue accumulating, strip trailing backslash
                let lineWithoutSlash = String(rstripped.dropLast())
                multilineBuffer.append(lineWithoutSlash)
            } else {
                // Terminate continuation
                multilineBuffer.append(rawInput)
                let fullInput = multilineBuffer.joined(separator: "\n")
                multilineBuffer = []
                inMultiline = false
                guard !fullInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                await processInput(fullInput)
            }
            continue
        }

        // --- Not in any multiline mode: check for entry ---
        // Triple-quote entry: entire trimmed line is """
        if trimmed == "\"\"\"" {
            inTripleQuote = true
            multilineBuffer = []
            continue
        }

        // Backslash entry: line ends with \ (after rstripping whitespace)
        let rstripped = rawInput.trimmingCharacters(in: .whitespaces)
        if rstripped.hasSuffix("\\") && trimmed != "\\" {
            let lineWithoutSlash = String(rstripped.dropLast())
            multilineBuffer = [lineWithoutSlash]
            inMultiline = true
            continue
        }

        // Normal single-line input (existing behavior)
        guard !trimmed.isEmpty else { continue }
        await processInput(trimmed)
    }
}
```

**关键设计细节：**

1. **两个独立的多行模式**：`inMultiline`（反斜杠续行）和 `inTripleQuote`（三引号模式），互斥
2. **Ctrl+C 取消**：linenoise 在 Ctrl+C 时返回空字符串（`LinenoiseInputReader` 的 `readLine` catch `CTRL_C` 返回 `""`）。在多行模式下，空输入清空缓冲区并回到主提示符
3. **续行合并**：去掉每行末尾的 `\`，用 `\n` 连接。保留每行原始缩进
4. **三引号合并**：保留所有原始行内容（包括空白行和缩进），用 `\n` 连接
5. **slash 命令只在最终合并后处理**：多行内容合并后才检查是否是 `/` 命令，避免续行中间被误判为命令

### continuation prompt

需要在 `ANSI.swift` 中添加一个新方法 `coloredContinuationPrompt`，与 `coloredPrompt` 相同的颜色映射，但显示 `...>`：

```swift
/// Generate a colored continuation prompt for multiline input mode.
///
/// Uses the same color mapping as `coloredPrompt(forMode:forceColor:)` but
/// displays `"...>"` instead of `"> "`.
static func coloredContinuationPrompt(forMode mode: PermissionMode, forceColor: Bool = false) -> String {
    let prompt = "...>"
    guard forceColor || isatty(STDOUT_FILENO) != 0 else { return prompt + " " }
    let colorCode: String
    switch mode {
    case .default: colorCode = "\u{001B}[32m"
    case .plan: colorCode = "\u{001B}[33m"
    case .bypassPermissions: colorCode = "\u{001B}[31m"
    case .acceptEdits: colorCode = "\u{001B}[34m"
    case .auto, .dontAsk: return prompt + " "
    }
    return colorCode + prompt + " " + "\u{001B}[0m"
}
```

### 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `REPLLoop.swift` | **修改** | 重构 `start()` 方法，添加多行状态机 (~60 行新增) |
| `ANSI.swift` | **修改** | 添加 `coloredContinuationPrompt` 方法 (~15 行) |
| `MultilineInputTests.swift` | **新建** | ~10-15 个测试用例 |

### 不需要修改的文件

- `LinenoiseInputReader.swift` — linenoise 保持行导向，多行逻辑在 REPLLoop 层
- `TabCompletionProvider.swift` — Tab 补全在单行输入层工作，多行模式下每行仍可使用补全
- `CLI.swift` — REPL 入口不变
- `Package.swift` — 无新依赖
- `OutputRenderer.swift` — 无输出变更

### 关键实现细节

**1. 续行中空行的处理**

在反斜杠续行模式下，空行（直接回车）不应终止续行。空行应作为内容的一部分累积。`readLine` 返回空字符串有两种情况：
- Ctrl+C → 取消续行（AC#3）
- 用户直接按回车 → 空行内容，继续累积

**区分方法**：`LinenoiseInputReader` 在 Ctrl+C 时返回 `""`，但 linenoise 正常情况下用户按回车也会返回空字符串。这两者在 `LinenoiseInputReader.readLine` 中是不同的：Ctrl+C 走 `catch LinenoiseError.CTRL_C` 分支返回 `""`，正常回车返回 linenoise 读取到的内容（可能是空字符串 `""`）。

**问题**：这两者返回值相同（都是 `""`），无法在 REPLLoop 层区分。

**解决方案**：现有的 `start()` 方法已经通过 `guard !trimmed.isEmpty else { continue }` 处理了空行。在多行模式下：
- 续行中按回车（空行）→ `rawInput == ""`，这不是 Ctrl+C，而是空内容。在续行模式下，空行应继续累积（`\n` 连接会产生连续换行）
- 但 Ctrl+C 也返回 `""`

**最终方案**：在 `LinenoiseInputReader` 中增加一个标志位来区分 Ctrl+C 和空行输入。或者，更简单的方案：**续行模式下空行直接累积**（Ctrl+C 行为不变，只是空行也被累积）。但 Ctrl+C 应该取消而不是累积。

**最佳方案**：修改 `InputReading` 协议或 `LinenoiseInputReader` 来区分 Ctrl+C 和空行。但这会影响所有使用方。更简单的方法是：在 `LinenoiseInputReader` 上暴露一个 `lastWasInterrupt: Bool` 属性：

```swift
// LinenoiseInputReader 中添加
private(set) var lastWasInterrupt: Bool = false

func readLine(prompt: String) -> String? {
    do {
        let line = try linenoise.getLine(prompt: prompt)
        lastWasInterrupt = false
        // ...
    } catch LinenoiseError.CTRL_C {
        lastWasInterrupt = true
        return ""
    } catch {
        lastWasInterrupt = false
        return nil
    }
}
```

然后 REPLLoop 检查 `reader.lastWasInterrupt` 来区分。但这要求 `reader` 是 `LinenoiseInputReader` 类型，而非 `InputReading` 协议。

**更优方案**：在 `InputReading` 协议中不需要修改。而是在续行模式下，空行继续累积。Ctrl+C 由 `SignalHandler.check()` 检测（Story 5.3 已建立信号处理机制）。当 Ctrl+C 在 linenoise 等待输入时被按下，linenoise 抛出 `CTRL_C` 错误，`readLine` 返回 `""`。然后信号处理器的状态也被设置。在多行模式下检查 `SignalHandler.check()` 是否为 `.interrupt`：

```swift
if rawInput.isEmpty {
    let sigCheck = SignalHandler.check()
    if (inMultiline || inTripleQuote) && sigCheck == .interrupt {
        // Ctrl+C cancel multiline
        renderer.output.write("^C\n")
        multilineBuffer = []
        inMultiline = false
        inTripleQuote = false
        continue
    }
    // In multiline mode, empty line is just content
    if inMultiline || inTripleQuote {
        multilineBuffer.append("")
        continue
    }
    // At main prompt, ignore empty line
    continue
}
```

**注意**：`SignalHandler.check()` 在 linenoise 的 Ctrl+C 处理中是否会被正确设置？需要验证。如果 linenoise 的 Ctrl+C 不触发 SIGINT handler（linenoise 可能自行拦截了信号），则需要换用 `lastWasInterrupt` 方案。

**推荐实现路径**：先用 `SignalHandler.check()` 方案实现。如果测试中发现 Ctrl+C 时不触发信号处理器，则切换到 `lastWasInterrupt` 属性方案。

**2. 斜杠命令在多行内容中的处理**

只有合并后的完整输入才检查是否是 `/` 命令。续行模式下不可能输入斜杠命令（因为所有行被合并）。三引号模式下同理。

**3. 历史记录**

多行输入合并后作为一个整体添加到历史。linenoise 的 `addHistory` 在 `LinenoiseInputReader.readLine` 中自动调用，但多行模式下中间行也会被记录。这可能导致历史中出现不完整片段。

**解决方案**：最终合并后的输入由 `LinenoiseInputReader.readLine` 中的 `addHistory` 自动记录最后一次 `readLine` 调用的内容。中间行的历史记录不可避免（linenoise 在每次 `getLine` 返回时都不知道是否在多行模式中），但这是可接受的——用户在历史中看到的是每一行的单独记录，而不是合并后的多行内容。这与大多数 shell 的行为一致。

**4. Tab 补全在多行模式下**

linenoise 的 Tab 补全在每行输入时都可用。多行模式不影响补全功能——每行仍是独立的 linenoise `getLine` 调用。

### 重构 start() 方法

现有的 `start()` 方法（~60 行）将增长到约 100 行。建议将输入处理逻辑提取为独立方法以保持可读性：

```swift
/// Process a complete input (after multiline merging if applicable).
/// Returns true if the REPL should exit.
private func processInput(_ input: String) async -> Bool {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }

    // Signal check
    let preCheck = SignalHandler.check()
    if preCheck == .terminate || preCheck == .forceExit { return true }
    if preCheck == .interrupt {
        renderer.output.write("^C\n")
        return false
    }

    // Slash commands
    if trimmed.hasPrefix("/") {
        return await handleSlashCommand(trimmed)
    }

    // Agent query with streaming
    let stream = agentHolder.agent.stream(trimmed)
    for await message in stream {
        if case .result(let data) = message {
            costTracker.cumulativeCostUsd += data.totalCostUsd
            if let usage = data.usage {
                costTracker.cumulativeInputTokens += usage.inputTokens
                costTracker.cumulativeOutputTokens += usage.outputTokens
            }
        }
        let event = SignalHandler.check()
        if event == .interrupt || event == .forceExit || event == .terminate {
            agentHolder.agent.interrupt()
            renderer.output.write("^C\n")
            if event == .forceExit || event == .terminate { return true }
            break
        }
        renderer.render(message)
    }

    let postCheck = SignalHandler.check()
    if postCheck == .interrupt || postCheck == .forceExit || postCheck == .terminate {
        agentHolder.agent.interrupt()
        renderer.output.write("^C\n")
        if postCheck == .forceExit || postCheck == .terminate { return true }
    }

    return false
}
```

然后在 `start()` 中使用：

```swift
func start() async {
    var multilineBuffer: [String] = []
    var inMultiline = false
    var inTripleQuote = false

    while let rawInput = reader.readLine(prompt: promptForState(inMultiline: inMultiline, inTripleQuote: inTripleQuote)) {
        // ... multiline state machine logic ...

        // For complete inputs:
        if await processInput(fullInput) { return }
    }
}
```

### Project Structure Notes

```
Sources/OpenAgentCLI/
  REPLLoop.swift              -- 修改 (~60 行新增)：多行状态机 + processInput 提取
  ANSI.swift                  -- 修改 (+15 行)：coloredContinuationPrompt 方法

Tests/OpenAgentCLITests/
  MultilineInputTests.swift   -- 新建 (~10-15 个测试用例)
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 9, Story 9.5]
- [Source: Sources/OpenAgentCLI/REPLLoop.swift — start() 方法 L119-183]
- [Source: Sources/OpenAgentCLI/REPLLoop.swift — handleSlashCommand L187-220]
- [Source: Sources/OpenAgentCLI/ANSI.swift — coloredPrompt(forMode:forceColor:) L78-90]
- [Source: Sources/OpenAgentCLI/LinenoiseInputReader.swift — readLine(prompt:) L55-71]
- [Source: Sources/OpenAgentCLI/SignalHandler.swift — 信号检测]
- [Source: _bmad-output/implementation-artifacts/9-4-tab-completion.md — Story 9.4 实现记录]

### Previous Story Learnings (9.1-9.4)

- 777+ unit tests 全量通过，0 回归
- `REPLLoop` 是 struct，不可变语义。可变状态使用 class wrapper（`AgentHolder`, `ModeHolder`, `CostTracker`）
- 多行状态机的 `multilineBuffer`、`inMultiline`、`inTripleQuote` 是局部变量（在 `start()` 方法内），不需要 class wrapper
- `InputReading` 协议只有 `readLine(prompt:) -> String?` 一个方法
- `LinenoiseInputReader` 在 Ctrl+C 时返回 `""`（空字符串），Ctrl+D 时返回 `nil`
- CLI.swift 有两处 REPL 入口（L127 skill REPL, L179 主 REPL），但多行逻辑在 REPLLoop 内部，不需要修改 CLI.swift
- ANSI prompt 颜色使用 `coloredPrompt(forMode:forceColor:)`，测试时传 `forceColor: true`
- SignalHandler 已建立 `.interrupt` / `.forceExit` / `.terminate` 三种信号类型
- Tab 补全在单行输入层工作，多行模式下每行仍可使用补全——不需要修改 `TabCompletionProvider`
- 测试使用 `MockInputReader`（返回预定义输入序列）和 `MockTextOutputStream`（捕获输出）

### Git Intelligence (Recent Commits)

```
4c57d45 feat: add Tab completion for REPL slash commands — Story 9.4
cf89f3f feat: add command history with linenoise-swift — Story 9.3
58e516c feat: add colored REPL prompt based on permission mode — Story 9.2
66047e1 feat: add REPL welcome screen — Story 9.1
```

- Story 9.4 新增 `TabCompletionProvider.swift`（50 行），修改 `LinenoiseInputReader.swift`（+11 行）和 `CLI.swift`（+8 行）
- Story 9.3 新增 `LinenoiseInputReader.swift`（122 行），修改 `Package.swift`（+5 行 linenoise-swift 依赖）
- Story 9.2 修改 `ANSI.swift` 和 `REPLLoop.swift`（添加 `ModeHolder`、动态 prompt）
- Story 9.1 修改 `CLI.swift`（添加欢迎信息输出）
- Epic 9 所有 story 均未修改 `OutputRenderer` 或 `AgentFactory`

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No debug issues encountered. All tests passed on first implementation run.

### Completion Notes List

- Implemented multiline state machine in REPLLoop.start() with two independent modes: backslash continuation (`inMultiline`) and triple-quote mode (`inTripleQuote`)
- Extracted `processInput()` method from start() for clean separation between multiline accumulation and input processing (signal handling, slash commands, Agent streaming)
- Added `ANSI.coloredContinuationPrompt(forMode:forceColor:)` with identical color mapping to `coloredPrompt` but displaying `...>` instead of `> `
- Ctrl+C cancellation: empty input during multiline mode clears buffer and returns to main prompt with `^C` output
- Backslash continuation: rstrips whitespace before checking for trailing `\`, strips backslash on accumulation, joins with `\n`
- Triple-quote mode: preserves original indentation and empty lines, content between `"""` delimiters joined with `\n`
- Bare `\` guard: a line consisting only of `\` is treated as normal input, not continuation
- Empty triple-quote content (immediately closed) is filtered by whitespace guard
- All 25 ATDD tests pass, 802 total tests pass with 0 failures and 0 regressions

### File List

| File | Operation | Description |
|------|-----------|-------------|
| Sources/OpenAgentCLI/REPLLoop.swift | Modified | Added multiline state machine in start(), extracted processInput() method |
| Sources/OpenAgentCLI/ANSI.swift | Modified | Added coloredContinuationPrompt(forMode:forceColor:) method |
| Tests/OpenAgentCLITests/MultilineInputTests.swift | Existing | 25 ATDD tests (pre-existing, all now passing) |

### Review Findings

- [x] [Review][Patch] AC#1 violation: empty line during multiline treated as Ctrl+C instead of content — Fixed: use SignalHandler.check() to distinguish real Ctrl+C from plain Enter; updated tests with SignalingMockInputReader [`REPLLoop.swift:145-170`]
- [x] [Review][Patch] ANSI code duplication: coloredPrompt and coloredContinuationPrompt duplicated switch — Fixed: extracted shared formattedPrompt() private helper [`ANSI.swift:78-130`]
