---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
workflowType: 'architecture'
project_name: 'open-agent-cli'
user_name: 'Nick'
date: '2026-04-19'
status: 'complete'
completedAt: '2026-04-19'
---

# 架构决策文档 — OpenAgentCLI

---

## 项目上下文分析

### 需求概述

**功能需求：**

38 项功能需求，划分为 10 个类别（FR1–FR10）：

| 类别 | 数量 | 优先级分布 |
|------|------|-----------|
| FR1：启动与配置 | 6 | P0×3, P1×2, P2×1 |
| FR2：交互模式 | 6 | P0×4, P1×1, P2×1 |
| FR3：工具系统 | 5 | P0×3, P1×2 |
| FR4：会话管理 | 5 | P0×1, P1×3, P2×1 |
| FR5：MCP 集成 | 5 | P0×3, P1×1, P2×1 |
| FR6：权限与安全 | 4 | P0×2, P1×2 |
| FR7：Hook 系统 | 3 | P1×3 |
| FR8：子代理与团队 | 4 | P0×1, P1×2, P2×1 |
| FR9：输出与格式 | 5 | P1×4, P2×1 |
| FR10：技能与自定义工具 | 4 | P1×2, P2×2 |

**P0（MVP）：** 21 项需求 — 必须全部可通过公共 API 实现
**P1（增强）：** 13 项需求 — 首次发布的扩展目标
**P2（锦上添花）：** 4 项需求 — 未来迭代

**非功能需求：**

- **NFR1 性能：** 冷启动 < 2s，流式传输开销 < 50ms/块，空闲内存 < 50MB
- **NFR2 可靠性：** 自动重试，优雅的 Ctrl+C 处理并保存会话，MCP 自动重连
- **NFR3 易用性：** 零配置（仅需 API Key），可操作的错误信息，跨平台
- **NFR4 SDK 验证：** 零内部访问，API 差距文档化，集成参考质量

### 规模与复杂度

- **主要领域：** CLI 开发者工具（AI Agent 基础设施）
- **复杂度等级：** 中等
- **预估架构组件：** 8 个（Config、REPL、ArgParser、OutputRenderer、ToolManager、SessionManager、MCPManager、HookManager）
- **无数据库** — SDK 通过基于文件的 JSON 持久化提供 SessionStore
- **无前端** — 仅终端 ANSI 输出
- **无 REST API** — CLI 是唯一接口
- **单进程** — 无分布式组件

### 技术约束与依赖

| 约束 | 详情 |
|------|------|
| 语言 | Swift 5.9+（支持 typed throws） |
| 平台 | macOS 13+, Linux (Ubuntu 20.04+) |
| 构建系统 | 仅 Swift Package Manager |
| 依赖 | 仅 OpenAgentSDK（本地路径引用） |
| 无第三方 CLI 库 | 自定义参数解析，自定义终端渲染 |
| 无 SDK 内部访问 | 仅允许 `import OpenAgentSDK` |
| 不 fork SDK | 问题记录为 Issue，不做 workaround |

### 已识别的横切关注点

1. **SDK API 完整性** — 每个功能必须可通过公共 API 实现；差距记录为 Issue
2. **跨平台终端 I/O** — ANSI 码有差异；仅使用 Foundation 抽象
3. **流式管道** — `AsyncStream<SDKMessage>` 在各处被消费；一致的渲染
4. **配置分层** — CLI 参数 > 环境变量 > 配置文件 > SDK 默认值
5. **错误传播** — SDK 错误映射为用户友好的终端消息

---

## 启动模板评估

### 主要技术领域

基于 Swift Package Manager 构建的 CLI 工具，包含单个可执行目标。

### 考虑的启动方案

| 方案 | 结论 |
|------|------|
| Swift Argument Parser (apple/swift-argument-parser) | 拒绝 — 增加第三方依赖，与"无第三方 CLI 库"约束冲突 |
| TSCUtility (SwiftPM 内部) | 拒绝 — 不是稳定的公共 API |
| 自定义参数解析器 | 选中 — 验证 SDK 充分性，零依赖，完全控制 |

### 选定方案：自定义 SPM 可执行项目

**理由：**

- PRD 明确约束："无第三方 CLI 库"
- 自定义解析证明 Foundation 已足够（进一步验证最小依赖理念）
- 总参数数量可控（约 20 个标志），不值得引入依赖
- 保持 CLI 作为纯 SDK 集成参考

**初始化命令：**

```bash
# Already created
mkdir -p open-agent-cli && cd open-agent-cli
swift package init --type executable --name OpenAgentCLI
```

**提供的架构决策：**

- **语言与运行时：** Swift 5.9+，支持结构化并发
- **构建工具：** SPM，通过本地路径依赖 `../open-agent-sdk-swift`
- **测试：** XCTest，与 SDK 相同的结构
- **代码组织：** 扁平模块，基于协议的分离
- **无需启动模板** — 项目已初始化

---

## 核心架构决策

### 决策优先级分析

**关键决策（阻塞实现）：**

| 决策 | 选择 | 理由 |
|------|------|------|
| 架构模式 | SDK 之上的薄编排层 | CLI 解析输入，委托给 SDK，渲染输出。CLI 中无业务逻辑。 |
| 参数解析 | 自定义 `ArgumentParser` 结构体 | 约 20 个标志，仅用 Foundation，无依赖 |
| REPL 引擎 | 自定义 `REPLLoop`，使用 `FileHandle.standardInput` | 验证 SDK 的 AsyncStream 管道无需外部 readline 即可工作 |
| 流式输出 | 直接消费 `AsyncStream<SDKMessage>` | 无缓冲 — 流到终端直通 |
| 权限流程 | `CanUseToolFn` 回调 → 终端提示 | SDK 提供 Hook；CLI 渲染提示 |

**重要决策（塑造架构）：**

| 决策 | 选择 | 理由 |
|------|------|------|
| 配置分层 | CLI 参数 > 环境变量 > 配置文件 > SDK 默认值 | 最具体的优先；符合 Unix 惯例 |
| MCP 配置格式 | JSON 文件（SDK 的 `McpServerConfig` 结构体） | 复用 SDK 原生格式，无需转换层 |
| Hook 配置格式 | JSON 文件（SDK 的 `HookDefinition` 结构体） | 同理 — 直接兼容 SDK |
| 会话存储 | SDK 的 `SessionStore`，使用默认路径 | 零自定义持久化代码 |
| 工具层级加载 | `getAllBaseTools(tier:)` + `assembleToolPool()` | 直接使用 SDK API，无自定义工具注册表 |

**推迟的决策（MVP 之后）：**

| 决策 | 推迟原因 |
|------|---------|
| Markdown 渲染库 | P1；先评估终端宽度检测 |
| 配置文件格式（YAML vs TOML） | P2；JSON 足以满足 MVP |
| 插件系统 | P2；SDK 验证阶段不需要 |
| Shell 补全脚本 | P2；锦上添花 |

### 数据架构

无数据库。所有状态由 SDK actor 管理：
- **SessionStore** — 对话持久化（`~/.open-agent-sdk/sessions/`）
- **TaskStore** — 任务生命周期
- **TeamStore** — 团队成员
- **WorktreeStore**、**PlanStore**、**CronStore**、**TodoStore** — 专家状态

CLI 从不直接访问这些存储 — 仅将它们传递给 `AgentOptions`。

### 认证与安全

- API Key 通过 `OPENAGENT_API_KEY` 环境变量或 `--api-key` 标志传入
- 不在配置文件中存储 Key（仅环境变量）
- 权限模式完全委托给 SDK 的 `PermissionMode` 枚举
- `canUseTool` 回调提供基于终端的审批交互

### API 与通信模式

无 HTTP API。通信模式：

1. **CLI → SDK：** 创建时通过 `AgentOptions`，会话期间通过方法调用
2. **SDK → CLI：** `AsyncStream<SDKMessage>` 用于流式传输，`QueryResult` 用于阻塞调用
3. **CLI → 终端：** 通过 `print()` / `FileHandle` 输出 ANSI 格式化内容
4. **终端 → CLI：** `FileHandle.standardInput` 用于 REPL，`CommandLine.arguments` 用于参数

### 前端架构

不适用 — 仅终端输出。输出渲染由 `OutputRenderer` 处理：

```
SDKMessage.assistant  → print text (streaming)
SDKMessage.toolUse    → print tool name + params summary
SDKMessage.toolResult → print result or error
SDKMessage.result     → print summary (turns, cost, duration)
SDKMessage.system     → print system messages (compact, etc.)
```

### 基础设施与部署

- **分发：** `swift build -c release` 生成静态二进制文件
- **无需容器化** — 单个二进制文件
- **初期无 CI/CD** — 手动 `swift build && swift test`
- **安装：** 将二进制文件复制到 PATH，或从源码 `swift run`

### 决策影响分析

**实现顺序：**

1. `ArgumentParser` — 解析 CLI 标志 → `AgentOptions`
2. `AgentFactory` — 从解析后的选项创建 Agent
3. `OutputRenderer` — 消费 `AsyncStream<SDKMessage>` → 终端
4. `REPLLoop` — 读取输入，发送给 Agent，渲染输出，循环
5. `PermissionHandler` — `canUseTool` 回调 → 终端提示
6. `SessionManager` — 通过 SDK SessionStore 自动保存/恢复
7. `MCPConfigLoader` — 加载 JSON → `McpServerConfig` 字典
8. `HookConfigLoader` — 加载 JSON → `HookDefinition` 字典

**跨组件依赖：**

- `REPLLoop` 依赖 `AgentFactory`、`OutputRenderer`、`PermissionHandler`
- `AgentFactory` 依赖 `ArgumentParser`、`MCPConfigLoader`、`HookConfigLoader`
- `OutputRenderer` 独立 — 仅消费 `SDKMessage`
- 所有组件生产/消费 SDK 类型 — 无共享的 CLI 特定状态

---

## 实现模式与一致性规则

### 命名模式

**Swift 命名（遵循 SDK 惯例）：**

| 元素 | 约定 | 示例 |
|------|------|------|
| 类型（struct/class/protocol） | PascalCase | `REPLLoop`、`OutputRenderer` |
| 函数 | camelCase | `parseArguments()`、`renderMessage()` |
| 变量 / 属性 | camelCase | `currentSessionId`、`toolTier` |
| 常量 | SNAKE_CASE | `DEFAULT_MODEL`、`CLI_VERSION` |
| 文件名 | PascalCase，每个文件一个类型 | `REPLLoop.swift`、`OutputRenderer.swift` |

**不与 SDK 产生新的命名冲突：**
- CLI 类型位于 `OpenAgentCLI` 模块中，与 `OpenAgentSDK` 不冲突
- 永远不要将 CLI 类型命名为与 SDK 类型相同（CLI 中不使用 `Agent`、`SessionStore` 等名称）

### 结构模式

**项目组织：**

- 每个文件一个主要职责
- 使用协议实现可测试性（如 `OutputRendering`、`InputReading`）
- 为 SDK 类型便利方法提供扩展文件（如 `SDKMessage+Rendering.swift`）

**文件结构：**

```
Sources/OpenAgentCLI/
  main.swift              # Entry point only — dispatch to CLI.run()
  CLI.swift               # Top-level orchestrator
  ArgumentParser.swift     # CLI flag parsing → AgentOptions
  AgentFactory.swift       # createAgent() with assembled options
  OutputRenderer.swift     # SDKMessage → terminal ANSI output
  REPLLoop.swift           # Read-eval-print loop
  PermissionHandler.swift  # canUseTool callback → terminal prompt
  SessionManager.swift     # Auto-save/restore session
  MCPConfigLoader.swift    # JSON → McpServerConfig dict
  HookConfigLoader.swift   # JSON → HookDefinition dict
  ANSI.swift               # Terminal escape code helpers
```

### 格式模式

**终端输出格式：**

| SDKMessage case | 格式 |
|-----------------|------|
| `.assistant(data)` | `data.text` 直接打印（流式） |
| `.toolUse(data)` | 青色 `⚙ toolName(args...)` |
| `.toolResult(data)` | 结果文本，`isError` 时为红色 |
| `.result(data)` | `--- Turns: N | Cost: $X.XXXX | Duration: Xs` |
| `.system(data)` | 灰色 `[system] message` |

**错误输出：**

- 用户错误（参数错误、缺少 Key） → stderr，退出码 1
- SDK 错误 → 映射为友好消息输出到 stderr
- 工具错误 → 在对话中内联显示（红色文本）

**配置文件格式（MVP 使用 JSON）：**

```json
{
  "mcpServers": {
    "server-name": {
      "command": "path/to/server",
      "args": ["--flag"]
    }
  }
}
```

### 通信模式

**AsyncStream 消费模式：**

```swift
let stream = agent.stream(prompt)
for await message in stream {
    renderer.render(message)
}
```

**权限回调模式：**

```swift
options.canUseTool = { toolName, input in
    renderer.showPermissionPrompt(toolName, input)
    return renderer.readApproval()
}
```

**REPL 输入模式：**

```swift
while let input = reader.readLine(prompt: "> ") {
    if input.hasPrefix("/") { handleCommand(input); continue }
    let stream = agent.stream(input)
    for await message in stream { renderer.render(message) }
}
```

### 流程模式

**错误处理：**

- 永不崩溃 — 在 REPL 边界捕获所有错误
- SDK 错误：显示友好消息，继续 REPL
- 致命错误（无 API Key）：显示可操作消息，退出
- 工具错误：内联显示，不中断对话

**加载状态：**

- 流式传输：等待第一个 token 时显示加载动画
- MCP 连接：启动时显示进度
- 会话恢复：显示 "[restoring session...]"

**信号处理：**

- SIGINT (Ctrl+C)：`agent.interrupt()`，继续 REPL
- SIGTERM：`agent.close()`，保存会话，退出
- 1 秒内第二次 Ctrl+C：强制退出

### 执行指南

**所有 AI Agent 必须：**

- 仅使用 `import OpenAgentSDK` — 无内部访问
- 遵循一类型一文件的约定
- 所有终端输出使用 `OutputRenderer` — 永远不对 SDK 消息使用原始 `print()`
- 渲染时处理所有 `SDKMessage` case（使用 `default` 保证前向兼容）
- 所有 SDK 状态通过 `AgentOptions` 传递 — 永远不在 Agent 创建后持有 SDK actor 引用
- 使用 `// SDK-GAP:` 前缀注释记录任何 SDK API 差距

---

## 项目结构与边界

### 完整项目目录结构

```
open-agent-cli/
├── Package.swift                          # SPM manifest, local SDK dependency
├── README.md                              # Quick start guide
├── .gitignore
├── _bmad/
│   └── bmm/
│       └── config.yaml                    # BMAD configuration
├── _bmad-output/
│   └── planning-artifacts/
│       ├── prd.md                         # Product requirements
│       └── architecture.md               # This document
├── Sources/
│   └── OpenAgentCLI/
│       ├── main.swift                     # Entry point → CLI.run()
│       ├── CLI.swift                      # Top-level orchestrator
│       ├── ArgumentParser.swift           # CLI flags → AgentOptions
│       ├── AgentFactory.swift             # createAgent() assembly
│       ├── OutputRenderer.swift           # SDKMessage → terminal
│       ├── OutputRenderer+SDKMessage.swift # Per-case rendering
│       ├── REPLLoop.swift                 # Interactive read-eval-print
│       ├── PermissionHandler.swift        # canUseTool → terminal prompt
│       ├── SessionManager.swift           # Auto-save/restore
│       ├── MCPConfigLoader.swift          # JSON → McpServerConfig dict
│       ├── HookConfigLoader.swift         # JSON → HookDefinition dict
│       ├── ANSI.swift                     # Terminal escape code helpers
│       └── Version.swift                  # CLI_VERSION constant
└── Tests/
    └── OpenAgentCLITests/
        ├── ArgumentParserTests.swift
        ├── AgentFactoryTests.swift
        ├── OutputRendererTests.swift
        ├── REPLLoopTests.swift
        ├── PermissionHandlerTests.swift
        ├── SessionManagerTests.swift
        ├── MCPConfigLoaderTests.swift
        └── HookConfigLoaderTests.swift
```

### 架构边界

**SDK 边界：**

CLI 仅在单一点接触 SDK — `AgentOptions` 配置和 `Agent` 方法调用。所有 SDK 状态通过 Agent 传递。

```
┌─────────────────────────────────────────┐
│               OpenAgentCLI               │
│                                         │
│  ArgumentParser → AgentFactory → Agent  │
│       ↓              ↓           ↓      │
│  CLI types      AgentOptions    SDKMessage
│  String, Bool   (SDK type)     (SDK type)
└─────────────────────┬───────────────────┘
                      │ import OpenAgentSDK
                      ↓
┌─────────────────────────────────────────┐
│              OpenAgentSDK                │
│                                         │
│  Agent → QueryEngine → Tools/Stores/MCP │
└─────────────────────────────────────────┘
```

**组件边界：**

```
main.swift
  └── CLI.run()
        ├── ArgumentParser.parse() → ParsedArgs
        ├── AgentFactory.create(ParsedArgs) → Agent
        ├── SessionManager.restore() → sessionId?
        ├── REPLLoop.start(Agent, SessionManager)
        │     ├── OutputRenderer.render(SDKMessage)
        │     ├── PermissionHandler.prompt(toolName, input) → Bool
        │     └── REPLLoop.handleSlashCommand(String)
        └── SessionManager.save()
```

### 需求到结构的映射

**FR1：启动与配置 → `ArgumentParser.swift`、`CLI.swift`**
- 参数解析，环境变量读取，默认值

**FR2：交互模式 → `REPLLoop.swift`、`CLI.swift`**
- REPL 循环，单次提问模式，stdin 模式

**FR3：工具系统 → `AgentFactory.swift`**
- `getAllBaseTools(tier:)` → `assembleToolPool()`

**FR4：会话管理 → `SessionManager.swift`**
- 关闭时自动保存，启动时自动恢复，/sessions 命令

**FR5：MCP 集成 → `MCPConfigLoader.swift`、`AgentFactory.swift`**
- JSON 配置加载，传递给 AgentOptions.mcpServers

**FR6：权限 → `PermissionHandler.swift`**
- canUseTool 回调，终端提示

**FR7：Hook → `HookConfigLoader.swift`、`AgentFactory.swift`**
- JSON 配置加载，传递给 createHookRegistry()

**FR8：子代理 → `AgentFactory.swift`**
- 选择高级层级时包含 createAgentTool()

**FR9：输出 → `OutputRenderer.swift`、`OutputRenderer+SDKMessage.swift`**
- 渲染所有 SDKMessage case

**FR10：技能 → `AgentFactory.swift`**
- SkillRegistry + 技能目录加载

### 集成点

**内部通信：**

- 所有组件通过普通函数调用和 Swift 类型通信
- 无需内部事件总线或消息传递
- 状态由 `CLI` 结构体持有，传递给子组件

**外部集成（通过 SDK）：**

- Anthropic API → 完全由 SDK 的 `AnthropicClient` 处理
- MCP 服务器 → 由 SDK 的 `MCPClientManager` 处理
- 文件系统 → 由 SDK 的 `SessionStore` 处理
- Shell Hook → 由 SDK 的 `HookRegistry` 处理

**数据流：**

```
User Input → ArgumentParser → AgentFactory → Agent
                                              ↓
                                         LLM API (via SDK)
                                              ↓
                                     AsyncStream<SDKMessage>
                                              ↓
                                      OutputRenderer
                                              ↓
                                        Terminal (stdout)
```

---

## 架构验证结果

### 一致性验证

**决策兼容性：** 所有决策互相兼容。"SDK 之上的薄 CLI" 模式意味着每个 CLI 组件与 SDK 能力一一映射。无冲突选择。

**模式一致性：** 命名遵循 SDK 约定（PascalCase 类型，camelCase 函数）。文件结构匹配 SDK 模式（一类型一文件）。AsyncStream 消费在全局保持一致。

**结构对齐：** 13 个源文件，每个单一职责。无循环依赖。所有数据流经 Agent → OutputRenderer。

### 需求覆盖验证

**P0 需求覆盖（21 项）：**

| FR | 覆盖组件 | 使用的 SDK API |
|----|---------|---------------|
| FR1.1 CLI启动 | `CLI.swift` + `main.swift` | `createAgent()` |
| FR1.2 API Key env | `ArgumentParser.swift` | `AgentOptions.apiKey` |
| FR1.3 --model flag | `ArgumentParser.swift` | `AgentOptions.model` |
| FR2.1 REPL模式 | `REPLLoop.swift` | `agent.stream()` |
| FR2.2 单次提问 | `CLI.swift` | `agent.prompt()` |
| FR2.4 /help | `REPLLoop.swift` | — |
| FR2.5 流式输出 | `OutputRenderer.swift` | `AsyncStream<SDKMessage>` |
| FR3.1 Core工具 | `AgentFactory.swift` | `getAllBaseTools(.core)` |
| FR3.2 Advanced工具 | `AgentFactory.swift` | `getAllBaseTools(.advanced)` |
| FR3.5 工具调用显示 | `OutputRenderer.swift` | `SDKMessage.toolUse` |
| FR4.1 会话持久化 | `SessionManager.swift` | `SessionStore`, `AgentOptions.sessionId` |
| FR5.1 MCP配置 | `MCPConfigLoader.swift` | `McpServerConfig` |
| FR5.2 MCP连接 | `AgentFactory.swift` | `AgentOptions.mcpServers` |
| FR5.5 MCP统一调度 | SDK内置 | — |
| FR6.1 --mode | `ArgumentParser.swift` | `PermissionMode` |
| FR6.2 默认default | `AgentFactory.swift` | `PermissionMode.default` |
| FR8.1 Agent工具 | `AgentFactory.swift` | `createAgentTool()` |
| FR9.4 成本统计 | `OutputRenderer.swift` | `QueryResult.totalCostUsd` |
| FR2.6 中断 | `REPLLoop.swift` | `agent.interrupt()` |
| — | — | — |

**非功能需求：** 所有 NFR 通过委托给 SDK 能力来解决（重试、会话保存、流式传输）。CLI 仅增加终端渲染开销。

### 实现就绪验证

**决策完整性：** 所有关键决策已文档化。技术选型已验证（Swift 5.9+、SPM、仅 Foundation）。

**结构完整性：** 13 个源文件已定义，职责明确。测试文件与源文件一一对应。

**模式完整性：** 命名、结构、格式、通信和流程模式均已指定并附有示例。

### 差距分析结果

**关键差距：** 无。

**重要差距：**

1. SDK-GAP：需验证 `PermissionMode` 枚举值是否与 PRD 的 `--mode` 值匹配（bypass 与 bypassPermissions 命名）
2. SDK-GAP：需验证 `createHookRegistry()` 是否接受 `[String: [HookDefinition]]` 配置字典
3. SDK-GAP：需验证通过 `AgentOptions.continueRecentSession` 的会话自动恢复路径是否可用

**锦上添花的差距：**

1. 终端宽度检测用于自动换行 — 可通过 Process 使用 `stty size`
2. 彩色输出 — 需验证 Linux 终端的 ANSI 支持
3. 信号处理库 — Foundation `Signal` 或自定义 `sigaction`

### 架构完整性检查清单

- [x] 项目上下文已充分分析
- [x] 规模与复杂度已评估（中等）
- [x] 技术约束已识别
- [x] 横切关注点已映射
- [x] 关键决策已文档化并标注版本
- [x] 技术栈已完全指定（Swift 5.9+、SPM、Foundation）
- [x] 集成模式已定义
- [x] 性能考量已解决
- [x] 命名约定已建立
- [x] 结构模式已定义
- [x] 通信模式已指定
- [x] 流程模式已文档化
- [x] 完整目录结构已定义
- [x] 组件边界已建立
- [x] 集成点已映射
- [x] 需求到结构的映射已完成

### 架构就绪评估

**总体状态：** 已准备好实现

**置信度：** 高

**核心优势：**

- 薄架构 — CLI 是纯 SDK 消费者，无业务逻辑
- 清晰的关注点分离 — 每个文件单一职责
- SDK 验证融入每个决策
- 除 SDK 外零外部依赖

**未来增强方向：**

- Markdown 终端渲染（MVP 后评估）
- 超越 JSON 的配置文件支持（YAML/TOML）
- Shell 补全脚本（zsh/bash）
- 自定义工具的插件系统

### 实现交接

**AI Agent 指南：**

1. 严格按照文件结构实现 — 一类型一文件
2. 仅 `import OpenAgentSDK` — 使用 `// SDK-GAP:` 注释记录任何 API 差距
3. 所有终端输出使用 `OutputRenderer`
4. 处理所有 `SDKMessage` case（使用 `@unknown default` 保证前向兼容）
5. 每个文件完成后用 `swift build` 和 `swift test` 测试
6. 遵循 `--mode` → `PermissionMode` 的映射

**首批实现优先级：**

1. `Version.swift` + `ANSI.swift`（常量）
2. `ArgumentParser.swift`（CLI 标志 → AgentOptions）
3. `OutputRenderer.swift`（SDKMessage → 终端）
4. `AgentFactory.swift`（从解析参数组装 Agent）
5. `REPLLoop.swift`（将所有组件串联起来）
6. `main.swift` → `CLI.swift`（入口点）
