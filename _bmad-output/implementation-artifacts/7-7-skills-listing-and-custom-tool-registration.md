# Story 7.7: 技能列表与自定义工具注册

Status: done

## Story

作为一个高级用户，
我想要列出可用技能并通过配置文件注册自定义工具，
以便我可以发现和扩展 Agent 的能力。

## Acceptance Criteria

1. **假设** 技能已加载
   **当** 我在 REPL 中输入 `/skills`
   **那么** 列出可用技能及其名称和描述

2. **假设** 配置文件指定了自定义工具
   **当** CLI 使用该配置启动
   **那么** 自定义工具被注册并可供 Agent 使用

3. **假设** 技能未加载（无 `--skill-dir` 或 `--skill` 参数）
   **当** 我在 REPL 中输入 `/skills`
   **那么** 显示 "No skills loaded."

4. **假设** 配置文件中的自定义工具有无效的 JSON Schema
   **当** CLI 启动
   **那么** 显示警告信息，跳过该工具，CLI 继续运行

5. **假设** 配置文件中的自定义工具有无效的 execute 脚本路径
   **当** CLI 启动
   **那么** 显示警告信息，跳过该工具，CLI 继续运行

## Tasks / Subtasks

- [x] Task 1: 在 CLIConfig 中添加 `customTools` 字段 (AC: #2, #4, #5)
  - [x] 定义 `CustomToolConfig` 结构体（Decodable），包含 name、description、inputSchema、execute 字段
  - [x] 在 `CLIConfig` 中添加 `customTools: [CustomToolConfig]?` 属性
  - [x] 在 `ConfigLoader.apply()` 中传递 customTools 到 ParsedArgs

- [x] Task 2: 在 ParsedArgs 中添加 `customTools` 字段 (AC: #2)
  - [x] 添加 `customTools: [CustomToolConfig]?` 属性

- [x] Task 3: 实现自定义工具注册逻辑 (AC: #2, #4, #5)
  - [x] 在 `AgentFactory` 中添加 `createCustomTools(from:)` 方法
  - [x] 遍历 `customTools` 配置，为每个工具调用 `defineTool()` 创建 ToolProtocol
  - [x] 自定义工具的 execute 通过 `Process`（shell 脚本）执行，传入 JSON 输入，捕获 stdout 作为结果
  - [x] 无效 Schema 或脚本路径不存在时，打印警告并跳过该工具
  - [x] 在 `computeToolPool()` 中将自定义工具添加到 customTools 数组

- [x] Task 4: 更新 CLI.swift 传递 customTools (AC: #2)
  - [x] 确保 ConfigLoader 加载的 customTools 正确传递到 AgentFactory

- [x] Task 5: 验证 `/skills` 命令已正确工作 (AC: #1, #3)
  - [x] 确认 `printSkills()` 已在 REPLLoop 中实现且正常工作
  - [x] 确认无技能时显示 "No skills loaded."

- [x] Task 6: 添加测试覆盖 (AC: #1-#5)
  - [x] 测试：customTools 配置正确加载和注册
  - [x] 测试：无效 Schema 的工具被跳过
  - [x] 测试：不存在的脚本路径被跳过
  - [x] 测试：/skills 显示已加载技能
  - [x] 测试：/skills 无技能时显示提示

## Dev Notes

### 重要发现：`/skills` 命令已实现

**`/skills` 命令已在 Story 2.3 中实现。** 查看 `REPLLoop.swift` 第 182-183 行和第 242-259 行：

```swift
case "/skills":
    printSkills()
```

```swift
private func printSkills() {
    guard let registry = skillRegistry else {
        renderer.output.write("No skills loaded.\n")
        return
    }
    let skills = registry.allSkills
    if skills.isEmpty {
        renderer.output.write("No skills loaded.\n")
    } else {
        let sorted = skills.sorted { $0.name < $1.name }
        renderer.output.write("Available skills (\(sorted.count)):\n")
        for skill in sorted {
            renderer.output.write("  \(skill.name): \(skill.description)\n")
        }
    }
}
```

**这意味着 AC#1 和 AC#3 已经满足。** 本故事的核心工作是 AC#2（自定义工具注册）和相关的 AC#4、AC#5（错误处理）。

### SDK API 分析

#### 1. `defineTool()` 函数（ToolBuilder.swift）

SDK 提供 4 个 `defineTool()` 重载：

**推荐使用：Raw Dictionary Input 版本**（最适合自定义工具，输入从 JSON 转换）：

```swift
public func defineTool(
    name: String,
    description: String,
    inputSchema: ToolInputSchema,  // 即 [String: Any]
    isReadOnly: Bool = false,
    annotations: ToolAnnotations? = nil,
    execute: @Sendable @escaping ([String: Any], ToolContext) async -> ToolExecuteResult
) -> ToolProtocol
```

这个版本接收 `[String: Any]` 原始字典输入，无需定义 Codable 类型，直接从配置 JSON 中读取 schema 和参数即可。

**`ToolInputSchema` 类型：**
```swift
public typealias ToolInputSchema = [String: Any]
```
就是 JSON Schema 字典。

**`ToolExecuteResult` 结构：**
```swift
public struct ToolExecuteResult {
    public var content: String
    public var isError: Bool
}
```

#### 2. `assembleToolPool()` 函数

已在 `AgentFactory.computeToolPool()` 中使用：
```swift
return assembleToolPool(
    baseTools: baseTools,
    customTools: customTools,
    mcpTools: nil,
    allowed: args.toolAllow,
    disallowed: args.toolDeny
)
```

`customTools` 参数接受 `[ToolProtocol]?`，自定义工具通过 `defineTool()` 创建后放入此数组即可。

### 自定义工具配置格式设计

在 `~/.openagent/config.json` 中添加 `customTools` 数组：

```json
{
  "customTools": [
    {
      "name": "weather",
      "description": "Get weather for a city",
      "inputSchema": {
        "type": "object",
        "properties": {
          "city": {
            "type": "string",
            "description": "City name"
          }
        },
        "required": ["city"]
      },
      "execute": "/path/to/weather-script.sh",
      "isReadOnly": true
    }
  ]
}
```

**字段说明：**
- `name`：工具名称（必须唯一）
- `description`：工具描述（LLM 使用此描述决定何时调用工具）
- `inputSchema`：JSON Schema 对象，描述工具输入参数
- `execute`：要执行的可执行文件或脚本的绝对路径（接收 stdin JSON，输出到 stdout）
- `isReadOnly`：是否只读工具（可选，默认 false）

### 执行模式：基于进程的自定义工具

自定义工具的 execute 通过 `Process` 执行外部命令：

```swift
// 伪代码
let process = Process()
process.executableURL = URL(fileURLWithPath: toolConfig.execute)
let pipe = Pipe()
process.standardInput = pipe
process.standardOutput = Pipe()
// 将 input 字典序列化为 JSON 写入 stdin
// 读取 stdout 作为结果
```

**约束：**
- execute 路径必须是绝对路径或相对于 cwd 的路径
- 工具接收 JSON 输入通过 stdin
- 工具输出通过 stdout 返回
- 工具退出码非零时，结果标记为 error
- 执行超时保护（建议 30 秒）

### 当前实现分析

#### ConfigLoader.swift — 需要修改

**`CLIConfig` 结构体（第 7 行）：** 需要添加 `customTools` 字段。

```swift
struct CLIConfig: Decodable {
    // ... 现有字段 ...
    var customTools: [CustomToolConfig]? = nil  // 新增
}
```

**`ConfigLoader.apply()` 方法（第 67 行）：** 需要添加 customTools 传递逻辑。

#### ParsedArgs — 需要修改

在 `ArgumentParser.swift` 的 `ParsedArgs` 结构体中添加：
```swift
var customTools: [CustomToolConfig]? = nil
```

#### AgentFactory.swift — 需要修改

**新增方法：** `createCustomTools(from:)` 将 `CustomToolConfig` 数组转换为 `[ToolProtocol]`。

**修改方法：** `computeToolPool()` 中添加自定义工具到 customTools 数组。

**修改方法：** `createAgent()` 中传递 customTools。

#### CLI.swift — 可能需要修改

确保 ConfigLoader 加载的 customTools 正确传递到 ParsedArgs，然后到 AgentFactory。

#### REPLLoop.swift — 不需要修改

`/skills` 命令已完全实现（Story 2.3）。

### 命令解析注意事项

本故事不需要添加新的斜杠命令。`/skills` 已存在。自定义工具注册是通过配置文件在启动时完成的，不是 REPL 运行时操作。

### 关键约束

1. **零 internal 访问** — 仅使用 `import OpenAgentSDK`
2. **零第三方依赖** — 不引入外部库
3. **不修改 SDK** — 如遇 SDK 限制，记录为 `// SDK-GAP:` 注释
4. **`defineTool()` 是公开函数** — 可以直接调用创建自定义工具
5. **`ToolInputSchema` 是 `[String: Any]` 类型别名** — 直接从 JSON 解析
6. **`ToolExecuteResult` 是公开结构体** — 可直接构造返回值
7. **Process 执行外部脚本** — 使用 Foundation 的 `Process` 类

### 不要做的事

1. **不要修改 REPLLoop.swift** — `/skills` 命令已经实现
2. **不要添加 `--custom-tool` CLI 标志** — 自定义工具仅通过配置文件注册
3. **不要在配置文件中支持内联脚本** — execute 必须是外部文件路径
4. **不要实现运行时动态添加工具** — 工具在启动时注册，不支持 REPL 中动态增减
5. **不要为自定义工具实现超复杂的错误恢复** — 简单跳过失败的工具即可

### 前一故事的关键学习

Story 7.6（动态 MCP 管理）完成后的关键信息：

1. **`renderer.output.write()` 是标准输出方式** — 所有输出通过此方法
2. **`ConfigLoader.apply()` 使用 `explicitlySet` 避免覆盖** — 新字段需要遵循此模式
3. **全量回归测试通过** — 开发完成后需确认所有现有测试仍通过
4. **`AgentFactory.computeToolPool()` 是工具组装的核心** — 自定义工具在此处集成
5. **Process 脚本执行在 HookConfigLoader 中有参考实现** — 可参考其模式

### CustomToolConfig 结构体设计

需要定义一个新的 Decodable 结构体来解析配置文件中的自定义工具定义：

```swift
struct CustomToolConfig: Decodable {
    let name: String
    let description: String
    let inputSchema: [String: Any]  // JSON Schema
    let execute: String              // 可执行文件路径
    let isReadOnly: Bool?            // 可选，默认 false

    // Custom decoding for inputSchema (Any 不直接 Decodable)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        execute = try container.decode(String.self, forKey: .execute)
        isReadOnly = try container.decodeIfPresent(Bool.self, forKey: .isReadOnly)

        // inputSchema 使用 JSONSerialization 手动解析
        let schemaData = try container.decode(Data.self, forKey: .inputSchema)
        inputSchema = (try JSONSerialization.jsonObject(with: schemaData) as? [String: Any]) ?? [:]
    }
}
```

**注意：** `[String: Any]` 不直接遵循 `Decodable`。需要自定义解码或使用 `JSONSerialization`。参见 `MCPConfigLoader.swift` 和 `HookConfigLoader.swift` 中的类似模式。

### 自定义工具执行实现参考

```swift
// 在 AgentFactory 或新的 CustomToolLoader 中
static func createCustomTools(from configs: [CustomToolConfig]?) -> [ToolProtocol] {
    guard let configs, !configs.isEmpty else { return [] }

    var tools: [ToolProtocol] = []
    for config in configs {
        // 验证 execute 路径存在
        if !FileManager.default.fileExists(atPath: config.execute) {
            FileHandle.standardError.write(
                "Warning: Custom tool '\(config.name)' execute path not found: \(config.execute)\n".data(using: .utf8)!)
            continue
        }

        // 验证 inputSchema 非空
        if config.inputSchema.isEmpty {
            FileHandle.standardError.write(
                "Warning: Custom tool '\(config.name)' has empty inputSchema, skipping.\n".data(using: .utf8)!)
            continue
        }

        let executePath = config.execute
        let toolName = config.name

        let tool = defineTool(
            name: config.name,
            description: config.description,
            inputSchema: config.inputSchema,
            isReadOnly: config.isReadOnly ?? false
        ) { (input: [String: Any], context: ToolContext) async -> ToolExecuteResult in
            // 通过 Process 执行外部脚本
            do {
                let result = try await executeExternalTool(
                    path: executePath,
                    input: input
                )
                return ToolExecuteResult(content: result, isError: false)
            } catch {
                return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
            }
        }
        tools.append(tool)
    }
    return tools
}
```

### 项目结构说明

本故事修改 3 个现有文件，不创建新文件：

```
Sources/OpenAgentCLI/
  ConfigLoader.swift     # 修改：添加 CustomToolConfig 和 customTools 字段
  ArgumentParser.swift   # 修改：ParsedArgs 添加 customTools 属性
  AgentFactory.swift     # 修改：添加自定义工具创建和注册逻辑

Tests/OpenAgentCLITests/
  CustomToolRegistrationTests.swift  # 新增：自定义工具注册测试
```

### 测试策略

**测试环境：** CustomToolRegistrationTests

**单元测试覆盖：**

| 测试方法名 | 覆盖 AC | 说明 |
|-----------|---------|------|
| testCustomToolConfig_decoding | #2 | 从 JSON 解析 CustomToolConfig |
| testCustomToolConfig_missingExecutePath_skipped | #5 | 脚本路径不存在时跳过 |
| testCustomToolConfig_emptySchema_skipped | #4 | 空 Schema 时跳过 |
| testCustomToolRegistration_toolsAddedToPool | #2 | 自定义工具被添加到工具池 |
| testCustomToolRegistration_toolExecution | #2 | 自定义工具执行并返回结果 |
| testCustomToolRegistration_toolExecutionFailure | #2 | 工具执行失败返回错误 |
| testSkillsCommand_showsSkills | #1 | /skills 显示技能列表（已有覆盖） |
| testSkillsCommand_noSkills | #3 | /skills 无技能时显示提示（已有覆盖） |

**注意：** AC#1 和 AC#3 的测试已在 Story 2.3 中覆盖。本故事的新测试聚焦于 AC#2、#4、#5。

### SDK API 参考

本故事使用以下 SDK API：

- `defineTool(name:description:inputSchema:isReadOnly:annotations:execute:)` — 创建自定义工具
  - Raw Dictionary Input 版本，接收 `[String: Any]` 和返回 `ToolExecuteResult`
  - 位置：`.build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/ToolBuilder.swift`
- `ToolInputSchema` (`[String: Any]`) — JSON Schema 类型别名
- `ToolExecuteResult` — 工具执行结果（content + isError）
- `ToolProtocol` — 工具协议
- `assembleToolPool()` — 工具池组装函数
- `SkillRegistry.allSkills` — 已注册技能列表（已在 REPLLoop 中使用）

无新 SDK API 需要引入。无 SDK-GAP 预期。

### 架构合规性

本故事涉及架构文档中的 **FR10.3** 和 **FR10.4**：

- **FR10.3:** 在 REPL 中通过 `/skills` 列出可用技能 (P2) — 已在 Story 2.3 实现
- **FR10.4:** 通过配置文件注册自定义工具 (P2) — 本故事核心工作

**FR 覆盖映射：**
- FR10.3 -> Epic 7, Story 7.7 (本故事，已部分实现)
- FR10.4 -> Epic 7, Story 7.7 (本故事)

**架构模式遵循：**
- "薄编排层" — CLI 仅解析配置并调用 `defineTool()` 创建工具，不实现工具执行逻辑
- "配置分层" — 自定义工具通过配置文件（最低优先级）注册
- "零 internal 访问" — 使用 `defineTool()` 公开 API

[Source: epics.md#Story 7.7]
[Source: prd.md#FR10.3, FR10.4]
[Source: architecture.md#配置分层 — "CLI 参数 > 环境变量 > 配置文件 > SDK 默认值"]

### 延迟工作

- **`--custom-tool` CLI 标志** — 支持通过命令行直接注册自定义工具（AC 不要求）
- **REPL 中动态注册工具** — `/tool add` 和 `/tool remove` 命令（AC 不要求）
- **自定义工具的权限控制** — 自定义工具的 isReadOnly 支持自定义权限级别（AC 不要求）
- **自定义工具配置热重载** — 运行时重新加载配置文件（AC 不要求）

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.7]
- [Source: _bmad-output/planning-artifacts/prd.md#FR10.3, FR10.4]
- [Source: _bmad-output/planning-artifacts/architecture.md#配置分层]
- [Source: Sources/OpenAgentCLI/REPLLoop.swift — printSkills() (已实现)]
- [Source: Sources/OpenAgentCLI/ConfigLoader.swift — CLIConfig, ConfigLoader.apply()]
- [Source: Sources/OpenAgentCLI/AgentFactory.swift — computeToolPool(), createSkillRegistry()]
- [Source: .build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/ToolBuilder.swift — defineTool()]
- [Source: .build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/SkillRegistry.swift — allSkills]
- [Source: _bmad-output/implementation-artifacts/7-6-dynamic-mcp-management.md — 前一故事]

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- Fixed `[String: Any]` decoding issue: JSONDecoder cannot decode `[String: Any]` directly. Solved by using two-pass loading: JSONDecoder for standard fields + JSONSerialization for customTools extraction.
- Fixed stderr capture test reliability: `freopen`/`fclose` on C's `stderr` stream breaks subsequent tests. Switched to fd-level `dup`/`dup2` with POSIX `write()` for warnings.
- Added explicit CodingKeys to CLIConfig to exclude customTools from Decodable synthesis.

### Completion Notes List

- All 6 tasks completed, all 19 ATDD tests passing, full regression suite (600 tests) passing with 0 failures.
- AC#1 and AC#3 already satisfied by existing `/skills` command implementation (Story 2.3).
- AC#2: Custom tools defined in config.json are loaded, decoded, registered as ToolProtocol, and available in tool pool.
- AC#4: Tools with empty inputSchema are skipped with warning.
- AC#5: Tools with nonexistent execute path are skipped with warning. CLI continues running.
- Custom tool execution uses Foundation Process to spawn external scripts, passing JSON via stdin, capturing stdout.
- No new files created; 3 source files modified + 1 test file fixed.

### File List

- Sources/OpenAgentCLI/ConfigLoader.swift (modified: added CustomToolConfig struct, customTools field on CLIConfig, two-pass loading with JSONSerialization, custom Decodable init with explicit CodingKeys, memberwise init, customTools pass-through in apply())
- Sources/OpenAgentCLI/ArgumentParser.swift (modified: added customTools: [CustomToolConfig]? to ParsedArgs)
- Sources/OpenAgentCLI/AgentFactory.swift (modified: added createCustomTools(from:) using SDK's defineTool() raw dictionary overload, executeExternalTool() using Process, integrated in computeToolPool())
- Tests/OpenAgentCLITests/CustomToolRegistrationTests.swift (modified: fixed stderr capture in 2 tests to use fd-level dup/dup2 instead of freopen/fclose to avoid breaking C stderr stream between tests)

### Change Log

- 2026-04-22: Story 7.7 implementation complete. All tasks done, 19 tests passing, 600 total tests passing with 0 regressions.
