---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-02b-vision
  - step-02c-executive-summary
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
inputDocuments:
  - _bmad-output/project-context.md
classification:
  projectType: developer_tool
  domain: ai_agent_infrastructure
  complexity: medium
  projectContext: greenfield
workflowType: 'prd'
---

# 产品需求文档 - OpenAgentCLI

**作者：** Nick
**日期：** 2026-04-19
**版本：** 1.0

## 概述

OpenAgentCLI 是一个基于 OpenAgentSDK 构建的命令行 AI Agent 应用。它的核心使命是 **系统性验证 SDK 的综合能力** —— 通过构建一个真实可用的 CLI 产品，证明仅靠 SDK 的 public API 就能构建出功能完整的 Agent 应用。

这不是一个 Demo 或 Example，而是一个面向开发者的终端工具，让用户可以在命令行中体验完整的 AI Agent 能力。

### 为什么做这个

OpenAgentSDK 已经有 94 个源文件、4,560 个单元测试、29 个 E2E 测试、32 个示例。但所有验证都是 **单模块、单功能** 的。没有人用 SDK 从头构建过一个真实应用。

**CLI 是最诚实的验证方式：**
- 只能用 `import OpenAgentSDK`，不能碰 internal
- 必须组合多个模块才能工作（Session + Hook + Tool + MCP + Permission）
- 用户会做开发者意想不到的事，暴露 API 设计的缺陷
- 作为一个可运行的产品，它的成功就是 SDK 成功的证明

### 独特之处

- **SDK 能力的终极证明。** 如果 CLI 能流畅运行，SDK 的公开 API 就是完整的。如果 CLI 碰壁了，我们就找到了 SDK 的 API 缺口。
- **真正的 Dogfood。** SDK 开发者通过使用自己的 SDK 构建产品，发现真实痛点。
- **最强大的示例。** 比 32 个独立 Example 更有说服力 —— 一个集成了所有能力的真实应用。
- **低门槛上手。** `swift run openagent` 即可开始使用，无需配置。

## 项目分类

| 维度 | 值 |
|---|---|
| **项目类型** | 开发者工具（CLI） |
| **领域** | AI Agent 基础设施 |
| **复杂度** | 中等 |
| **项目状态** | 新项目（Greenfield） |

## 目标用户

| 角色 | 描述 | 核心需求 |
|------|------|---------|
| **SDK 开发者** | OpenAgentSDK 的维护者 | 验证 SDK 综合能力，发现 API 缺口 |
| **Swift 开发者** | 想在项目中使用 AI Agent 的开发者 | 快速体验 SDK 能力，作为集成参考 |
| **AI 应用开发者** | 正在评估 Agent SDK 选型的开发者 | 评估 SDK 是否满足其需求 |

## 用户旅程

### 旅程 1：首次体验（5 分钟内上手）

**目标：** 零配置启动，立刻感受到 Agent 的能力

1. 用户克隆仓库，`swift run openagent`
2. CLI 显示欢迎信息，提示输入 API Key（如果未设置环境变量）
3. 用户输入第一个问题："帮我看看当前目录有什么文件"
4. Agent 调用 Bash 工具执行 `ls`，返回结果
5. 用户继续对话，体验多轮交互

**成功标准：** 从 `swift run` 到得到第一个回答 < 30 秒

### 旅程 2：多轮编程任务

**目标：** 验证工具调用 + 多轮对话 + 会话持久化

1. 用户启动 CLI，输入 "帮我创建一个 Swift Hello World 项目"
2. Agent 调用 Write 工具创建文件
3. 用户说 "运行它"
4. Agent 调用 Bash 工具编译运行
5. 用户退出，下次启动时自动恢复会话
6. 用户继续 "给它加个命令行参数"

**成功标准：** 跨会话的连续性，工具调用链路正确

### 旅程 3：MCP + 子代理

**目标：** 验证 MCP 集成 + SubAgent 委派

1. 用户配置 MCP 服务器（通过 CLI 参数或配置文件）
2. 用户输入一个需要外部工具的复杂任务
3. Agent 连接 MCP 服务器，使用外部工具
4. 对于子任务，Agent 派生子代理执行
5. 子代理完成后汇报结果

**成功标准：** MCP 工具发现和调用正常，子代理生命周期管理正确

### 旅程 4：权限和安全

**目标：** 验证 Permission 系统和 Hook 系统

1. 用户以 `--mode plan` 启动（Plan 模式需要批准）
2. Agent 提出执行计划，等待用户确认
3. 用户批准后 Agent 执行
4. Hook 在关键事件触发（如工具执行前记录日志）

**成功标准：** 权限控制生效，Hook 回调正确触发

## 功能需求

### FR1: 启动和配置

| ID | 需求 | 优先级 |
|----|------|--------|
| FR1.1 | CLI 通过 `swift run openagent` 或编译后的二进制启动 | P0 |
| FR1.2 | 通过环境变量 `OPENAGENT_API_KEY` 或 `--api-key` 参数配置 API Key | P0 |
| FR1.3 | 通过 `--model` 参数选择模型，默认 `glm-5.1` | P0 |
| FR1.4 | 通过 `--base-url` 参数配置自定义 API 端点 | P1 |
| FR1.5 | 通过 `--provider` 参数选择 LLM 提供商（anthropic/openai） | P1 |
| FR1.6 | 通过配置文件 `.openagent/config.yaml` 持久化配置 | P2 |

### FR2: 交互模式

| ID | 需求 | 优先级 |
|----|------|--------|
| FR2.1 | 支持交互式 REPL 模式：持续对话直到用户输入 `/exit` | P0 |
| FR2.2 | 支持单次提问模式：`openagent "你的问题"` 直接返回结果 | P0 |
| FR2.3 | 支持管道模式：`echo "问题" \| openagent --stdin` 从标准输入读取 | P2 |
| FR2.4 | REPL 中通过 `/help` 显示可用命令列表 | P0 |
| FR2.5 | 支持流式输出：实时显示 Agent 的思考和工具调用过程 | P0 |
| FR2.6 | 支持中断当前操作：Ctrl+C 优雅中断，不退出 REPL | P1 |

### FR3: 工具系统

| ID | 需求 | 优先级 |
|----|------|--------|
| FR3.1 | 默认加载所有 Core 层工具（Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, AskUser, ToolSearch） | P0 |
| FR3.2 | 通过 `--tools advanced` 加载 Advanced 层工具（Agent, SendMessage, Task*, Team*, NotebookEdit） | P0 |
| FR3.3 | 通过 `--tools specialist` 加载 Specialist 层工具（Worktree, Plan, Cron, TodoWrite, LSP, Config, RemoteTrigger, MCP Resources） | P1 |
| FR3.4 | 通过 `--tool-allow` / `--tool-deny` 白名单/黑名单控制工具访问 | P1 |
| FR3.5 | 工具调用过程实时显示：工具名、输入参数摘要、执行耗时 | P0 |

### FR4: 会话管理

| ID | 需求 | 优先级 |
|----|------|--------|
| FR4.1 | 默认启用会话持久化：每次对话自动保存 | P0 |
| FR4.2 | 通过 `/sessions` 命令列出历史会话 | P1 |
| FR4.3 | 通过 `/resume <id>` 命令恢复历史会话 | P1 |
| FR4.4 | 通过 `/fork` 命令从当前会话分叉 | P2 |
| FR4.5 | 启动时自动恢复最近一次会话（可通过 `--no-restore` 禁用） | P1 |

### FR5: MCP 集成

| ID | 需求 | 优先级 |
|----|------|--------|
| FR5.1 | 通过 `--mcp <config.json>` 参数加载 MCP 服务器配置 | P0 |
| FR5.2 | 启动时自动连接配置的 MCP 服务器 | P0 |
| FR5.3 | 通过 `/mcp status` 命令查看 MCP 服务器连接状态 | P1 |
| FR5.4 | 通过 `/mcp reconnect <name>` 命令重新连接 MCP 服务器 | P2 |
| FR5.5 | MCP 工具与内置工具统一调度 | P0 |

### FR6: 权限和安全

| ID | 需求 | 优先级 |
|----|------|--------|
| FR6.1 | 通过 `--mode` 参数设置权限模式（default/acceptEdits/bypassPermissions/plan/dontAsk/auto） | P0 |
| FR6.2 | 默认模式为 `default`：危险操作需要用户确认 | P0 |
| FR6.3 | 在 REPL 中通过 `/mode <mode>` 动态切换权限模式 | P1 |
| FR6.4 | 权限确认提示清晰显示操作内容和风险 | P1 |

### FR7: 钩子系统

| ID | 需求 | 优先级 |
|----|------|--------|
| FR7.1 | 通过 `--hooks <config.json>` 参数加载钩子配置 | P1 |
| FR7.2 | 支持所有 21 个生命周期事件的 Shell 钩子 | P1 |
| FR7.3 | 钩子执行超时和错误不阻塞主流程 | P1 |

### FR8: 子代理和团队

| ID | 需求 | 优先级 |
|----|------|--------|
| FR8.1 | Agent 工具自动可用（Advanced 层加载时） | P0 |
| FR8.2 | 子代理继承父代理的权限模式和 API 配置 | P1 |
| FR8.3 | 子代理执行进度实时显示 | P1 |
| FR8.4 | SendMessage 工具支持团队内通信 | P2 |

### FR9: 输出和格式

| ID | 需求 | 优先级 |
|----|------|--------|
| FR9.1 | 支持 Markdown 渲染输出（终端兼容） | P1 |
| FR9.2 | 通过 `--output json` 输出结构化 JSON（方便管道集成） | P2 |
| FR9.3 | 通过 `--quiet` 模式只输出最终结果 | P1 |
| FR9.4 | 显示 token 使用量和成本统计 | P1 |
| FR9.5 | 支持配置 Thinking/Extended Thinking | P1 |

### FR10: 自定义工具和技能

| ID | 需求 | 优先级 |
|----|------|--------|
| FR10.1 | 通过 `--skill-dir <path>` 加载技能目录 | P0 |
| FR10.2 | 通过 `--skill <name>` 调用特定技能 | P0 |
| FR10.3 | 在 REPL 中通过 `/skills` 列出可用技能 | P2 |
| FR10.4 | 通过配置文件注册自定义工具 | P2 |

## 非功能需求

### NFR1: 性能

| ID | 需求 | 目标 |
|----|------|------|
| NFR1.1 | CLI 启动时间 | < 2 秒（冷启动） |
| NFR1.2 | 首个 token 延迟 | 取决于 LLM API，SDK 层开销 < 100ms |
| NFR1.3 | 流式输出延迟 | SDK 层 < 50ms per chunk |
| NFR1.4 | 内存占用（空闲） | < 50MB |

### NFR2: 可靠性

| ID | 需求 | 目标 |
|----|------|------|
| NFR2.1 | API 错误自动重试 | 遵循 SDK RetryConfig |
| NFR2.2 | 工具执行超时不崩溃 | 遵循 SDK 超时机制 |
| NFR2.3 | 会话保存失败不丢失对话 | 错误提示但不中断 |
| NFR2.4 | MCP 服务器断连自动重连 | SDK 层处理 |
| NFR2.5 | Ctrl+C 优雅退出 | 保存会话，清理资源 |

### NFR3: 可用性

| ID | 需求 | 目标 |
|----|------|------|
| NFR3.1 | 零配置即可使用（仅需 API Key） | 默认值覆盖所有参数 |
| NFR3.2 | 错误信息可操作 | 告诉用户怎么修，不只是报错 |
| NFR3.3 | 帮助文档完整 | `--help` 和 `/help` 覆盖所有功能 |
| NFR3.4 | 跨平台一致 | macOS 和 Linux 行为一致 |

### NFR4: SDK 验证

| ID | 需求 | 目标 |
|----|------|------|
| NFR4.1 | 零 internal 访问 | 仅使用 `import OpenAgentSDK` |
| NFR4.2 | API 缺口文档化 | 每个需要的 internal 功能记录为 Issue |
| NFR4.3 | 每个 P0 功能验证一个 SDK 模块 | 覆盖 Core、Tools、Stores、Hooks、MCP |
| NFR4.4 | CLI 代码作为 SDK 集成参考 | 代码清晰、有注释 |

## SDK 验证矩阵

CLI 的每个功能对应验证的 SDK 能力：

| CLI 功能 | SDK 模块 | SDK API |
|----------|---------|---------|
| 创建 Agent | Core | `createAgent(options:)`, `AgentOptions` |
| 流式对话 | Core | `agent.stream(_:)`, `AsyncStream<SDKMessage>` |
| 单次对话 | Core | `agent.prompt(_:)`, `QueryResult` |
| 工具加载 | Tools | `getAllBaseTools(tier:)`, `assembleToolPool()` |
| 自定义工具 | Tools | `defineTool()`, `ToolProtocol` |
| 会话持久化 | Stores | `SessionStore`, `AgentOptions.sessionStore` |
| MCP 连接 | MCP | `MCPClientManager`, `McpServerConfig` |
| 钩子注册 | Hooks | `HookRegistry`, `createHookRegistry()` |
| 权限控制 | Types | `PermissionMode`, `CanUseToolFn` |
| 子代理 | Tools/Advanced | `createAgentTool()`, `SubAgentSpawner` |
| 任务管理 | Stores | `TaskStore`, `createTaskCreateTool()` 等 |
| 技能系统 | Tools | `SkillRegistry`, `createSkillTool()` |
| 模型切换 | Core | `agent.switchModel(_:)` |
| Thinking 配置 | Types | `ThinkingConfig`, `AgentOptions.thinking` |
| 成本追踪 | Types | `TokenUsage`, `QueryResult.totalCostUsd` |
| 中断操作 | Core | `agent.interrupt()` |
| Worktree | Stores/Tools | `WorktreeStore`, `createEnterWorktreeTool()` |
| Budget 控制 | Types | `AgentOptions.maxBudgetUsd` |
| AutoCompact | Core | Agent 内置 |
| 日志输出 | Types | `LogLevel`, `LogOutput` |

## 命令行接口设计

```
openagent [选项] [提示词]

模式：
  openagent                    # 交互式 REPL
  openagent "你的问题"          # 单次提问
  echo "问题" | openagent --stdin  # 管道输入

选项：
  --model <model>              # 模型名称（默认：glm-5.1）
  --base-url <url>             # API 基础 URL
  --provider <provider>        # LLM 提供商：anthropic | openai
  --mode <mode>                # 权限模式：default | acceptEdits | bypass | plan | dontAsk | auto
  --tools <tiers>              # 工具层级：core | advanced | specialist | all（默认：core）
  --tool-allow <names>         # 工具白名单（逗号分隔）
  --tool-deny <names>          # 工具黑名单（逗号分隔）
  --mcp <config.json>          # MCP 服务器配置文件路径
  --hooks <config.json>        # 钩子配置文件路径
  --skill-dir <path>           # 技能目录路径
  --skill <name>               # 执行指定技能
  --session <id>               # 恢复指定会话
  --no-restore                 # 不自动恢复最近会话
  --output <format>            # 输出格式：text | json
  --quiet                      # 静默模式，只输出最终结果
  --thinking <budget>          # Thinking token 预算（如 8192）
  --max-turns <n>              # 最大轮次（默认：10）
  --max-budget <usd>           # 最大预算（美元）
  --system-prompt <text>       # 自定义系统提示词
  --log-level <level>          # 日志级别：debug | info | warn | error
  --stdin                      # 从标准输入读取提示词
  --help                       # 显示帮助
  --version                    # 显示版本

REPL 命令：
  /help                        # 显示帮助
  /exit, /quit                 # 退出
  /mode <mode>                 # 切换权限模式
  /model <model>               # 切换模型
  /sessions                    # 列出历史会话
  /resume <id>                 # 恢复会话
  /fork                        # 分叉当前会话
  /mcp status                  # MCP 服务器状态
  /mcp reconnect <name>        # 重连 MCP 服务器
  /skills                      # 列出可用技能
  /clear                       # 清除当前对话
  /cost                        # 显示累计成本
  /tools                       # 列出已加载工具
```

## MVP 范围

### P0 — 核心体验（第一版必须）

1. **REPL 交互** — 流式输入/输出，多轮对话
2. **单次提问** — `openagent "问题"` 直接返回
3. **Core 工具** — Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch
4. **会话自动保存/恢复** — 退出后下次启动继续
5. **权限模式** — 至少支持 default 和 bypassPermissions
6. **MCP 连接** — 通过配置文件加载 MCP 服务器
7. **SubAgent** — Agent 工具可用
8. **流式输出** — 实时显示思考和工具调用过程
9. **中断** — Ctrl+C 中断当前操作不退出
10. **技能加载** — `--skill-dir` 加载技能目录，`--skill <name>` 调用技能

### P1 — 增强体验

10. **Advanced 工具** — Task/Team 工具族
11. **Specialist 工具** — Worktree, Plan, Cron, Todo
12. **Hook 系统** — Shell 钩子配置
13. **Thinking 配置** — Extended Thinking 支持
14. **Markdown 渲染** — 终端友好的格式化输出
15. **成本统计** — `/cost` 命令
16. **权限动态切换** — `/mode` 命令
17. **模型切换** — `/model` 命令

### P2 — 锦上添花

18. **管道模式** — stdin 输入
19. **JSON 输出** — `--output json`
20. **技能系统** — 技能加载和调用
21. **自定义工具注册** — 配置文件注册
22. **会话分叉** — `/fork`
23. **配置文件** — `.openagent/config.yaml`

## 验证完成标准

CLI 项目在以下条件下视为"SDK 验证通过"：

1. **P0 功能全部可用** — 每个 P0 功能都可以通过 public API 实现
2. **零 internal 访问** — 整个 CLI 项目仅使用 `import OpenAgentSDK`
3. **API 缺口清单** — 所有发现的 API 不足都记录为 SDK 项目的 Issue
4. **至少 3 个真实场景端到端验证通过：**
   - 场景 A：多轮编程任务（工具调用 + 会话持久化）
   - 场景 B：MCP 集成 + SubAgent 委派
   - 场景 C：权限控制 + Hook 回调
5. **跨平台** — macOS 和 Linux 均可编译运行

## 技术约束

| 约束 | 说明 |
|------|------|
| **语言** | Swift 5.9+ |
| **平台** | macOS 13+, Linux (Ubuntu 20.04+) |
| **依赖** | 仅 OpenAgentSDK（通过本地 path 引用） |
| **无第三方 CLI 库** | 使用 Foundation + 自定义参数解析（验证 SDK 足够） |
| **构建系统** | Swift Package Manager |
| **不得 fork SDK** | 发现问题时记录 Issue，不在 CLI 中 workaround |
