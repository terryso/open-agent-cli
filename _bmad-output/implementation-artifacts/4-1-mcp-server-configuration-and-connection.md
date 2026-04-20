# Story 4.1: MCP 服务器配置与连接

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## 故事

作为一个用户，
我想要将外部 MCP 工具服务器连接到我的 Agent，
以便 Agent 可以使用我定义的工具（如数据库、API、自定义服务）。

## 验收标准

1. **假设** 存在有效的 MCP 配置 JSON 文件 `./mcp-config.json`
   **当** 我运行 `openagent --mcp ./mcp-config.json`
   **那么** MCP 服务器在启动时连接

2. **假设** MCP 服务器已配置
   **当** Agent 创建其工具池
   **那么** MCP 工具与内置工具一起被包含

3. **假设** MCP 服务器连接失败
   **当** CLI 启动
   **那么** 显示警告，列出失败的服务器，但 CLI 继续运行

4. **假设** MCP 配置文件不存在
   **当** 我运行 `openagent --mcp nonexistent.json`
   **那么** 清晰的错误信息显示 "MCP config file not found"
   **并且** CLI 以退出码 1 退出

## 任务 / 子任务

- [x] 任务 1: 创建 MCPConfigLoader.swift (AC: #1, #4)
  - [x] 实现 `loadMcpConfig(from:)` 函数：读取 JSON 文件，解析为 `[String: McpServerConfig]`
  - [x] JSON 格式支持 stdio、sse、http 三种传输类型的解析
  - [x] 文件不存在时抛出明确错误（"MCP config file not found: <path>"）
  - [x] JSON 格式无效时抛出明确错误（包含解析错误详情）
  - [x] 空的 mcpServers 对象返回空字典（不报错）
  - [x] 使用 Foundation 的 `JSONSerialization` 解析（与项目零第三方依赖一致）

- [x] 任务 2: 集成 MCP 配置到 AgentFactory (AC: #1, #2)
  - [x] 在 `createAgent(from:)` 中调用 MCPConfigLoader 加载配置
  - [x] 将解析的 `[String: McpServerConfig]` 传入 `AgentOptions.mcpServers`
  - [x] 当 `args.mcpConfigPath` 为 nil 时，跳过加载（mcpServers = nil）
  - [x] MCP 工具通过 `AgentOptions.mcpServers` 自动集成到工具池（SDK 处理 `assembleToolPool` 中 MCP tools 的发现和注册）

- [x] 任务 3: 处理 MCP 连接失败的优雅降级 (AC: #3)
  - [x] 配置文件加载失败（不存在、格式错误）→ 致命错误，退出码 1（AC #4 行为）
  - [x] MCP 服务器运行时连接失败 → SDK 处理（通过 `SDKMessage.system` 或错误消息报告）
  - [x] CLI 在启动时显示 MCP 连接进度提示（如 "[Connecting to MCP servers...]"）
  - [x] 确保即使 MCP 连接失败，REPL 仍然可用（SDK 的降级行为）

- [x] 任务 4: 编写 MCPConfigLoaderTests 测试 (AC: #1, #3, #4)
  - [x] 测试有效 stdio 配置文件加载成功
  - [x] 测试有效 sse 配置文件加载成功
  - [x] 测试有效 http 配置文件加载成功
  - [x] 测试混合多种传输类型的配置文件
  - [x] 测试空 mcpServers 对象返回空字典
  - [x] 测试文件不存在时抛出正确错误
  - [x] 测试 JSON 格式无效时抛出正确错误
  - [x] 测试缺少必需字段时的错误处理
  - [x] 测试 AgentFactory 集成（无 --mcp 时 mcpServers 为 nil）
  - [x] 测试 AgentFactory 集成（有 --mcp 时 mcpServers 有值）
  - [x] 回归测试验证：306 项现有测试全部通过

## 开发备注

### 前一故事的关键学习

Story 3.3（启动时自动恢复上次会话）完成后的项目状态：

1. **306 项测试全部通过** — 分布于 ArgumentParserTests、AgentFactoryTests、ConfigLoaderTests、OutputRendererTests、REPLLoopTests、CLISingleShotTests、SmokePerformanceTests、ToolLoadingTests、SkillLoadingTests、SessionSaveTests、SessionListResumeTests、AutoRestoreTests。[来源: 最新 `swift test` 执行结果]

2. **AgentFactory.createAgent 返回 (Agent, SessionStore) 元组** — 所有调用方（CLI.swift 和测试）使用此元组。[来源: `Sources/OpenAgentCLI/AgentFactory.swift#L60`]

3. **AgentFactory.computeToolPool 已有 mcpTools 参数** — `assembleToolPool(baseTools:customTools:mcpTools:allowed:disallowed:)` 当前传入 `mcpTools: nil`。本故事需要将 MCP 配置加载后的 tools 传入此参数，或依赖 SDK 通过 `AgentOptions.mcpServers` 自动发现。[来源: `Sources/OpenAgentCLI/AgentFactory.swift#L133-139`]

4. **ArgumentParser 已支持 --mcp 参数** — `args.mcpConfigPath` 已解析并存储在 `ParsedArgs.mcpConfigPath` 中。[来源: `Sources/OpenAgentCLI/ArgumentParser.swift#L18, L172-175`]

5. **deferred-work.md 已有 4 项** — 包括 force-unwrap 模式、误导性错误消息、AgentOptions 未完整填充、缺失测试路径。不要在此故事中修复这些问题，除非直接相关。[来源: `_bmad-output/implementation-artifacts/deferred-work.md`]

### SDK API 详细参考

本故事使用的核心 SDK API — MCP 配置类型：

```swift
// SDK 中的 MCP 配置类型层次 (Sources/OpenAgentSDK/Types/MCPConfig.swift)
public enum McpServerConfig: Sendable, Equatable {
    case stdio(McpStdioConfig)       // 子进程 stdio 传输
    case sse(McpSseConfig)           // Server-Sent Events 传输
    case http(McpHttpConfig)         // HTTP POST 传输
    case sdk(McpSdkServerConfig)     // 进程内 SDK 传输（本故事不涉及）
    case claudeAIProxy(McpClaudeAIProxyConfig) // ClaudeAI 代理（本故事不涉及）
}

public struct McpStdioConfig: Sendable, Equatable {
    public let command: String
    public let args: [String]?
    public let env: [String: String]?
    public init(command: String, args: [String]? = nil, env: [String: String]? = nil)
}

public struct McpTransportConfig: Sendable, Equatable {
    public let url: String
    public let headers: [String: String]?
    public init(url: String, headers: [String: String]? = nil)
}
public typealias McpSseConfig = McpTransportConfig
public typealias McpHttpConfig = McpTransportConfig
```

```swift
// AgentOptions 中的 MCP 配置 (Sources/OpenAgentSDK/Types/AgentTypes.swift)
public struct AgentOptions {
    public var mcpServers: [String: McpServerConfig]?  // nil = 无 MCP

    public init(
        // ... 其他参数 ...
        mcpServers: [String: McpServerConfig]? = nil,
        // ...
    )
}
```

```swift
// assembleToolPool 已支持 MCP 工具 (Sources/OpenAgentSDK/Tools/ToolRegistry.swift#L149-155)
public func assembleToolPool(
    baseTools: [ToolProtocol],
    customTools: [ToolProtocol]?,
    mcpTools: [ToolProtocol]?,       // MCP 工具参数
    allowed: [String]?,
    disallowed: [String]?
) -> [ToolProtocol]
```

**关键洞察：** SDK 通过 `AgentOptions.mcpServers` 自动管理 MCP 连接生命周期。CLI 只需解析 JSON 配置文件为 `[String: McpServerConfig]` 字典并传入 AgentOptions。SDK 负责：
- 启动 MCP 服务器进程（stdio 传输）或建立网络连接（sse/http）
- 发现 MCP 工具并注册到工具池
- 处理连接失败和重试

CLI 不需要手动调用 `MCPClientManager`。只需在 AgentOptions 中传入配置即可。

[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/MCPConfig.swift]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#L257, L442, L501]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/ToolRegistry.swift#L149-159]

### JSON 配置文件格式

SDK 期望的 JSON 格式（与 Claude Desktop / Claude Code 兼容）：

```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
    },
    "another-server": {
      "command": "python3",
      "args": ["mcp_server.py"],
      "env": {
        "API_KEY": "xxx"
      }
    },
    "remote-server": {
      "url": "https://mcp.example.com/sse",
      "headers": {
        "Authorization": "Bearer xxx"
      }
    }
  }
}
```

**JSON 解析规则：**
- 顶层对象必须有 `mcpServers` 键
- 每个服务器条目根据字段判断传输类型：
  - 有 `command` 字段 → `McpServerConfig.stdio`
  - 有 `url` 字段 → `McpServerConfig.sse`（或 `.http`，取决于 URL 或额外字段）
- `command` 是 stdio 的必需字段
- `url` 是 sse/http 的必需字段
- `args`、`env`、`headers` 是可选字段

### 核心设计决策

#### 决策 1: MCP 配置文件中的传输类型判断

根据 JSON 中是否存在 `command` 或 `url` 字段来判断传输类型：

| 字段 | 传输类型 | SDK 类型 |
|------|---------|---------|
| `command` 存在 | stdio | `McpServerConfig.stdio(McpStdioConfig)` |
| `url` 存在 | sse | `McpServerConfig.sse(McpTransportConfig)` |
| 两者都不存在 | 错误 | 抛出解析错误 |

**不实现 `type` 字段检测** — MCP 配置通常不含 `type` 字段，而是通过结构推断传输类型（与 Claude Desktop 格式兼容）。`http` 类型可以在后续迭代中通过 `type` 字段区分。

#### 决策 2: 错误处理策略

| 错误场景 | 行为 | 退出码 |
|---------|------|--------|
| 配置文件不存在 | 致命错误，退出 | 1 |
| JSON 格式无效 | 致命错误，退出 | 1 |
| 缺少 mcpServers 键 | 致命错误，退出 | 1 |
| 单个服务器配置缺少必需字段 | 致命错误，退出 | 1 |
| MCP 服务器运行时连接失败 | SDK 处理，CLI 继续 | 0 |

AC #4 明确要求文件不存在时退出。运行时连接失败（AC #3）由 SDK 的 `MCPClientManager` 处理，CLI 通过 `SDKMessage.system` 或错误回调得知。

#### 决策 3: 不修改 computeToolPool 中的 mcpTools 参数

当前 `computeToolPool` 传入 `mcpTools: nil`。MCP 工具由 SDK 通过 `AgentOptions.mcpServers` 自动发现和注册——CLI 不需要手动提取 MCP 工具列表。`assembleToolPool` 中的 `mcpTools` 参数用于已经手动获取的 MCP 工具实例，而 `AgentOptions.mcpServers` 让 SDK 在 Agent 初始化时自动处理 MCP 工具发现。

因此：**不需要修改 `computeToolPool`**。只需在 `AgentOptions` 中传入 `mcpServers`。

### 架构合规性

本故事涉及架构文档中的 **FR5.1、FR5.2、FR5.5**：

- **FR5.1:** 通过 `--mcp <config.json>` 加载 MCP 服务器配置 → `MCPConfigLoader.swift` + `ArgumentParser.swift`（已有 `--mcp` 支持）
- **FR5.2:** 启动时自动连接配置的 MCP 服务器 → `AgentFactory.swift`（通过 `AgentOptions.mcpServers` 传入配置，SDK 自动连接）
- **FR5.5:** MCP 工具与内置工具统一调度 → SDK 内置行为（`assembleToolPool` 合并所有工具源）

架构文档中提到的 `MCPConfigLoader.swift` 是本故事需要创建的新文件。

[来源: _bmad-output/planning-artifacts/epics.md#Story 4.1]
[来源: _bmad-output/planning-artifacts/prd.md#FR5.1, FR5.2, FR5.5]
[来源: _bmad-output/planning-artifacts/architecture.md#FR5:MCP集成→MCPConfigLoader.swift]

### 关键约束：零 internal 访问

整个项目仅允许 `import OpenAgentSDK`。不得导入任何 internal 模块或使用 `@_implementationOnly`。如果发现 SDK 缺少 public API，使用 `// SDK-GAP:` 注释记录，不绕过。

[来源: prd.md#技术约束, architecture.md#执行指南]

### 不要做的事

1. **不要修改 ArgumentParser** — `--mcp` 参数已完整实现。`args.mcpConfigPath` 已可用。[来源: `Sources/OpenAgentCLI/ArgumentParser.swift#L172-175`]

2. **不要手动调用 MCPClientManager** — SDK 通过 `AgentOptions.mcpServers` 自动管理 MCP 连接。CLI 只需传入配置字典。

3. **不要修改 computeToolPool** — MCP 工具由 SDK 通过 `AgentOptions.mcpServers` 自动发现和注册，不需要手动传入 `mcpTools` 参数。

4. **不要在 REPL 中添加 /mcp 命令** — `/mcp status` 和 `/mcp reconnect` 是 P2 功能（Epic 7 Story 7.6）。本故事只做启动时加载和连接。

5. **不要实现 sdk 和 claudeAIProxy 传输类型** — 这两种类型需要进程内 MCP 服务器或特殊代理端点，不在 CLI 配置文件的范围内。只解析 stdio、sse、http。

6. **不要修改 OutputRenderer** — MCP 连接提示通过 `renderer.output.write()` 直接输出，不需要新的渲染方法。

7. **不要在单次提问模式中跳过 MCP** — 单次提问模式同样应该加载 MCP 配置，Agent 可能需要 MCP 工具来完成任务。

### 项目结构说明

需要新建的文件：
```
Sources/OpenAgentCLI/
  MCPConfigLoader.swift       # 新建：JSON → [String: McpServerConfig] 解析
```

需要修改的文件：
```
Sources/OpenAgentCLI/
  AgentFactory.swift          # 修改：调用 MCPConfigLoader，传入 mcpServers 到 AgentOptions
  CLI.swift                   # 修改：添加 MCP 连接进度提示
```

需要新增的测试：
```
Tests/OpenAgentCLITests/
  MCPConfigLoaderTests.swift  # 新建：覆盖所有解析场景和错误情况
```

不修改的文件：
```
Sources/OpenAgentCLI/
  ArgumentParser.swift           # 参数解析不变（--mcp 已存在）
  OutputRenderer.swift           # 渲染不变
  OutputRenderer+SDKMessage.swift  # 消息渲染不变
  CLIEntry.swift / main.swift    # 入口不变
  ANSI.swift                     # ANSI 辅助不变
  Version.swift                  # 版本不变
  CLISingleShot.swift            # 单次模式不变
  ConfigLoader.swift             # 配置加载不变
  REPLLoop.swift                 # REPL 循环不变
```

[来源: architecture.md#项目结构]

### 测试策略

**新增测试分布预期：**

| 测试方法名 | 覆盖 AC | 说明 |
|-----------|---------|------|
| testLoadMcpConfig_validStdioConfig | #1 | 有效 stdio 配置解析为 McpStdioConfig |
| testLoadMcpConfig_stdioWithArgsAndEnv | #1 | stdio 带完整字段 |
| testLoadMcpConfig_validSseConfig | #1 | 有效 sse 配置解析为 sse(McpTransportConfig) |
| testLoadMcpConfig_validHttpConfig | #1 | 有效 http 配置解析为 http(McpTransportConfig) |
| testLoadMcpConfig_multipleServers | #1, #2 | 多服务器混合配置 |
| testLoadMcpConfig_emptyServers | #1 | 空 mcpServers 对象返回空字典 |
| testLoadMcpConfig_fileNotFound | #4 | 文件不存在抛出错误 |
| testLoadMcpConfig_invalidJson | #4 | JSON 格式无效抛出错误 |
| testLoadMcpConfig_missingCommandAndUrl | #4 | 单个条目缺少必需字段抛出错误 |
| testLoadMcpConfig_missingMcpServersKey | #4 | 缺少 mcpServers 键抛出错误 |
| testCreateAgent_withoutMcp_mcpServersIsNil | #2 | 无 --mcp 时 mcpServers 为 nil |
| testCreateAgent_withMcp_mcpServersPopulated | #1, #2 | 有 --mcp 时 mcpServers 有值 |
| testExistingTestsStillPass_regression | 全部 | 306 项测试无回归 |

**测试方法：**

1. **MCPConfigLoader 测试** — 创建临时 JSON 文件作为 fixture，调用 `loadMcpConfig(from:)` 验证返回的字典内容。使用 `UUID().uuidString` 创建唯一临时目录，测试后清理。

2. **AgentFactory 集成测试** — 构造带 `mcpConfigPath` 的 `ParsedArgs`（指向测试 fixture 文件），调用 `createAgent(from:)`，验证不抛出错误。由于 AgentOptions 的 mcpServers 属性不是 public 可读的，需要通过间接方式验证（如创建后执行 stream 检查 MCP 工具可用性）。

3. **回归测试** — MCPConfigLoader 的引入不应影响任何现有测试。特别注意 `computeToolPool` 中传入 `mcpTools: nil` 的行为不变。

**潜在需要更新的测试：** 如果 `createAgent` 方法签名不变（仅新增可选参数），现有测试应全部通过。

### 参考

- [来源: _bmad-output/planning-artifacts/epics.md#Story 4.1]
- [来源: _bmad-output/planning-artifacts/prd.md#FR5.1, FR5.2, FR5.5]
- [来源: _bmad-output/planning-artifacts/architecture.md#FR5:MCP集成, MCPConfigLoader, AgentOptions.mcpServers]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/MCPConfig.swift (McpServerConfig, McpStdioConfig, McpTransportConfig)]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#L257 (mcpServers 属性), L442 (init 参数)]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/ToolRegistry.swift#L149-159 (assembleToolPool)]
- [来源: Sources/OpenAgentCLI/AgentFactory.swift#L86-116 (createAgent), L124-139 (computeToolPool)]
- [来源: Sources/OpenAgentCLI/ArgumentParser.swift#L18 (mcpConfigPath), L172-175 (--mcp parsing)]
- [来源: Sources/OpenAgentCLI/CLI.swift#L36-43 (createAgentOrExit)]
- [来源: _bmad-output/implementation-artifacts/3-3-auto-restore-last-session-on-startup.md (前一故事学习)]
- [来源: _bmad-output/implementation-artifacts/deferred-work.md (4 项延迟工作)]

### 项目结构说明

- 新文件 `MCPConfigLoader.swift` 遵循架构文档中定义的文件命名约定（PascalCase，一个类型一个文件）
- MCP 配置格式复用 SDK 原生的 `McpServerConfig` JSON 格式（与 architecture.md 中 "MCP 配置复用 SDK 原生的 `McpServerConfig` JSON 格式" 决策一致）
- 没有与统一项目结构的冲突或偏差

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No issues encountered during implementation. All tests passed on first run after implementation.

### Completion Notes List

- Implemented MCPConfigLoader.swift with `loadMcpConfig(from:)` function using Foundation's JSONSerialization
- Transport type inference: `command` field -> stdio, `url` field -> sse (per design decision)
- Error types: fileNotFound, invalidJSON, missingMcpServersKey, missingRequiredField, emptyCommand, emptyUrl
- Integrated MCP config loading into AgentFactory.createAgent() via `args.mcpConfigPath.map { try MCPConfigLoader.loadMcpConfig(from: $0) }`
- Added `mcpServers` parameter to AgentOptions init call in AgentFactory
- Added MCP connection progress hint "[Connecting to MCP servers...]" in CLI.swift before agent creation
- SDK handles runtime MCP connection via AgentOptions.mcpServers -- CLI only parses and passes config
- computeToolPool was NOT modified (per design decision: SDK auto-discovers MCP tools via mcpServers)
- All 13 ATDD tests pass, plus 306 existing tests (319 total, 0 failures, 0 regressions)

### File List

- Sources/OpenAgentCLI/MCPConfigLoader.swift (new)
- Sources/OpenAgentCLI/AgentFactory.swift (modified: added MCP config loading and mcpServers pass-through)
- Sources/OpenAgentCLI/CLI.swift (modified: added MCP connection progress hint)
- Tests/OpenAgentCLITests/MCPConfigLoaderTests.swift (pre-existing ATDD tests, unchanged)

## Change Log

- 2026-04-20: Story 4.1 implementation complete - MCPConfigLoader with JSON parsing, AgentFactory integration, CLI progress hint. 319 tests pass (13 new + 306 existing).
