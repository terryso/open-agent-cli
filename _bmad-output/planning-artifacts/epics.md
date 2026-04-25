---
stepsCompleted: [1, 2, 3, 4, 5]
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
---

# OpenAgentCLI - Epic 分解

## 概述

本文档提供 OpenAgentCLI 的完整 Epic 和 Story 分解，将 PRD 和架构文档中的需求分解为可实施的 Story。项目的使命是**通过仅使用 SDK 的公共 API 构建一个真实的 CLI 应用，系统性地验证 OpenAgentSDK 的综合能力**。

## 需求清单

### 功能需求

FR1.1: CLI 通过 `swift run openagent` 或编译后的二进制启动
FR1.2: 通过环境变量 `OPENAGENT_API_KEY` 或 `--api-key` 参数配置 API Key
FR1.3: 通过 `--model` 参数选择模型，默认 `glm-5.1`
FR1.4: 通过 `--base-url` 参数配置自定义 API 端点 (P1)
FR1.5: 通过 `--provider` 参数选择 LLM 提供商 (P1)
FR1.6: 通过配置文件持久化配置 (P2)

FR2.1: 支持交互式 REPL 模式
FR2.2: 支持单次提问模式：`openagent "问题"` 直接返回
FR2.3: 支持管道模式：`echo "问题" | openagent --stdin` (P2)
FR2.4: REPL 中通过 `/help` 显示可用命令列表
FR2.5: 支持流式输出：实时显示 Agent 的思考和工具调用过程
FR2.6: 支持中断当前操作：Ctrl+C 优雅中断不退出 REPL (P1)

FR3.1: 默认加载所有 Core 层工具
FR3.2: 通过 `--tools advanced` 加载 Advanced 层工具
FR3.3: 通过 `--tools specialist` 加载 Specialist 层工具 (P1)
FR3.4: 通过 `--tool-allow` / `--tool-deny` 白名单/黑名单控制 (P1)
FR3.5: 工具调用过程实时显示：工具名、输入参数摘要、执行耗时

FR4.1: 默认启用会话持久化
FR4.2: 通过 `/sessions` 命令列出历史会话 (P1)
FR4.3: 通过 `/resume <id>` 命令恢复历史会话 (P1)
FR4.4: 通过 `/fork` 命令从当前会话分叉 (P2)
FR4.5: 启动时自动恢复最近一次会话 (P1)

FR5.1: 通过 `--mcp <config.json>` 加载 MCP 服务器配置
FR5.2: 启动时自动连接配置的 MCP 服务器
FR5.3: 通过 `/mcp status` 查看 MCP 连接状态 (P1)
FR5.4: 通过 `/mcp reconnect <name>` 重连 MCP (P2)
FR5.5: MCP 工具与内置工具统一调度

FR6.1: 通过 `--mode` 设置权限模式
FR6.2: 默认模式为 `default`：危险操作需要用户确认
FR6.3: REPL 中通过 `/mode <mode>` 动态切换权限 (P1)
FR6.4: 权限确认提示清晰显示操作内容和风险 (P1)

FR7.1: 通过 `--hooks <config.json>` 加载钩子配置 (P1)
FR7.2: 支持 21 个生命周期事件的 Shell 钩子 (P1)
FR7.3: 钩子执行超时和错误不阻塞主流程 (P1)

FR8.1: Agent 工具自动可用（Advanced 层加载时）
FR8.2: 子代理继承父代理的权限和配置 (P1)
FR8.3: 子代理执行进度实时显示 (P1)
FR8.4: SendMessage 工具支持团队内通信 (P2)

FR9.1: 支持 Markdown 渲染输出 (P1)
FR9.2: 通过 `--output json` 输出结构化 JSON (P2)
FR9.3: 通过 `--quiet` 模式只输出最终结果 (P1)
FR9.4: 显示 token 使用量和成本统计 (P1)
FR9.5: 支持配置 Thinking/Extended Thinking (P1)

FR10.1: 通过 `--skill-dir <path>` 加载技能目录 (P0)
FR10.2: 通过 `--skill <name>` 调用特定技能 (P0)
FR10.3: 在 REPL 中通过 `/skills` 列出可用技能 (P2)
FR10.4: 通过配置文件注册自定义工具 (P2)

FR-DISP1: Turn 标签与视觉分隔 — 用户/AI 输出清晰区分 (P1)
FR-DISP2: Markdown 表格终端渲染 — box-drawing 字符对齐 (P1)
FR-DISP3: 引用块/分割线/链接/标题装饰渲染 (P1)
FR-DISP4: 流式场景下表格缓冲与完整渲染 (P1)

### 非功能需求

NFR1.1: CLI 启动时间 < 2 秒（冷启动）
NFR1.2: 首个 token 延迟 SDK 层开销 < 100ms
NFR1.3: 流式输出延迟 SDK 层 < 50ms per chunk
NFR1.4: 内存占用（空闲）< 50MB

NFR2.1: API 错误自动重试（遵循 SDK RetryConfig）
NFR2.2: 工具执行超时不崩溃
NFR2.3: 会话保存失败不丢失对话
NFR2.4: MCP 服务器断连自动重连
NFR2.5: Ctrl+C 优雅退出（保存会话，清理资源）

NFR3.1: 零配置即可使用（仅需 API Key）
NFR3.2: 错误信息可操作
NFR3.3: 帮助文档完整（`--help` 和 `/help`）
NFR3.4: 跨平台一致（macOS 和 Linux）

NFR4.1: 零 internal 访问（仅 `import OpenAgentSDK`）
NFR4.2: API 缺口文档化
NFR4.3: 每个 P0 功能验证一个 SDK 模块
NFR4.4: CLI 代码作为 SDK 集成参考

### 附加需求（来自架构文档）

- 不使用起始模板——项目已通过 `swift package init` 初始化
- 自定义参数解析器（不使用第三方库）
- 每个文件一个类型的约定
- 基于协议的可测试性（如 `OutputRendering`、`InputReading`）
- 所有 SDK 状态通过 `AgentOptions` 传递
- 信号处理：SIGINT → 中断，SIGTERM → 保存 + 退出
- 配置分层：CLI 参数 > 环境变量 > 配置文件 > SDK 默认值
- MCP 配置复用 SDK 原生的 `McpServerConfig` JSON 格式
- SDK API 缺口使用 `// SDK-GAP:` 注释记录

### FR 覆盖映射

FR1.1: Epic 1 — Story 1.1
FR1.2: Epic 1 — Story 1.2
FR1.3: Epic 1 — Story 1.2
FR1.4: Epic 7 — Story 7.4
FR1.5: Epic 7 — Story 7.4
FR1.6: Epic 7 — Story 7.3

FR2.1: Epic 1 — Story 1.4
FR2.2: Epic 1 — Story 1.5
FR2.3: Epic 7 — Story 7.1
FR2.4: Epic 1 — Story 1.4
FR2.5: Epic 1 — Story 1.3
FR2.6: Epic 5 — Story 5.3

FR3.1: Epic 2 — Story 2.1
FR3.2: Epic 2 — Story 2.1
FR3.3: Epic 6 — Story 6.2
FR3.4: Epic 6 — Story 6.2
FR3.5: Epic 2 — Story 2.2

FR4.1: Epic 3 — Story 3.1
FR4.2: Epic 3 — Story 3.2
FR4.3: Epic 3 — Story 3.2
FR4.4: Epic 7 — Story 7.5
FR4.5: Epic 3 — Story 3.3

FR5.1: Epic 4 — Story 4.1
FR5.2: Epic 4 — Story 4.1
FR5.3: Epic 7 — Story 7.5
FR5.4: Epic 7 — Story 7.5
FR5.5: Epic 4 — Story 4.1

FR6.1: Epic 5 — Story 5.1
FR6.2: Epic 5 — Story 5.1
FR6.3: Epic 6 — Story 6.3
FR6.4: Epic 5 — Story 5.2

FR7.1: Epic 6 — Story 6.1
FR7.2: Epic 6 — Story 6.1
FR7.3: Epic 6 — Story 6.1

FR8.1: Epic 4 — Story 4.2
FR8.2: Epic 4 — Story 4.2
FR8.3: Epic 4 — Story 4.2
FR8.4: Epic 7 — Story 7.5

FR9.1: Epic 6 — Story 6.5
FR9.2: Epic 7 — Story 7.2
FR9.3: Epic 6 — Story 6.4
FR9.4: Epic 1 — Story 1.3
FR9.5: Epic 6 — Story 6.4

FR10.1: Epic 2 — Story 2.3
FR10.2: Epic 2 — Story 2.3
FR10.3: Epic 7 — Story 7.7
FR10.4: Epic 7 — Story 7.7

FR-DISP1: Epic 10 — Story 10.1
FR-DISP2: Epic 10 — Story 10.2
FR-DISP3: Epic 10 — Story 10.2
FR-DISP4: Epic 10 — Story 10.3

## Epic 列表

### Epic 1: 首次对话
用户可以在 5 分钟内安装、配置并与 AI Agent 进行对话。交付 REPL 循环、流式输出、单次提问模式和基础 /help 功能。
**覆盖的 FR：** FR1.1, FR1.2, FR1.3, FR2.1, FR2.2, FR2.4, FR2.5, FR9.4
**覆盖的 NFR：** NFR1.1, NFR1.3, NFR1.4, NFR2.1, NFR3.1
**优先级：** P0 (MVP)

### Epic 2: 带工具的 Agent
用户可以让 Agent 使用内置的 Core 和 Advanced 工具执行真实任务，并提供实时的工具调用可见性和基于技能的提示模板。
**覆盖的 FR：** FR3.1, FR3.2, FR3.5, FR10.1, FR10.2
**优先级：** P0 (MVP)

### Epic 3: 会话连续性
用户可以跨 CLI 重启保存和恢复对话，以及列出/管理历史会话。
**覆盖的 FR：** FR4.1, FR4.2, FR4.3, FR4.5
**优先级：** P0 (MVP)

### Epic 4: 外部集成（MCP 与子代理）
用户可以通过连接 MCP 服务器和委派任务给子代理来扩展 Agent 的能力。
**覆盖的 FR：** FR5.1, FR5.2, FR5.5, FR8.1, FR8.2, FR8.3
**优先级：** P0 (MVP)

### Epic 5: 安全执行与控制
用户可以控制 Agent 被允许做什么、批准危险操作以及中断执行。
**覆盖的 FR：** FR6.1, FR6.2, FR6.4, FR2.6
**优先级：** P0 (MVP)

### Epic 6: 高级功能
用户可以使用钩子、专业工具、富文本输出、思考配置、技能和动态权限切换。
**覆盖的 FR：** FR3.3, FR3.4, FR6.3, FR7.1, FR7.2, FR7.3, FR9.1, FR9.3, FR9.4, FR9.5
**优先级：** P1

### Epic 7: 高级用户与自定义
用户可以使用管道、JSON 输出、配置文件、会话分叉、SendMessage 和自定义工具注册。
**覆盖的 FR：** FR1.4, FR1.5, FR1.6, FR2.3, FR4.4, FR5.3, FR5.4, FR8.4, FR9.2, FR10.3, FR10.4
**优先级：** P2

### Epic 8: 核心使命收尾与质量验证
系统性验证 SDK 集成的完整性，清零所有已知技术债务和 deferred work，确保 CLI 作为 SDK 验证载体的使命圆满完成。
**覆盖的 FR：** NFR4.1, NFR4.2, NFR4.3, NFR4.4
**覆盖的 NFR：** NFR2.5, NFR3.2, NFR3.4
**优先级：** P0

### Epic 10: 终端输出美化
用户在 REPL 中能清晰区分自己的输入和 AI 的各类输出，Markdown 内容（尤其是表格）获得人类友好的终端渲染，整体阅读体验从"原始日志"升级为"结构化对话"。
**覆盖的 FR：** FR-DISP1, FR-DISP2, FR-DISP3, FR-DISP4
**覆盖的 NFR：** NFR3.2, NFR3.4
**优先级：** P1
**依赖：** Epic 1（OutputRenderer 基础设施）, Story 6.5（Markdown 渲染基础）

---

## Epic 1: 首次对话

用户可以在 5 分钟内安装、配置并与 AI Agent 进行对话。此 Epic 交付核心 REPL 体验——使 CLI 有用的最小功能集。

### Story 1.1: CLI 入口与参数解析器

作为一个开发者，
我想要一个能解析命令行参数并启动相应模式的 CLI，
以便我无需编辑配置文件即可配置 Agent。

**验收标准：**

**假设** CLI 已安装
**当** 我运行 `openagent --help`
**那么** 显示帮助信息，列出所有可用参数
**并且** 进程以退出码 0 退出

**假设** 未提供任何参数
**当** 我运行 `openagent`
**那么** CLI 以默认设置进入 REPL 模式

**假设** 提供了带引号的字符串
**当** 我运行 `openagent "what is 2+2?"`
**那么** CLI 以单次提问模式运行并在回答后退出

**假设** 提供了无效参数
**当** 我运行 `openagent --invalid-flag`
**那么** 错误信息解释了无效参数
**并且** 进程以退出码 1 退出

**SDK API：** `AgentOptions`, `createAgent(options:)`
**文件：** `main.swift`, `CLI.swift`, `ArgumentParser.swift`, `Version.swift`, `ANSI.swift`

### Story 1.2: Agent 工厂与核心配置

作为一个开发者，
我想要 CLI 通过 base_url、api_key 和 model 三个核心配置创建 SDK Agent，
以便我能连接到任意兼容的 LLM API（如 GLM、Anthropic、OpenAI 等）。

**验收标准：**

**假设** 传入了 `--api-key <key> --base-url <url> --model <model>`
**当** CLI 创建 Agent
**那么** Agent 使用指定的 base_url、api_key 和 model 连接到 LLM API
**并且** 能够成功获得响应

**假设** 只传入了 `--api-key` 和 `--base-url`，未指定 `--model`
**当** CLI 创建 Agent
**那么** 使用默认模型（`glm-5.1`）创建 Agent

**假设** 通过环境变量 `OPENAGENT_API_KEY` 设置了 API Key
**当** CLI 启动且未传入 `--api-key`
**那么** 使用环境变量中的 API Key 创建 Agent

**假设** 未通过任何方式设置 API Key
**当** CLI 启动
**那么** 显示清晰的错误信息 "请通过 --api-key 参数或 OPENAGENT_API_KEY 环境变量设置 API Key"
**并且** 进程以退出码 1 退出

**假设** 传入了 `--max-turns 5` 和 `--max-budget 1.0`
**当** 创建 Agent
**那么** `AgentOptions.maxTurns` 为 5，`maxBudgetUsd` 为 1.0

**SDK API：** `createAgent(options:)`, `AgentOptions`, `SDK_VERSION`
**文件：** `AgentFactory.swift`

### Story 1.3: 流式输出渲染器

作为一个用户，
我想要看到 Agent 的响应在生成时实时出现，
以便我不必盯着空白屏幕等待完整响应。

**验收标准：**

**假设** Agent 正在流式传输响应
**当** `SDKMessage.assistant(data)` 消息到达
**那么** 文本逐字符输出到标准输出，无缓冲

**假设** Agent 响应完成
**当** `SDKMessage.result(data)` 到达
**那么** 显示汇总行，包括轮次、成本和耗时

**假设** 系统消息到达（如自动压缩）
**当** 收到 `SDKMessage.system(data)`
**那么** 以灰色/暗色文本显示，带有 `[system]` 前缀

**假设** 流式传输过程中发生错误
**当** `SDKMessage.result` 包含错误信息
**那么** 错误以红色显示，并附有可操作的指导

**SDK API：** `AsyncStream<SDKMessage>`, `SDKMessage`（所有变体）
**文件：** `OutputRenderer.swift`, `OutputRenderer+SDKMessage.swift`

### Story 1.4: 交互式 REPL 循环

作为一个用户，
我想要一个交互式提示符，可以持续地输入问题并获得回答，
以便我与 Agent 进行多轮对话。

**验收标准：**

**假设** CLI 处于 REPL 模式
**当** 我看到 `>` 提示符
**那么** 我可以输入消息并按 Enter 发送

**假设** 我在 REPL 中发送了一条消息
**当** Agent 正在处理
**那么** 我看到实时的流式输出

**假设** Agent 完成响应
**当** 流完成
**那么** `>` 提示符重新出现，等待下一条消息

**假设** 我在 REPL 中输入 `/help`
**当** 命令被处理
**那么** 显示可用 REPL 命令列表

**假设** 我在 REPL 中输入 `/exit` 或 `/quit`
**当** 命令被处理
**那么** CLI 优雅退出

**假设** 我输入空行或仅包含空白字符
**当** 输入被读取
**那么** 被忽略，提示符重新出现

**SDK API：** `agent.stream(_:)`, `agent.close()`
**文件：** `REPLLoop.swift`

### Story 1.5: 单次提问模式

作为一个用户，
我想要从命令行运行单个查询并获取结果，
以便我可以将 CLI 集成到脚本和快速任务中。

**验收标准：**

**假设** 传入了提示字符串作为参数
**当** CLI 以单次提问模式运行
**那么** Agent 处理提示并输出响应

**假设** 单次提问响应完成
**当** 结果到达
**那么** CLI 显示响应文本并以退出码 0 退出

**假设** 单次提问模式中发生错误
**当** API 调用失败
**那么** 错误输出到 stderr，CLI 以退出码 1 退出

**SDK API：** `agent.prompt(_:)`, `QueryResult`
**文件：** `CLI.swift`

### Story 1.6: 冒烟测试——性能与可靠性

作为一个开发者，
我想要验证 CLI 满足基本的性能和可靠性目标，
以便我知道 SDK 集成不会引入不可接受的开销。

**验收标准：**

**假设** CLI 在没有先前会话的情况下启动
**当** Agent 创建完成且 `>` 提示符出现
**那么** 启动时间在 2 秒以内（从进程启动到提示符出现）

**假设** Agent 正在流式传输响应
**当** `SDKMessage.assistant` 数据块到达
**那么** 每个数据块的渲染开销在 50ms 以内（无可见延迟）

**假设** 发生 API 错误（如无效模型、速率限制）
**当** SDK 进行重试
**那么** 重试对用户透明，CLI 继续运行

**假设** CLI 在 `>` 提示符空闲
**当** 测量内存使用量
**那么** 保持在 50MB 以内

**SDK API：** `createAgent()`, `AsyncStream<SDKMessage>`, `QueryResult`
**文件：** 通过手动测试验证，非专用源文件

---

## Epic 2: 带工具的 Agent

用户可以让 Agent 使用内置工具执行真实任务，并实时查看 Agent 的操作过程。

### Story 2.1: 核心工具加载与显示

作为一个用户，
我想要 Agent 默认拥有文件和 Shell 工具的访问权限，
以便它能执行真实任务，如读取文件和运行命令。

**验收标准：**

**假设** CLI 以默认设置启动
**当** 创建 Agent
**那么** 加载 Core 层工具（Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, AskUser, ToolSearch）

**假设** CLI 使用 `--tools advanced` 启动
**当** 创建 Agent
**那么** 同时加载 Core 和 Advanced 层工具

**假设** 指定了 `--tools all`
**当** 创建 Agent
**那么** Core + Advanced + Specialist 层工具全部加载

**假设** 工具已加载
**当** 我在 REPL 中输入 `/tools`
**那么** 显示已加载的工具名称列表

**SDK API：** `getAllBaseTools(tier:)`, `assembleToolPool()`, `ToolTier`
**文件：** `AgentFactory.swift`

### Story 2.2: 工具调用可见性

作为一个用户，
我想要实时看到 Agent 调用了哪些工具，
以便我了解 Agent 在做什么并能调试问题。

**验收标准：**

**假设** Agent 在响应过程中调用了一个工具
**当** `SDKMessage.toolUse(data)` 到达
**那么** 以青色高亮显示一行，展示工具名称和输入参数摘要

**假设** 工具返回结果
**当** `SDKMessage.toolResult(data)` 到达
**那么** 显示结果文本（超过 500 字符时截断）
**并且** 如果 `isError` 为 true，结果以红色显示

**假设** Agent 进行多个连续的工具调用
**当** 它们在流中到达
**那么** 每个工具调用按顺序实时显示

**SDK API：** `SDKMessage.toolUse`, `SDKMessage.toolResult`
**文件：** `OutputRenderer+SDKMessage.swift`

### Story 2.3: 技能加载与调用

作为一个用户，
我想要从目录加载技能定义并调用特定技能，
以便我可以使用预定义的提示模板处理常见任务，无需重启。

**验收标准：**

**假设** 技能目录包含有效的技能定义
**当** 我运行 `openagent --skill-dir ./skills`
**那么** 技能被加载到 SDK 的 `SkillRegistry` 中

**假设** 传入了 `--skill review`
**当** CLI 启动
**那么** 自动调用 "review" 技能

**假设** 技能已加载
**当** 我在 REPL 中输入 `/skills`
**那么** 列出可用技能及其名称和描述

**假设** 提供了无效的技能名称
**当** 我运行 `openagent --skill nonexistent`
**那么** 错误信息显示 "Skill not found" 并列出可用技能

**SDK API：** `SkillRegistry`, `createSkillTool()`, `Skill`, `AgentOptions.skillDirectories`
**文件：** `AgentFactory.swift`, `REPLLoop.swift`

---

## Epic 3: 会话连续性

用户可以跨 CLI 重启保存和恢复对话，因此不会丢失上下文。

### Story 3.1: 退出时自动保存会话

作为一个用户，
我想要在退出 CLI 时自动保存对话，
以便我稍后可以接着上次的进度继续。

**验收标准：**

**假设** CLI 在 REPL 模式下运行，且会话持久化已启用（默认）
**当** 我输入 `/exit` 或 Ctrl+D
**那么** 当前会话通过 SDK 的 SessionStore 保存

**假设** 会话保存失败（如磁盘已满）
**当** 保存操作出错
**那么** 显示警告但 CLI 仍然正常退出

**假设** CLI 以 `--no-restore` 启动
**当** 配置会话时
**那么** 自动恢复被禁用，但自动保存仍然有效

**SDK API：** `AgentOptions.sessionStore`, `AgentOptions.persistSession`, `AgentOptions.sessionId`
**文件：** `SessionManager.swift`

### Story 3.2: 列出和恢复历史会话

作为一个用户，
我想要查看过去的对话并恢复其中一个，
以便我可以继续之前的任务。

**验收标准：**

**假设** 存在已保存的会话
**当** 我在 REPL 中输入 `/sessions`
**那么** 显示历史会话列表，包括 ID、日期和首条消息预览

**假设** 我有一个会话 ID
**当** 我在 REPL 中输入 `/resume <id>`
**那么** CLI 加载该会话并继续对话

**假设** 提供了无效的会话 ID
**当** 我输入 `/resume invalid-id`
**那么** 错误信息显示 "Session not found"

**SDK API：** `AgentOptions.sessionId`, `AgentOptions.continueRecentSession`, `SessionStore`
**文件：** `REPLLoop.swift`（斜杠命令）, `SessionManager.swift`

### Story 3.3: 启动时自动恢复上次会话

作为一个用户，
我想要 CLI 在启动时自动继续上次的对话，
以便我不必每次都手动恢复。

**验收标准：**

**假设** 存在最近的已保存会话
**当** CLI 以 REPL 模式启动（不带 `--no-restore`）
**那么** 自动加载并继续上次的会话

**假设** 传入了 `--session <id>`
**当** CLI 启动
**那么** 加载指定会话而非最近的会话

**假设** 传入了 `--no-restore`
**当** CLI 启动
**那么** 无论是否有已保存的会话，都启动新会话

**假设** 会话恢复失败（文件损坏）
**当** CLI 启动
**那么** 显示警告并启动新会话

**SDK API：** `AgentOptions.continueRecentSession`, `AgentOptions.sessionId`
**文件：** `SessionManager.swift`, `CLI.swift`

---

## Epic 4: 外部集成（MCP 与子代理）

用户可以通过连接 MCP 服务器和委派任务给子代理来扩展 Agent 的能力。

### Story 4.1: MCP 服务器配置与连接

作为一个用户，
我想要将外部 MCP 工具服务器连接到我的 Agent，
以便 Agent 可以使用我定义的工具（如数据库、API、自定义服务）。

**验收标准：**

**假设** 存在有效的 MCP 配置 JSON 文件 `./mcp-config.json`
**当** 我运行 `openagent --mcp ./mcp-config.json`
**那么** MCP 服务器在启动时连接

**假设** MCP 服务器已配置
**当** Agent 创建其工具池
**那么** MCP 工具与内置工具一起被包含

**假设** MCP 服务器连接失败
**当** CLI 启动
**那么** 显示警告，列出失败的服务器，但 CLI 继续运行

**假设** MCP 配置文件不存在
**当** 我运行 `openagent --mcp nonexistent.json`
**那么** 清晰的错误信息显示 "MCP config file not found"
**并且** CLI 以退出码 1 退出

**SDK API：** `McpServerConfig`, `McpStdioConfig`, `AgentOptions.mcpServers`
**文件：** `MCPConfigLoader.swift`, `AgentFactory.swift`

### Story 4.2: 子代理委派

作为一个用户，
我想要 Agent 为复杂任务生成子代理，
以便工作可以并行化或委派给专门的 Agent。

**验收标准：**

**假设** 指定了 `--tools advanced`
**当** Agent 创建其工具池
**那么** 包含 Agent 工具（子代理生成器）

**假设** Agent 决定生成子代理
**当** 子代理运行
**那么** 其输出在终端中可见，带有缩进前缀

**假设** 子代理完成
**当** 返回结果
**那么** 父代理使用子代理的输出继续

**假设** 父代理有权限模式和 API 配置
**当** 子代理被生成
**那么** 子代理继承父代理的权限模式和 API 配置

**假设** 子代理正在执行
**当** 产生进度消息
**那么** 进度在终端中以缩进的 `[sub-agent]` 前缀显示

**SDK API：** `createAgentTool()`, `AgentOptions.agentName`, `PermissionMode`
**文件：** `AgentFactory.swift`, `OutputRenderer+SDKMessage.swift`

---

## Epic 5: 安全执行与控制

用户可以控制 Agent 被允许做什么，并在需要时中断执行。

### Story 5.1: 权限模式配置

作为一个用户，
我想要控制 Agent 的权限级别，
以便我可以防止意外的破坏性操作。

**验收标准：**

**假设** 传入了 `--mode bypassPermissions`
**当** 创建 Agent
**那么** 所有工具执行无需审批即可进行

**假设** 传入了 `--mode default`（或未指定 --mode）
**当** Agent 尝试执行危险工具（如带 rm 的 Bash）
**那么** 提示用户批准或拒绝该操作

**假设** 传入了 `--mode plan`
**当** Agent 提出计划
**那么** 用户必须在执行开始前批准

**假设** 提供了无效的模式字符串
**当** 传入 `--mode invalid`
**那么** 错误信息列出有效模式并退出

**SDK API：** `PermissionMode`, `AgentOptions.permissionMode`, `CanUseToolFn`
**文件：** `ArgumentParser.swift`, `AgentFactory.swift`, `PermissionHandler.swift`

### Story 5.2: 交互式权限提示

作为一个用户，
我想要在 Agent 请求权限时看到清晰的提示，
以便我了解它即将做什么并能做出明智的决定。

**验收标准：**

**假设** Agent 请求执行危险工具
**当** 权限回调触发
**那么** 提示显示：工具名称、输入参数摘要和风险级别

**假设** 权限提示已显示
**当** 我输入 `y` 或 `yes`
**那么** 工具执行继续

**假设** 权限提示已显示
**当** 我输入 `n` 或 `no`
**那么** 工具执行被拒绝，Agent 收到通知

**SDK API：** `CanUseToolFn`, `ToolContext`
**文件：** `PermissionHandler.swift`, `OutputRenderer.swift`

### Story 5.3: 优雅的中断处理

作为一个用户，
我想要在 Agent 响应过程中中断它而不丢失会话，
以便我可以重定向或停止失控的任务。

**验收标准：**

**假设** Agent 正在流式传输响应
**当** 我按下 Ctrl+C
**那么** 通过 `agent.interrupt()` 中断当前 Agent 操作
**并且** REPL 提示符重新出现

**假设** Agent 正在等待权限提示
**当** 我按下 Ctrl+C
**那么** 操作被取消，REPL 继续

**假设** 我在 1 秒内按了两次 Ctrl+C
**当** 处于 REPL 模式
**那么** CLI 立即退出

**假设** 收到 SIGTERM 信号
**当** CLI 正在运行
**那么** 会话被保存，进程干净退出

**SDK API：** `agent.interrupt()`, `agent.close()`
**文件：** `REPLLoop.swift`, `CLI.swift`

---

## Epic 6: 高级功能

用户可以使用钩子、专业工具、富文本输出、思考配置、技能和动态控制。

### Story 6.1: 钩子系统集成

作为一个用户，
我想要在 Agent 生命周期事件上配置 Shell 钩子，
以便我可以记录日志、审计或转换 Agent 的行为。

**验收标准：**

**假设** 存在钩子配置 JSON 文件
**当** 我运行 `openagent --hooks ./hooks.json`
**那么** 钩子通过 SDK 的 `createHookRegistry()` 注册

**假设** 为 `beforeToolCall` 事件配置了钩子
**当** Agent 调用工具
**那么** 钩子脚本在工具运行之前执行

**假设** 钩子脚本超时或出错
**当** 执行时
**那么** 记录警告但 Agent 操作继续

**SDK API：** `createHookRegistry()`, `HookRegistry`, `HookDefinition`, `HookEvent`
**文件：** `HookConfigLoader.swift`, `AgentFactory.swift`

### Story 6.2: 专业工具与工具过滤

作为一个用户，
我想要加载专业工具并控制哪些工具可用，
以便我可以根据任务定制 Agent 的能力。

**验收标准：**

**假设** 传入了 `--tools specialist`
**当** 创建 Agent
**那么** 加载 Worktree、Plan、Cron、TodoWrite、LSP、Config、RemoteTrigger、MCP Resource 工具

**假设** 传入了 `--tool-deny "Bash,Write"`
**当** Agent 创建其工具池
**那么** Bash 和 Write 工具被排除

**假设** 传入了 `--tool-allow "Read,Grep,Glob"`
**当** Agent 创建其工具池
**那么** 仅有 Read、Grep 和 Glob 工具可用

**SDK API：** `getAllBaseTools(tier:)`, `filterTools()`, `assembleToolPool()`
**文件：** `AgentFactory.swift`

### Story 6.3: 动态 REPL 命令

作为一个用户，
我想要在对话过程中切换模型和权限模式，
以便我可以无需重启即可调整 Agent 的行为。

**验收标准：**

**假设** 我处于 REPL 会话中
**当** 我输入 `/model claude-opus-4-7`
**那么** Agent 切换到指定模型

**假设** 我处于 REPL 会话中
**当** 我输入 `/mode plan`
**那么** 权限模式切换到计划模式

**假设** 我在 REPL 中输入 `/cost`
**那么** 显示会话的累计 token 使用量和成本

**假设** 我在 REPL 中输入 `/clear`
**那么** 当前对话历史被清除，开始新会话

**SDK API：** `agent.switchModel(_:)`, `agent.setPermissionMode(_:)`, `agent.getMessages()`
**文件：** `REPLLoop.swift`

### Story 6.4: 思考配置与安静模式

作为一个用户，
我想要启用扩展思考并控制输出详细程度，
以便我可以获得更深层的推理或更干净的脚本输出。

**验收标准：**

**假设** 传入了 `--thinking 8192`
**当** 创建 Agent
**那么** `AgentOptions.thinking` 配置为 8192 预算 token

**假设** 传入了 `--quiet`
**当** Agent 处理查询
**那么** 仅显示最终的助手文本（无工具调用、无系统消息）

**假设** 思考功能已启用
**当** Agent 使用扩展思考
**那么** 思考输出以暗色/不同样式显示

**SDK API：** `ThinkingConfig`, `AgentOptions.thinking`, `AgentOptions.maxThinkingTokens`
**文件：** `ArgumentParser.swift`, `OutputRenderer+SDKMessage.swift`

### Story 6.5: Markdown 终端渲染

作为一个用户，
我想要 Agent 的响应在终端中以基本 Markdown 格式渲染，
以便代码块、标题和列表清晰可读。

**验收标准：**

**假设** Agent 以 Markdown 格式的文本响应
**当** 在终端中渲染
**那么** 代码块带有可视边框显示
**并且** 标题加粗显示
**并且** 列表正确缩进

**假设** 检测到终端宽度
**当** 渲染长行时
**那么** 文本在终端宽度边界处换行

**SDK API：** 无（仅终端渲染）
**文件：** `OutputRenderer+SDKMessage.swift`, `ANSI.swift`

---

## Epic 7: 高级用户与自定义

用户可以使用管道、JSON 输出、配置文件和其他高级功能进行脚本编写和自定义。

### Story 7.1: 管道/标准输入模式

作为一个用户，
我想要将输入通过管道传入 CLI，
以便我可以将其集成到 Shell 脚本和管道中。

**验收标准：**

**假设** 通过标准输入管道输入
**当** 我运行 `echo "explain this" | openagent --stdin`
**那么** CLI 从标准输入读取并处理输入

**假设** 同时提供了标准输入和位置参数
**当** CLI 启动
**那么** 位置参数优先

**SDK API：** `agent.prompt(_:)`
**文件：** `CLI.swift`

### Story 7.2: JSON 输出模式

作为一个开发者，
我想要从 CLI 获取结构化的 JSON 输出，
以便我可以程序化地解析 Agent 的响应。

**验收标准：**

**假设** 传入了 `--output json`
**当** Agent 完成查询
**那么** 结果以 JSON 对象打印，包含 `text`、`toolCalls`、`cost` 和 `turns` 字段

**假设** JSON 输出模式处于活动状态
**当** 发生错误
**那么** 错误以 JSON 格式打印到标准输出，格式为 `{"error": "..."}`

**SDK API：** `QueryResult`, `SDKMessage`
**文件：** `OutputRenderer.swift`

### Story 7.3: 持久化配置文件

作为一个用户，
我想要将 CLI 配置保存在文件中，
以便我不必每次都传入参数。

**验收标准：**

**假设** 配置文件存在于 `~/.openagent/config.json`
**当** CLI 启动
**那么** 配置文件中的设置作为默认值应用

**假设** 配置文件和 CLI 参数同时指定了相同的设置
**当** CLI 启动
**那么** CLI 参数覆盖配置文件中的值

**SDK API：** `AgentOptions`
**文件：** `CLI.swift`, `ArgumentParser.swift`

### Story 7.4: 多提供商支持

作为一个用户，
我想要使用非 Anthropic 的 LLM 提供商，
以便我可以将 CLI 与 OpenAI 或其他兼容的 API 一起使用。

**验收标准：**

**假设** 传入了 `--provider openai --base-url https://api.openai.com/v1`
**当** 创建 Agent
**那么** 使用兼容 OpenAI 的客户端

**假设** 传入了 `--provider anthropic`（或默认）
**当** 创建 Agent
**那么** 使用 Anthropic 客户端

**SDK API：** `LLMProvider`, `AgentOptions.provider`, `AgentOptions.baseURL`
**文件：** `AgentFactory.swift`

### Story 7.5: 会话分叉

作为一个高级用户，
我想要从当前节点分叉对话，
以便我可以探索替代方案而不丢失原始上下文。

**验收标准：**

**假设** 我处于带有对话历史的 REPL 会话中
**当** 我输入 `/fork`
**那么** 从当前对话状态创建一个新的分支会话

**假设** 分叉完成
**当** 我继续对话
**那么** 新会话从此处开始拥有独立的后续历史

**SDK API：** `AgentOptions.forkSession`
**文件：** `REPLLoop.swift`, `SessionManager.swift`

### Story 7.6: 动态 MCP 管理

作为一个高级用户，
我想要在会话中检查和重新连接 MCP 服务器，
以便我可以排查连接问题而无需重启。

**验收标准：**

**假设** MCP 服务器已连接
**当** 我输入 `/mcp status`
**那么** 显示每个服务器的连接状态

**假设** MCP 服务器断开连接
**当** 我输入 `/mcp reconnect <name>`
**那么** 服务器重新连接

**假设** 提供了不存在的服务器名称
**当** 我输入 `/mcp reconnect nonexistent`
**那么** 错误信息显示 "Server not found"

**SDK API：** `agent.mcpServerStatus()`, `agent.reconnectMcpServer()`
**文件：** `REPLLoop.swift`

### Story 7.7: 技能列表与自定义工具注册

作为一个高级用户，
我想要列出可用技能并通过配置注册自定义工具，
以便我可以发现和扩展 Agent 的能力。

**验收标准：**

**假设** 技能已加载
**当** 我在 REPL 中输入 `/skills`
**那么** 列出可用技能及其名称和描述

**假设** 配置文件指定了自定义工具
**当** CLI 使用该配置启动
**那么** 自定义工具被注册并可供 Agent 使用

**SDK API：** `SkillRegistry`, `defineTool()`
**文件：** `REPLLoop.swift`, `CLI.swift`

---

## Epic 8: 核心使命收尾与质量验证

系统性验证 SDK 集成的完整性，清零所有已知技术债务和 deferred work，确保 CLI 作为 SDK 验证载体的使命圆满完成。

### Story 8.1: Technical Debt Cleanup

**状态：已完成** (2026-04-22)

作为一个开发者和维护者，
我想要一次性清理所有已知的 deferred work 和技术债务，
以便代码库在后续开发前处于健康、安全和可维护的状态。

**验收标准：**

**AC#1: 消除所有 force-unwrap `data(using: .utf8)!`** — 已完成
- 16 处 force-unwrap 全部替换为安全的 `ANSI.writeToStderr()` 或 `?? Data()` fallback

**AC#2: 修复 handleFork/handleResume 的 ParsedArgs 字段遗漏** — 已完成
- 改用 struct copy (`var forkArgs = args`) 替代手动逐字段构造

**AC#3: 修复 stdin 在终端下无限阻塞** — 已完成
- 添加 `isatty(STDIN_FILENO)` 检查，终端 stdin 直接报错退出

**AC#4: 修复 --stdin + --skill 组合的未定义行为** — 已完成
- 添加互斥校验，明确错误提示

**AC#5: 修复单次提问 + default/plan 模式下静默拒绝写工具** — 已完成
- 非交互模式改为 auto-approve 并显示警告

**AC#6: 为 CostTracker 添加 Sendable 一致性** — 已完成
- 标记为 `@unchecked Sendable`

**AC#7: 清理孤立的 fork 会话** — 已完成
- AgentFactory 失败时自动删除已创建的 session

**测试覆盖：** 28 个专用测试 + 13+ 回归测试，628 全量测试通过

**SDK API：** `PermissionMode`, `SessionStore.delete()`, `AgentOptions`
**文件：** `ANSI.swift`, `CLI.swift`, `ConfigLoader.swift`, `AgentFactory.swift`, `REPLLoop.swift`, `PermissionHandler.swift`, `ArgumentParser.swift`

### Story 8.2: 端到端场景验证补全

作为一个 SDK 验证者，
我想要通过多轮真实场景验证 CLI 与 SDK 的集成完整性，
以便确认 SDK 的公共 API 足以支撑一个功能完整的 Agent 应用。

**验收标准：**

**假设** CLI 已编译且配置了有效的 API Key
**当** 执行多轮编程任务（包含工具调用链）
**那么** Agent 正确调用 Write/Bash/Edit 工具完成文件创建、编译、修改的完整流程
**并且** 工具调用过程实时可见（工具名、参数摘要、耗时）

**假设** 存在有效的 MCP 服务器配置
**当** CLI 使用 `--mcp` 启动并提交需要 MCP 工具的任务
**那么** MCP 工具被发现、调用并返回结果
**并且** `/mcp status` 正确显示连接状态

**假设** CLI 以 `--mode default` 启动
**当** Agent 请求执行需要权限确认的工具
**那么** 在交互模式下弹出权限提示，非交互模式下自动批准
**并且** `/mode` 动态切换生效

**假设** CLI 在 REPL 模式下进行了多轮对话
**当** 用户执行 `/exit` 退出后重新启动 CLI
**那么** 自动恢复上次会话，对话历史完整保留
**并且** 新对话能引用之前的上下文

**SDK API：** `agent.stream(_:)`, `agent.interrupt()`, `McpServerConfig`, `PermissionMode`, `SessionStore`
**文件：** `Tests/OpenAgentE2ETests/E2ETests.swift`

### Story 8.3: Deferred Work 清零

作为一个项目维护者，
我想要关闭 deferred-work.md 中所有未解决的已知问题，
以便项目不存在"已知但未记录优先级"的遗留项。

**验收标准：**

**假设** `deferred-work.md` 中存在未关闭项
**当** 逐一处理每项
**那么** 每项要么被修复（附测试验证），要么被明确标记为"永久接受"并附理由
**并且** deferred-work.md 中不再有 open 状态的条目

**具体待处理项：**

1. `testCreateAgent_sessionSavedToDisk_afterClose lacks disk-write verification` — 补充磁盘写入验证或标记为永久接受（SDK 内部已覆盖）
2. `Misleading error message in registry guard` — 修正 CLI.swift 中 "Skill not found" 的错误信息，区分"注册表不存在"和"技能名不存在"
3. `Missing test for --skill + positional prompt combined path` — 补充 `--skill review "extra context"` 组合路径的测试

**SDK API：** `SessionStore`, `SkillRegistry`
**文件：** `CLI.swift`, `Tests/OpenAgentCLITests/`

---

## Epic 9: REPL 体验升级

用户在 REPL 中获得现代 CLI 工具的基本交互能力 — 启动欢迎界面、彩色状态提示、历史回溯、Tab 补全和多行输入。REPL 从"能用"变成"顺手"。

**覆盖的 FR：** FR-REPL1 (Tab 补全), FR-REPL2 (历史回溯), FR-REPL3 (多行输入), FR-REPL4 (欢迎界面), FR-REPL5 (彩色提示符)
**覆盖的 NFR：** NFR3.1 (零配置), NFR3.4 (跨平台)
**优先级：** P1
**依赖：** Epic 1（REPL 基础设施）
**技术方案：** 引入 [linenoise-swift](https://github.com/andybest/linenoise-swift)（纯 Swift 的 readline 替代品）作为 SPM 依赖，替代手写的 `FileHandleInputReader`。linenoise 提供行编辑、Emacs 快捷键、历史记录、Tab 补全回调，macOS + Linux 跨平台，零系统依赖。

### FR 覆盖映射（Epic 9）

FR-REPL4: Epic 9 — Story 9.1
FR-REPL5: Epic 9 — Story 9.2
FR-REPL2: Epic 9 — Story 9.3
FR-REPL1: Epic 9 — Story 9.4
FR-REPL3: Epic 9 — Story 9.5

### Story 9.1: 欢迎界面

作为一个用户，
我想要在 CLI 启动时看到当前配置概要，
以便我一眼就知道当前模型、工具和权限设置。

**验收标准：**

**假设** CLI 以默认设置启动 REPL 模式
**当** REPL 就绪（`>` 提示符出现前）
**那么** 显示欢迎信息，包含：
  - CLI 版本（`CLIVersion.current`）
  - 当前模型名
  - 已加载工具数量
  - 当前权限模式

**假设** CLI 以 `--quiet` 模式启动
**当** REPL 就绪
**那么** 不显示欢迎信息

**假设** CLI 以 `--output json` 模式启动
**当** REPL 就绪
**那么** 不显示欢迎信息

**假设** CLI 以单次提问模式启动（带位置参数）
**当** 执行查询
**那么** 不显示欢迎信息

**SDK API：** 无（纯输出）
**文件：** `CLI.swift`（在 REPL 启动前添加欢迎信息输出）

### Story 9.2: 彩色提示符

作为一个用户，
我想要提示符 `>` 根据当前权限模式显示不同颜色，
以便我一眼就能识别当前的安全级别。

**验收标准：**

**假设** CLI 以默认模式（`default`）启动
**当** `>` 提示符显示
**那么** 使用绿色（`\u{001B}[32m`）

**假设** CLI 以 `--mode plan` 启动
**当** `>` 提示符显示
**那么** 使用黄色（`\u{001B}[33m`）

**假设** CLI 以 `--mode bypassPermissions` 启动
**当** `>` 提示符显示
**那么** 使用红色（`\u{001B}[31m`）

**假设** 权限模式为 `acceptEdits`
**当** `>` 提示符显示
**那么** 使用蓝色（`\u{001B}[34m`）

**假设** 权限模式为 `auto` 或 `dontAsk`
**当** `>` 提示符显示
**那么** 使用白色/默认色（`\u{001B}[0m`）

**假设** 我在 REPL 中执行 `/mode plan`
**当** 模式切换成功
**那么** 下一个 `>` 提示符变为黄色

**假设** 终端不支持 ANSI 颜色
**当** `>` 提示符显示
**那么** 回退为无颜色的普通 `>`

**SDK API：** `PermissionMode`
**文件：** `REPLLoop.swift`（prompt 渲染逻辑）, `ANSI.swift`（颜色常量）

### Story 9.3: 历史回溯

作为一个用户，
我想要用上下箭头翻阅之前输入的命令，
以便快速重复或修改之前的输入。

**验收标准：**

**假设** 我在当前会话中已输入 3 条消息（"hello", "list files", "show cost"）
**当** 我按上箭头
**那么** 提示符显示 "show cost"
**当** 我再按上箭头
**那么** 显示 "list files"
**当** 我按下箭头
**那么** 显示 "show cost"

**假设** 我在历史中间位置修改了内容
**当** 我按上箭头到某条历史，修改了内容，然后按回车发送
**那么** 发送修改后的内容
**并且** 原始历史条目保持不变

**假设** 我退出并重新启动 CLI
**当** 我按上箭头
**那么** 可以看到上次会话的历史输入

**假设** 历史文件 `~/.openagent/history` 不存在
**当** CLI 启动
**那么** 自动创建文件，从空历史开始

**假设** 历史文件超过 1000 条
**当** 新输入被记录
**那么** 最早的条目被移除（FIFO）

**假设** 历史文件损坏或不可读
**当** CLI 启动
**那么** 显示警告但正常启动，从空历史开始

**SDK API：** 无（纯终端交互 + 文件 I/O）
**文件：** `LinenoiseInputReader.swift`（新建，替换 `FileHandleInputReader`）, `Package.swift`（添加 linenoise-swift 依赖）
**实现说明：** 此 Story 引入 [linenoise-swift](https://github.com/andybest/linenoise-swift) 并创建 `LinenoiseInputReader` 作为 `InputReading` 协议的新实现。linenoise 内置提供：
  - 行编辑（Emacs 快捷键：Ctrl+A/E 跳首尾，Ctrl+U/K 删行，Ctrl+W 删词）
  - 历史记录（上下箭头浏览）
  - 历史持久化（`Linenoise.saveHistory()` / `loadHistory()`）
  - 跨平台（macOS + Linux）
  - 保留 `FileHandleInputReader` 作为非交互模式（单次提问、stdin 管道）的回退实现

### Story 9.4: Tab 命令补全

作为一个用户，
我想要在输入 `/` 命令时按 Tab 自动补全，
以便我不需要记住所有命令的精确拼写。

**验收标准：**

**假设** 我处于 REPL 模式
**当** 我输入 `/m` 并按 Tab
**那么** 自动补全为 `/mode`（唯一匹配）

**假设** 我输入 `/` 并按 Tab
**那么** 列出所有可用的 `/` 命令（`/help`, `/exit`, `/quit`, `/tools`, `/skills`, `/model`, `/mode`, `/cost`, `/clear`, `/sessions`, `/resume`, `/fork`, `/mcp`）

**假设** 我输入 `/mcp ` 并按 Tab
**那么** 列出 MCP 子命令（`status`, `reconnect`）

**假设** 我输入 `/mode ` 并按 Tab
**那么** 列出所有有效权限模式

**假设** 我输入非 `/` 开头的普通文本并按 Tab
**那么** 不触发补全，保持输入不变

**假设** 存在多个匹配前缀
**当** 我输入 `/s` 并按 Tab
**那么** 列出 `/sessions`, `/skills` 等匹配项
**并且** 输入保持 `/s` 不变

**SDK API：** 无（纯终端交互）
**文件：** `LinenoiseInputReader.swift`（注册 `completionCallback`）, `REPLLoop.swift`（补全候选列表）
**实现依赖：** Story 9.3（需要 `LinenoiseInputReader` 基础）
**实现说明：** 利用 linenoise 的 `completionCallback` API，根据当前输入前缀返回匹配的补全候选列表。补全逻辑在 REPLLoop 中维护（命令名、子命令、模式名），LinenoiseInputReader 在初始化时注册回调。

### Story 9.5: 多行输入

作为一个用户，
我想要用 `\` 续行或 `"""` 包裹输入多行文本，
以便我可以方便地粘贴代码或多段提示词。

**验收标准：**

**假设** 我输入 `这是一个长问题 \` 并按回车
**当** 提示符变为 `...>`
**那么** 我可以继续输入下一行
**当** 输入完整内容后按回车（无 `\` 结尾）
**那么** 所有行合并为一个完整输入发送给 Agent

**假设** 我输入 `"""` 并按回车
**当** 提示符变为 `...>`
**那么** 进入多行模式
**当** 我输入多行内容后再输入 `"""` 并按回车
**那么** `"""` 之间的所有内容（包括换行）作为一个完整输入发送

**假设** 我在多行模式中按 Ctrl+C
**那么** 取消当前多行输入，回到 `>` 提示符

**假设** 我输入以 `\` 结尾但后面有空白字符（如 `hello \  `）
**当** 按回车
**那么** 忽略末尾空白，正确识别为续行

**SDK API：** 无（纯终端交互）
**文件：** `REPLLoop.swift`（多行状态机：检测 `\` 和 `"""`，累积行缓冲，切换 prompt）
**实现依赖：** Story 9.3（需要 `LinenoiseInputReader`）
**实现说明：** linenoise 是行导向的（每次 `readLine` 返回一行）。多行逻辑在 REPLLoop 层实现：检测行尾 `\` 或独立的 `"""` 标记，切换 prompt 为 `...>`，累积行直到满足终止条件后合并发送。

---

## Epic 10: 终端输出美化

用户在 REPL 中能清晰区分自己的输入和 AI 的各类输出，Markdown 内容（尤其是表格）获得人类友好的终端渲染，整体阅读体验从"原始日志"升级为"结构化对话"。

**覆盖的 FR：** FR-DISP1 (Turn 标签), FR-DISP2 (表格渲染), FR-DISP3 (引用块/分割线/链接), FR-DISP4 (流式表格缓冲)
**覆盖的 NFR：** NFR3.2 (输出可读), NFR3.4 (跨平台)
**优先级：** P1
**依赖：** Epic 1（OutputRenderer 基础设施）, Story 6.5（Markdown 渲染基础）
**技术方案：** 在现有 `MarkdownRenderer` 和 `OutputRenderer` 基础上增强，不引入新的 SPM 依赖。所有渲染基于 ANSI escape codes + Unicode box-drawing characters。

### 当前痛点

1. **角色混淆**：用户输入和 AI 输出视觉上无法区分，没有标签头或分隔
2. **Markdown 表格裸显示**：`| Name | Status |` 管道符原文直出，难以阅读
3. **其他 Markdown 元素未渲染**：引用块 (`> quote`)、水平分割线 (`---`)、链接 (`[text](url)`) 以原文显示
4. **标题装饰不足**：H1/H2 仅加粗，缺乏视觉层次感

### FR 覆盖映射（Epic 10）

FR-DISP1: Epic 10 — Story 10.1
FR-DISP2: Epic 10 — Story 10.2
FR-DISP3: Epic 10 — Story 10.2
FR-DISP4: Epic 10 — Story 10.3

### Story 10.1: Turn 标签与视觉分隔

作为一个用户，
我想要清楚地看到哪些是我说的、哪些是 AI 回复的，
以便我在多轮对话中不会迷失上下文。

**验收标准：**

**假设** AI 开始回复文本
**当** `SDKMessage.partialMessage` 第一个 chunk 到达
**那么** 在文本前输出蓝色 `● ` 前缀（`\u{001B}[34m●\u{001B}[0m `）
**并且** 后续 chunk 不再重复输出前缀

**假设** 一个完整的 Agent turn 结束
**当** `SDKMessage.result(data)` 到达且 `subtype == .success`
**那么** 在 result 分隔线前输出一个空行，视觉上与下一个 turn 分隔

**假设** 用户输入一条消息
**当** 消息被发送到 Agent
**那么** 用户输入行上方显示绿色 `> ` 前缀（已有，无需改动）

**假设** 工具调用被触发
**当** `SDKMessage.toolUse` 到达
**那么** 工具调用行保持青色 `> toolName(args)`（已有），但在首个工具调用前输出空行与 AI 文本分隔

**假设** 工具结果返回
**当** `SDKMessage.toolResult` 到达
**那么** 结果保持灰色缩进显示（已有）

**假设** 系统消息到达
**当** `SDKMessage.system` 到达
**那么** 保持灰色 `[system]` 前缀（已有），前加空行分隔

**假设** AI 回复过程中出现错误
**当** `SDKMessage.assistant` 包含 error
**那么** 错误信息以红色显示（已有），前加空行分隔

**颜色方案总览：**

| 元素 | 前缀 | ANSI 颜色 | 示例 |
|------|------|-----------|------|
| 用户输入 | `> ` | 绿色 (32) | `> hello` |
| AI 文本 | `● ` | 蓝色 (34) | `● Here is the answer...` |
| 工具调用 | `> ` | 青色 (36) | `> Read(file_path: ...)` |
| 工具结果 | `  ` (缩进) | 默认/dim | `  file contents...` |
| 系统消息 | `[system]` | dim (2) | `[system] compaction...` |
| 错误 | `Error:` | 红色 (31) | `Error: rate limit` |
| 分隔线 | `---` | dim (2) | `--- Turns: 1 | Cost: ...` |

**SDK API：** `SDKMessage`（所有变体）
**文件：** `OutputRenderer+SDKMessage.swift`（添加 turn 前缀和空行逻辑）, `ANSI.swift`（添加 `blue()` 如不存在）
**实现说明：** 核心改动在 `renderPartialMessage` 中——追踪是否已输出当前 turn 的 `● ` 前缀。`OutputRenderer` 添加 `private var turnHeaderPrinted = false` 状态，首个 partialMessage chunk 输出 `● ` 后置为 true，`renderResult` 时重置为 false。工具调用前的空行通过在 `renderToolUse` 首次调用时检查状态实现。

### Story 10.2: Markdown 表格与块级元素渲染

作为一个用户，
我想要看到表格、引用块、分割线和链接的终端渲染效果，
以便 AI 输出的结构化内容一目了然。

**验收标准：**

**AC#1: 表格渲染**

**假设** AI 输出包含 Markdown 表格
```
| Name | Status | Count |
|------|--------|-------|
| foo  | active | 3     |
| bar  | idle   | 0     |
```
**当** 渲染到终端
**那么** 使用 box-drawing 字符渲染为：
```
┌──────┬──────────┬───────┐
│ Name │ Status   │ Count │
├──────┼──────────┼───────┤
│ foo  │ active   │     3 │
│ bar  │ idle     │     0 │
└──────┴──────────┴───────┘
```
**并且** 表头行加粗显示
**并且** 列宽按最长内容自动对齐（左右各留 1 空格 padding）

**假设** 表格列数不一致
**当** 渲染到终端
**那么** 缺失列用空格填充，不崩溃

**假设** 单元格内容超过终端宽度
**当** 渲染到终端
**那么** 内容被截断并追加 `…`，表格不超宽

**AC#2: 引用块渲染**

**假设** AI 输出包含引用块
```
> This is a quote
> spanning multiple lines
```
**当** 渲染到终端
**那么** 每行前加灰色 `│ ` 前缀：
```
│ This is a quote
│ spanning multiple lines
```

**AC#3: 水平分割线**

**假设** AI 输出包含 `---` 或 `***` 或 `___`
**当** 渲染到终端
**那么** 输出一行 `─` 字符，长度为终端宽度

**AC#4: 链接渲染**

**假设** AI 输出包含链接 `[text](url)`
**当** 渲染到终端
**那么** 显示为 `text`（下划线样式），URL 不显示

**AC#5: 标题装饰增强**

**假设** AI 输出 H1 标题 `# Title`
**当** 渲染到终端
**那么** 加粗 + 下方追加 `═══` 装饰线（与标题等长）

**假设** AI 输出 H2 标题 `## Title`
**当** 渲染到终端
**那么** 加粗 + 下方追加 `───` 装饰线（与标题等长）

**假设** AI 输出 H3-H6 标题
**当** 渲染到终端
**那么** 仅加粗（已有行为，不变）

**SDK API：** 无（纯渲染逻辑）
**文件：** `MarkdownRenderer.swift`（新增 `renderTable`, `renderBlockquote`, `renderHorizontalRule`, `renderLink` 方法；增强 `renderHeading` 和 `renderBlock` 的分支逻辑；增强 `renderInline` 支持链接语法）
**实现说明：**
- **表格解析**：在 `splitIntoBlocks` 中识别 `|...|` 模式的连续行作为一个 block。`renderTable` 计算每列最大宽度，用 box-drawing 字符绘制。表头分隔行 (`|---|---|`) 不输出，仅用于检测表格结构。
- **引用块**：在 `renderBlock` 中检测以 `> ` 开头的连续行，聚合后调用 `renderBlockquote`。
- **分割线**：在 `renderBlock` 中检测仅由 `-`、`*`、`_` 和空格组成的行。
- **链接**：在 `renderInline` 中匹配 `[text](url)` 模式，替换为 `ANSI.underline(text)`。
- **标题装饰**：修改 `renderHeading`，H1 追加 `═══`，H2 追加 `───`。

### Story 10.3: 流式场景下的表格缓冲与渲染

作为一个用户，
我想要在 AI 流式输出表格时看到完整的渲染效果而非碎片，
以便表格不会在流式过程中变形或闪烁。

**验收标准：**

**假设** AI 流式输出中开始一个表格（首个 chunk 包含 `| Name |`）
**当** `MarkdownBuffer.append()` 检测到表格行开始
**那么** 后续 chunk 被缓冲，直到检测到表格结束（非 `|` 行或空行）
**当** 表格结束后
**那么** 整个表格一次性通过 `MarkdownRenderer.renderTable()` 渲染输出

**假设** AI 在流式输出中产生多个表格
**当** 每个表格独立缓冲和渲染
**那么** 每个表格都正确渲染，互不干扰

**假设** AI 输出的表格跨越多个 chunk 且 chunk 在单元格中间拆分
**当** 缓冲区累积内容
**那么** 正确拼接后在表格结束时渲染，不因 chunk 边界导致格式错误

**假设** AI 的回复在表格中间被中断（如用户 Ctrl+C）
**当** `MarkdownBuffer.flush()` 被调用
**那么** 已缓冲的表格内容以最佳努力渲染（可能不完整但不崩溃）

**假设** 表格后紧跟非表格文本
**当** 流式继续
**那么** 非表格文本正常通过 `renderInline` 即时输出

**SDK API：** 无（纯渲染逻辑）
**文件：** `OutputRenderer.swift`（`MarkdownBuffer` 扩展表格缓冲状态机）
**实现说明：** 在 `MarkdownBuffer` 中添加第三个缓冲状态 `insideTableBlock`。检测逻辑：当非 code-block 状态下遇到 `|...|` 模式的行，进入表格缓冲模式。表格结束条件：遇到空行或非 `|` 开头的行。`flush()` 时如有未完成表格，按已有行渲染（header + 已有数据行）。表格检测使用正则 `^\|.*\|$` 匹配（trim 后）。
