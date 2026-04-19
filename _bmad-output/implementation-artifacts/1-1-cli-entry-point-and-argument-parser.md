# Story 1.1: CLI 入口与参数解析器

状态: done

## 故事

作为一个开发者，
我想要一个能解析命令行参数并启动对应模式的 CLI，
以便无需编辑配置文件即可配置 Agent。

## 验收标准

1. **假设** CLI 已安装
   **当** 我运行 `openagent --help`
   **那么** 显示帮助信息，列出所有可用参数
   **并且** 进程以退出码 0 退出

2. **假设** 未提供任何参数
   **当** 我运行 `openagent`
   **那么** CLI 进入 REPL 模式并使用默认设置

3. **假设** 提供了一个带引号的字符串
   **当** 我运行 `openagent "what is 2+2?"`
   **那么** CLI 以单次模式运行并在响应后退出

4. **假设** 提供了无效参数
   **当** 我运行 `openagent --invalid-flag`
   **那么** 错误信息解释该无效参数
   **并且** 进程以退出码 1 退出

## 任务 / 子任务

- [ ] 任务 1: 创建 `Version.swift`，定义 CLI_VERSION 常量 (AC: #1)
  - [ ] 定义 `CLI_VERSION` 常量，匹配 SDK 版本或项目版本
  - [ ] 放置在 `Sources/OpenAgentCLI/Version.swift`

- [ ] 任务 2: 创建 `ANSI.swift` 终端转义码辅助工具 (AC: #1)
  - [ ] 定义静态方法: `bold()`, `dim()`, `red()`, `cyan()`, `reset()`, `clear()`
  - [ ] 所有方法返回 `String`，支持组合输出
  - [ ] 放置在 `Sources/OpenAgentCLI/ANSI.swift`

- [ ] 任务 3: 创建 `ArgumentParser.swift`，实现自定义参数解析 (AC: #1, #2, #3, #4)
  - [ ] 定义 `ParsedArgs` 结构体，持有所有解析后的 CLI 配置
  - [ ] 实现 `parse(_:)` 静态方法，接受 `[String]`
  - [ ] 处理 `--help` / `-h` 参数：打印用法并退出码 0
  - [ ] 处理 `--version` / `-v` 参数：打印版本并退出码 0
  - [ ] 处理位置参数（检测单次模式）
  - [ ] 处理 `--model <model>` 参数（默认: `glm-5.1`）
  - [ ] 处理 `--mode <mode>` 参数（默认: `default`）
  - [ ] 处理 `--tools <tiers>` 参数（默认: `core`）
  - [ ] 处理 `--mcp <path>` 参数
  - [ ] 处理 `--hooks <path>` 参数
  - [ ] 处理 `--skill-dir <path>` 参数
  - [ ] 处理 `--skill <name>` 参数
  - [ ] 处理 `--session <id>` 参数
  - [ ] 处理 `--no-restore` 布尔参数
  - [ ] 处理 `--max-turns <n>` 参数（默认: 10）
  - [ ] 处理 `--max-budget <usd>` 参数
  - [ ] 处理 `--system-prompt <text>` 参数
  - [ ] 处理 `--thinking <budget>` 参数
  - [ ] 处理 `--quiet` 布尔参数
  - [ ] 处理 `--output <format>` 参数
  - [ ] 处理 `--log-level <level>` 参数
  - [ ] 处理 `--api-key <key>` 参数
  - [ ] 处理 `--base-url <url>` 参数
  - [ ] 处理 `--provider <provider>` 参数
  - [ ] 处理 `--tool-allow <names>` 逗号分隔参数
  - [ ] 处理 `--tool-deny <names>` 逗号分隔参数
  - [ ] 处理未知参数：打印错误并列出有效参数，退出码 1
  - [ ] 验证 `--mode` 的值与 SDK `PermissionMode` 枚举匹配
  - [ ] 验证 `--tools` 的值为已知层级（core/advanced/specialist/all）
  - [ ] 验证 `--output` 的值（text/json）
  - [ ] 验证 `--provider` 的值（anthropic/openai）
  - [ ] 验证 `--log-level` 的值（debug/info/warn/error）
  - [ ] 解析 API Key：`--api-key` 参数 > `OPENAGENT_API_KEY` 环境变量
  - [ ] 将所有解析后的值存储在 `ParsedArgs` 结构体中

- [ ] 任务 4: 创建 `CLI.swift` 顶层协调器 (AC: #2, #3)
  - [ ] 定义 `CLI` 结构体，包含 `static func run() async` 方法
  - [ ] 调用 `ArgumentParser.parse()` 获取 `ParsedArgs`
  - [ ] 确定模式：REPL（无 prompt）或 单次模式（有 prompt）
  - [ ] 单次模式：打印 "Agent creation not yet implemented" 占位信息
  - [ ] REPL 模式：打印 "REPL mode not yet implemented" 占位信息
  - [ ] 处理 API Key 缺失：向 stderr 输出可操作的错误信息，退出码 1

- [ ] 任务 5: 更新 `main.swift` 入口 (AC: #2, #3)
  - [ ] 用 `CLI.run()` 分派替换已有原型代码
  - [ ] 使用 `@main` 属性配合 async main
  - [ ] main.swift 中不含业务逻辑——仅分派到 CLI.run()

- [ ] 任务 6: 创建 `ArgumentParserTests.swift` (AC: #1, #2, #3, #4)
  - [ ] 测试 `--help` 返回帮助文本并发出退出信号
  - [ ] 测试 `--version` 返回版本字符串并发出退出信号
  - [ ] 测试无参数返回默认 ParsedArgs（检测到 REPL 模式）
  - [ ] 测试位置参数被检测为单次模式 prompt
  - [ ] 测试所有参数使用有效值正确解析
  - [ ] 测试无效参数产生错误信息
  - [ ] 测试无效 `--mode` 值产生错误
  - [ ] 测试 API Key 解析：参数覆盖环境变量
  - [ ] 测试默认值与 SDK 默认值匹配

## 开发备注

### 架构合规性

本故事实现了架构文档实现顺序中的**前两个组件**：
1. `Version.swift` + `ANSI.swift`（常量）
2. `ArgumentParser.swift`（CLI 参数 → ParsedArgs）

[来源: architecture.md#实现顺序]

### 关键约束：禁止第三方 CLI 库

PRD 明确约束：**禁止第三方 CLI 库**。自定义 `ArgumentParser` 结构体验证了 Foundation 对 ~20 个参数的充分性。不得导入 `swift-argument-parser` 或任何外部包。

[来源: prd.md#技术约束, architecture.md#启动模板评估]

### 本故事的 SDK API 参考

**从 `import OpenAgentSDK` 中使用的类型：**

- `PermissionMode` 枚举: `.default`, `.acceptEdits`, `.bypassPermissions`, `.plan`, `.dontAsk`, `.auto` — 全部 `CaseIterable`，`String` 原始值
- `LLMProvider` 枚举: `.anthropic`, `.openai` — `String` 原始值
- `ToolTier` 枚举: `.core`, `.advanced`, `.specialist` — `CaseIterable`，`String` 原始值
- `ThinkingConfig` 枚举: `.adaptive`, `.enabled(budgetTokens: Int)`, `.disabled`
- `LogLevel` 枚举 — 检查 debug/info/warn/error/none 成员
- `AgentOptions` 结构体 — 所有字段带默认值可用
- `createAgent(options:)` — 工厂函数（Story 1.2 使用）
- `SDK_VERSION` 常量 — `public let SDK_VERSION = "0.1.0"`

### ParsedArgs 结构体设计

`ParsedArgs` 结构体应持有所有解析后的 CLI 值。它不应直接创建 `AgentOptions`——那是 Story 1.2 的工作。它持有准备转换的原始值：

```swift
struct ParsedArgs {
    var helpRequested: Bool
    var versionRequested: Bool
    var prompt: String?              // nil = REPL 模式
    var model: String                // 默认: "glm-5.1"
    var apiKey: String?              // nil = 检查环境变量
    var baseURL: String?
    var provider: String?            // nil = anthropic 默认
    var mode: String                 // 默认: "default"
    var tools: String                // 默认: "core"
    var mcpConfigPath: String?
    var hooksConfigPath: String?
    var skillDir: String?
    var skillName: String?
    var sessionId: String?
    var noRestore: Bool
    var maxTurns: Int                // 默认: 10
    var maxBudgetUsd: Double?
    var systemPrompt: String?
    var thinking: Int?               // token 预算，nil = 禁用
    var quiet: Bool
    var output: String               // 默认: "text"
    var logLevel: String?
    var toolAllow: [String]?         // 逗号分隔解析
    var toolDeny: [String]?          // 逗号分隔解析
    var shouldExit: Bool             // --help 或 --version 时为 true
    var exitCode: Int32              // help/version 为 0，错误为 1
    var errorMessage: String?        // 解析错误时设置
}
```

### 自定义参数解析模式

仅使用 Foundation 的解析方法。遍历 `CommandLine.arguments.dropFirst()`：

```swift
static func parse(_ args: [String] = CommandLine.arguments) -> ParsedArgs {
    var result = ParsedArgs()
    var i = 1
    while i < args.count {
        let arg = args[i]
        if arg == "--help" || arg == "-h" {
            result.helpRequested = true
            result.shouldExit = true
        } else if arg == "--model" {
            i += 1; guard i < args.count else { /* error */ }
            result.model = args[i]
        } else if !arg.hasPrefix("-") {
            result.prompt = arg  // 位置参数 = 单次模式
        } else { /* 检查已知参数或报错 */ }
        i += 1
    }
    return result
}
```

### 关键验证规则

- `--mode` 必须匹配以下值之一：`default`, `acceptEdits`, `bypassPermissions`, `plan`, `dontAsk`, `auto`（即 SDK `PermissionMode` 枚举的精确原始值）
- `--tools` 接受：`core`, `advanced`, `specialist`, `all`
- `--provider` 接受：`anthropic`, `openai`
- `--output` 接受：`text`, `json`
- `--log-level` 接受：`debug`, `info`, `warn`, `error`
- `--max-turns` 必须为正整数
- `--max-budget` 必须为正双精度浮点数
- `--thinking` 必须为正整数（token 预算）
- `--tool-allow` 和 `--tool-deny` 为逗号分隔的工具名
- API Key 解析顺序：`--api-key` 参数 > `OPENAGENT_API_KEY` 环境变量

### 项目结构说明

需要创建/修改的文件：
```
Sources/OpenAgentCLI/
  main.swift              # 修改：用 CLI.run() 替换原型代码
  CLI.swift               # 创建：顶层协调器
  ArgumentParser.swift     # 创建：自定义参数解析
  Version.swift            # 创建：CLI_VERSION 常量
  ANSI.swift               # 创建：终端转义码辅助工具

Tests/OpenAgentCLITests/
  ArgumentParserTests.swift # 创建：全面的解析测试
```

[来源: architecture.md#项目结构]

### 一类型一文件约定

遵循架构文档的约定：
- 每个文件一个主要类型
- 基于协议的可测试性（例如，`ArgumentParser` 应通过传入 `[String]` 进行测试，而非直接读取 `CommandLine.arguments`）
- PascalCase 文件名匹配主要类型

[来源: architecture.md#命名规范]

### 测试标准

- XCTest 框架
- 测试文件镜像源文件：`ArgumentParserTests.swift` 对应 `ArgumentParser.swift`
- 测试应直接传入 `[String]` 数组——不启动子进程
- 覆盖所有验收标准的测试用例

### 错误输出规则

- 用户错误（错误参数、缺少 Key）→ stderr，退出码 1
- 帮助/版本输出 → stdout，退出码 0
- 使用 `FileHandle.standardError` 输出错误信息
- 错误信息必须具有可操作性：告诉用户哪里出错**以及**如何修复

[来源: architecture.md#错误输出]

### 帮助信息格式

`--help` 输出应包含：
- 用法行：`openagent [options] [prompt]`
- 模式描述（REPL、单次模式）
- 所有可用选项及其描述
- 按逻辑分组选项（启动、交互、工具、会话、输出）

[来源: prd.md#CLI 接口设计]

### SDK-GAP 注释

如果在实现过程中发现 SDK 类型未暴露 CLI 所需功能，添加带 `// SDK-GAP:` 前缀的注释记录缺口。**不要**绕过处理。

[来源: architecture.md#执行指南]

### 参考资料

- [来源: _bmad-output/planning-artifacts/epics.md#Story 1.1]
- [来源: _bmad-output/planning-artifacts/prd.md#FR1, FR2, FR6]
- [来源: _bmad-output/planning-artifacts/architecture.md#自定义参数解析, 实现顺序]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#AgentOptions]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/PermissionTypes.swift#PermissionMode]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/ToolRegistry.swift#ToolTier]

## 开发代理记录

### 使用的代理模型

### 调试日志引用

### 完成备注列表

### 文件列表
