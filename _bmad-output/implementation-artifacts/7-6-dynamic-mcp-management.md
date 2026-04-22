# Story 7.6: 动态 MCP 管理

Status: done

## Story

作为一个高级用户，
我想要在会话中检查和重新连接 MCP 服务器，
以便我可以排查连接问题而无需重启。

## Acceptance Criteria

1. **假设** MCP 服务器已连接
   **当** 我输入 `/mcp status`
   **那么** 显示每个服务器的连接状态

2. **假设** MCP 服务器断开连接
   **当** 我输入 `/mcp reconnect <name>`
   **那么** 服务器重新连接

3. **假设** 提供了不存在的服务器名称
   **当** 我输入 `/mcp reconnect nonexistent`
   **那么** 错误信息显示 "Server not found"

4. **假设** 当前没有配置任何 MCP 服务器
   **当** 我输入 `/mcp status`
   **那么** 显示 "No MCP servers configured."

5. **假设** `/mcp` 后没有子命令或子命令无效
   **当** 我输入 `/mcp` 或 `/mcp unknown`
   **那么** 显示帮助信息，列出可用的 /mcp 子命令

6. **假设** `/mcp reconnect` 没有提供服务器名称
   **当** 我输入 `/mcp reconnect`
   **那么** 显示错误信息 "Usage: /mcp reconnect <name>"

## Tasks / Subtasks

- [x] Task 1: 在 REPLLoop 中添加 `/mcp` 命令分发处理 (AC: #1-#6)
  - [x] 在 `handleSlashCommand` 的 switch 中添加 `"/mcp"` case
  - [x] 实现 `handleMcp(parts:)` 方法解析子命令
  - [x] 实现 `handleMcpStatus()` 方法
  - [x] 实现 `handleMcpReconnect(serverName:)` 方法

- [x] Task 2: 实现 `/mcp status` 状态显示 (AC: #1, #4)
  - [x] 调用 `agent.mcpServerStatus()` 获取状态字典
  - [x] 空字典时显示 "No MCP servers configured."
  - [x] 非空时逐个显示服务器名称、状态枚举值、工具数量
  - [x] 如有错误信息（`serverStatus.error`），一并显示

- [x] Task 3: 实现 `/mcp reconnect <name>` 重连 (AC: #2, #3, #6)
  - [x] 解析服务器名称参数
  - [x] 无名称时显示用法提示
  - [x] 调用 `agent.reconnectMcpServer(name:)`
  - [x] 成功时显示 "Reconnected <name>."
  - [x] 捕获 `MCPClientManagerError.serverNotFound` 显示 "Server not found: <name>"
  - [x] 其他错误显示错误详情

- [x] Task 4: 更新 `/help` 输出 (AC: #1, #2)
  - [x] 在 `printHelp()` 中添加 `/mcp status` 和 `/mcp reconnect <name>` 命令说明

- [x] Task 5: 添加测试覆盖 (AC: #1-#6)
  - [x] 测试：/mcp status 显示已连接服务器状态
  - [x] 测试：/mcp status 无 MCP 配置时显示提示
  - [x] 测试：/mcp reconnect 成功重连
  - [x] 测试：/mcp reconnect 不存在的服务器显示 "Server not found"
  - [x] 测试：/mcp reconnect 无参数显示用法
  - [x] 测试：/mcp 无子命令显示帮助
  - [x] 测试：/help 输出包含 /mcp 命令

## Dev Notes

### SDK API 分析

本故事使用的 SDK API 均已存在且完整实现：

1. **`Agent.mcpServerStatus() async -> [String: McpServerStatus]`**
   - 位置：`.build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift` 第 671 行
   - 返回字典：server name -> McpServerStatus
   - 无 MCP 服务器配置时返回空字典 `[:]`
   - `mcpClientManager` 为 nil 时也返回空字典

2. **`Agent.reconnectMcpServer(name:) async throws`**
   - 位置：`.build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift` 第 686 行
   - 参数：`name: String` — 要重连的服务器名称
   - 抛出：`MCPClientManagerError.serverNotFound(String)` — 服务器名称不存在时
   - 行为：断开现有连接，使用原始配置重新建立连接
   - `mcpClientManager` 为 nil 时也抛出 `serverNotFound`

3. **`McpServerStatus` 结构体**
   - 位置：`.build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Types/MCPTypes.swift` 第 80 行
   - 关键字段：
     - `name: String` — 服务器名称
     - `status: McpServerStatusEnum` — 状态枚举
     - `serverInfo: McpServerInfo?` — 服务器名称和版本（可选）
     - `error: String?` — 错误信息（可选）
     - `tools: [String]` — 可用工具名称列表

4. **`McpServerStatusEnum` 枚举**
   - 位置：`.build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Types/MCPTypes.swift` 第 44 行
   - 5 个 case：`.connected`, `.failed`, `.needsAuth`, `.pending`, `.disabled`
   - 遵循 `String` 协议，可直接用于显示

5. **`MCPClientManagerError.serverNotFound(String)`**
   - 位置：`.build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift` 第 618 行
   - 携带服务器名称的关联值

### 当前实现分析

#### REPLLoop.swift — 需要修改

**`handleSlashCommand` 方法（第 176 行）：** 需要添加 `"/mcp"` case。注意 `/mcp` 需要两级解析：先匹配 `/mcp`，再解析子命令 `status` 或 `reconnect`。

**新增方法：**

```swift
// 伪代码
private func handleMcp(parts: [String.SubSequence]) async {
    // 解析子命令
    let subcommand: String
    let subArgs: String?
    if parts.count > 1 {
        let subParts = parts[1].split(separator: " ", maxSplits: 1)
        subcommand = String(subParts[0]).lowercased()
        subArgs = subParts.count > 1 ? String(subParts[1]) : nil
    } else {
        subcommand = ""
        subArgs = nil
    }

    switch subcommand {
    case "status":
        await handleMcpStatus()
    case "reconnect":
        guard let name = subArgs, !name.isEmpty else {
            renderer.output.write("Usage: /mcp reconnect <name>\n")
            return
        }
        await handleMcpReconnect(serverName: name)
    default:
        renderer.output.write("MCP commands:\n")
        renderer.output.write("  /mcp status              Show MCP server status\n")
        renderer.output.write("  /mcp reconnect <name>    Reconnect a server\n")
    }
}

private func handleMcpStatus() async {
    let statuses = await agentHolder.agent.mcpServerStatus()
    if statuses.isEmpty {
        renderer.output.write("No MCP servers configured.\n")
        return
    }
    renderer.output.write("MCP Servers:\n")
    for (name, status) in statuses.sorted(by: { $0.key < $1.key }) {
        let toolCount = status.tools.count
        renderer.output.write("  \(name): \(status.status.rawValue)")
        if let info = status.serverInfo {
            renderer.output.write(" (\(info.name) v\(info.version))")
        }
        if !status.tools.isEmpty {
            renderer.output.write(" — \(toolCount) tool\(toolCount == 1 ? "" : "s")")
        }
        if let error = status.error {
            renderer.output.write("\n    Error: \(error)")
        }
        renderer.output.write("\n")
    }
}

private func handleMcpReconnect(serverName: String) async {
    do {
        try await agentHolder.agent.reconnectMcpServer(name: serverName)
        renderer.output.write("Reconnected \(serverName).\n")
    } catch let error as MCPClientManagerError {
        // 匹配 serverNotFound
        renderer.output.write("Server not found: \(serverName)\n")
    } catch {
        renderer.output.write("Error reconnecting \(serverName): \(error.localizedDescription)\n")
    }
}
```

**注意：** `MCPClientManagerError` 是 SDK 公开类型，可以直接在 catch 中进行类型匹配。

**`printHelp()` 方法（第 211 行）：** 添加 `/mcp status` 和 `/mcp reconnect <name>` 到帮助列表。

#### 不需要修改的文件

- **AgentFactory.swift** — 无需修改。MCP 服务器配置在创建时已传入。
- **ArgumentParser.swift** — 无需修改。没有新的 CLI 标志。
- **CLI.swift** — 无需修改。MCP 管理是 REPL 运行时操作。
- **MCPConfigLoader.swift** — 无需修改。配置加载已在启动时完成。
- **OutputRenderer.swift** — 无需修改。直接使用 renderer.output.write()。

### 命令解析注意事项

`/mcp` 是一个带子命令的斜杠命令。当前 `handleSlashCommand` 使用 `split(separator: " ", maxSplits: 1)` 将输入分成最多两部分。对于 `/mcp status`，`parts[0]` 是 `/mcp`，`parts[1]` 是 `status`。对于 `/mcp reconnect myserver`，`parts[0]` 是 `/mcp`，`parts[1]` 是 `reconnect myserver`。因此 `handleMcp` 需要对 `parts[1]` 再次分割来提取子命令和参数。

### /mcp 与现有斜杠命令的模式对比

| 命令 | 参数解析 | 实现 |
|------|---------|------|
| /help | 无参数 | 直接调用 printHelp() |
| /model <name> | parts[1] 为名称 | handleModel(parts:) |
| /resume <id> | parts[1] 为 ID | handleResume(parts:) |
| /fork | 无参数 | handleFork() |
| /mcp status | 二级子命令 | handleMcp(parts:) → handleMcpStatus() |
| /mcp reconnect <name> | 二级子命令+参数 | handleMcp(parts:) → handleMcpReconnect(name:) |

**/mcp 是第一个带子命令的斜杠命令。** 需要二次解析子命令。

### 关键约束

1. **零 internal 访问** — 仅使用 `import OpenAgentSDK`
2. **零第三方依赖** — 不引入外部库
3. **不修改 SDK** — 如遇 SDK 限制，记录为 `// SDK-GAP:` 注释
4. **MCPClientManagerError 是公开类型** — 可以直接在 catch 中使用类型匹配
5. **mcpServerStatus() 是 async** — 需要 await
6. **reconnectMcpServer() 是 async throws** — 需要 try await

### 不要做的事

1. **不要创建新的 MCP 配置文件** — `/mcp` 只管理运行时状态，不修改配置
2. **不要添加 `/mcp connect` 或 `/mcp disconnect`** — AC 不要求，属于未来扩展
3. **不要修改 AgentFactory** — MCP 服务器在启动时已配置
4. **不要修改 ArgumentParser** — 没有新 CLI 标志
5. **不要实现 `/mcp add` 或 `/mcp remove`** — AC 不要求动态增减服务器

### 前一故事的关键学习

Story 7.5（会话分叉）完成后的关键信息：

1. **AgentHolder 模式** — 使用 class 包装 Agent，允许在 struct 的 non-mutating 方法中替换 agent 实例
2. **`renderer.output.write()` 是标准输出方式** — 所有斜杠命令结果通过此方法输出
3. **全量回归测试通过** — 开发完成后需确认所有现有测试仍通过
4. **handleSlashCommand switch 模式** — 在 switch 中添加新的 case 即可
5. **MCPClientManagerError 是公开枚举** — 可直接用于 catch 类型匹配

### 项目结构说明

本故事修改 1 个现有文件，不创建新文件：

```
Sources/OpenAgentCLI/
  REPLLoop.swift            # 修改：添加 /mcp 命令处理

Tests/OpenAgentCLITests/
  DynamicMcpManagementTests.swift  # 修改：添加 /mcp 相关测试
```

**注意：** 由于 `/mcp` 命令涉及调用真实的 SDK Agent 方法（`mcpServerStatus()` 和 `reconnectMcpServer()`），测试需要创建真实 Agent 但不配置 MCP 服务器（此时 `mcpServerStatus()` 返回空字典）。对于 reconnect 的 "Server not found" 测试，不配置 MCP 的 Agent 调用 `reconnectMcpServer()` 会抛出 `MCPClientManagerError.serverNotFound`。

### 测试策略

**测试环境：** DynamicMcpManagementTests 或在现有 REPLLoopTests 中添加。

**使用真实 Agent + 无 MCP 配置：**
- `mcpServerStatus()` 返回空字典 — 测试 AC#4
- `reconnectMcpServer(name:)` 抛出 serverNotFound — 测试 AC#3
- `/mcp` 子命令解析 — 测试 AC#5
- `/mcp reconnect` 无参数 — 测试 AC#6

**新增测试分布预期：**

| 测试方法名 | 覆盖 AC | 说明 |
|-----------|---------|------|
| testMcpStatus_noServers_showsNoConfigured | #4 | 无 MCP 配置时显示提示 |
| testMcpStatus_withServers_showsStatus | #1 | 显示服务器状态（需 MCP 配置，可能为集成测试） |
| testMcpReconnect_noArg_showsUsage | #6 | 无参数时显示用法 |
| testMcpReconnect_nonexistent_showsNotFound | #3 | 不存在的服务器显示错误 |
| testMcp_noSubcommand_showsHelp | #5 | 无子命令显示帮助 |
| testMcp_unknownSubcommand_showsHelp | #5 | 无效子命令显示帮助 |
| testHelp_includesMcpCommands | #1, #2 | /help 输出包含 /mcp 命令 |

**注意：** AC#1（显示已连接服务器状态）和 AC#2（成功重连）需要真实 MCP 服务器配置。单元测试中无法覆盖这两个 AC 的完整场景。可以通过以下方式处理：
- 使用无 MCP 的 Agent 测试"空状态"和"not found"
- AC#1 和 AC#2 的完整覆盖留给冒烟测试/手动验证

### SDK API 参考

本故事使用以下 SDK API：

- `Agent.mcpServerStatus() async -> [String: McpServerStatus]`
  - 返回所有已配置 MCP 服务器的状态字典
  - 无 MCP 时返回空字典
- `Agent.reconnectMcpServer(name: String) async throws`
  - 重连指定 MCP 服务器
  - 不存在时抛出 `MCPClientManagerError.serverNotFound`
- `McpServerStatus` — 状态结构体，包含 name, status, serverInfo, error, tools
- `McpServerStatusEnum` — 状态枚举（connected, failed, needsAuth, pending, disabled）
- `MCPClientManagerError.serverNotFound(String)` — 服务器不存在错误

无新 SDK API 需要引入。无 SDK-GAP 预期。

### 架构合规性

本故事涉及架构文档中的 **FR5.3** 和 **FR5.4**：

- **FR5.3:** 通过 `/mcp status` 命令查看 MCP 服务器连接状态 (P1)
- **FR5.4:** 通过 `/mcp reconnect <name>` 命令重新连接 MCP 服务器 (P2)

**FR 覆盖映射：**
- FR5.3 -> Epic 7, Story 7.6 (本故事)
- FR5.4 -> Epic 7, Story 7.6 (本故事)

**架构模式遵循：**
- "薄编排层" — CLI 仅调用 Agent 的 mcpServerStatus() 和 reconnectMcpServer()，不实现 MCP 管理
- "SDK 之上的薄 CLI" — MCP 状态和重连操作由 SDK Agent 执行
- "基于协议的分离" — REPLLoop 通过 Agent 公开 API 与 MCP 子系统交互

[Source: epics.md#Story 7.6]
[Source: prd.md#FR5.3, FR5.4]
[Source: architecture.md#SDK 边界 — "CLI 仅在单一点接触 SDK"]

### 延迟工作

- **`/mcp connect <name>`** — 动态连接新的 MCP 服务器（AC 不要求）
- **`/mcp disconnect <name>`** — 断开指定服务器（AC 不要求）
- **`/mcp add <config>` / `/mcp remove <name>`** — 动态增减 MCP 配置（AC 不要求）
- **`/mcp tools <name>`** — 显示指定服务器的工具列表（AC 不要求，但 McpServerStatus 已包含 tools 列表）
- **`/mcp enable/disable <name>`** — 使用 Agent.toggleMcpServer() 切换服务器启用状态（AC 不要求，但 SDK API 已就绪）

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.6]
- [Source: _bmad-output/planning-artifacts/prd.md#FR5.3, FR5.4]
- [Source: _bmad-output/planning-artifacts/architecture.md#SDK 边界]
- [Source: Sources/OpenAgentCLI/REPLLoop.swift — handleSlashCommand(), printHelp()]
- [Source: .build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Core/Agent.swift — mcpServerStatus(), reconnectMcpServer()]
- [Source: .build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Types/MCPTypes.swift — McpServerStatus, McpServerStatusEnum]
- [Source: .build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift — MCPClientManagerError]
- [Source: _bmad-output/implementation-artifacts/7-5-session-fork.md — 前一故事]

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No debug issues encountered. Build and tests passed on first attempt.

### Completion Notes List

- Implemented `/mcp` command group with two subcommands: `status` and `reconnect`
- Added `handleMcp(parts:)` dispatcher that performs two-level command parsing (first `/mcp`, then subcommand)
- Added `handleMcpStatus()` that calls `agent.mcpServerStatus()` and renders status for each server
- Added `handleMcpReconnect(serverName:)` that calls `agent.reconnectMcpServer(name:)` with proper error handling
- Updated `printHelp()` to include `/mcp status` and `/mcp reconnect <name>`
- All 9 ATDD tests pass (DynamicMcpManagementTests)
- Full regression suite passes: 581 tests, 0 failures
- AC#1 and AC#2 (showing connected server status and successful reconnect) require real MCP servers for full verification; the "no servers" and "server not found" paths are covered by unit tests

### File List

- Sources/OpenAgentCLI/REPLLoop.swift (modified)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified)

## Change Log

- 2026-04-22: Implemented Story 7.6 — dynamic MCP management (/mcp status, /mcp reconnect)

### Review Findings

- [x] [Review][Patch] Help text alignment for /mcp commands [REPLLoop.swift:221-222] -- fixed: aligned /mcp reconnect description column with other commands
