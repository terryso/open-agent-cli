# Story 7.3: 持久化配置文件

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为一个用户，
我想要将 CLI 配置保存在文件中，
以便我不必每次都传入参数。

## Acceptance Criteria

1. **假设** 配置文件存在于 `~/.openagent/config.json`
   **当** CLI 启动
   **那么** 配置文件中的设置作为默认值应用

2. **假设** 配置文件和 CLI 参数同时指定了相同的设置
   **当** CLI 启动
   **那么** CLI 参数覆盖配置文件中的值

3. **假设** 配置文件包含 `mcpConfigPath`、`hooksConfigPath` 或 `skillDir` 字段
   **当** CLI 启动
   **那么** 这些路径配置从配置文件正确加载并应用

4. **假设** 配置文件包含 `toolAllow` 或 `toolDeny` 字段
   **当** CLI 启动
   **那么** 工具白名单/黑名单从配置文件正确加载并应用

5. **假设** 配置文件目录 `~/.openagent/` 不存在
   **当** CLI 首次运行
   **那么** 自动创建该目录（仅在需要写入时，不阻塞只读操作）

6. **假设** 配置文件中的路径字段（如 `mcpConfigPath`）引用了不存在的文件
   **当** CLI 启动
   **那么** 显示清晰的警告信息，但 CLI 继续运行

7. **假设** 配置文件存在但包含无法识别的字段
   **当** CLI 启动
   **那么** 忽略未知字段，不报错（前向兼容）

## Tasks / Subtasks

- [x] Task 1: 扩展 CLIConfig 结构体支持缺失字段 (AC: #3, #4, #7)
  - [x] 在 `CLIConfig` 中添加 `mcpConfigPath: String?` 字段
  - [x] 在 `CLIConfig` 中添加 `hooksConfigPath: String?` 字段
  - [x] 在 `CLIConfig` 中添加 `skillDir: String?` 字段
  - [x] 在 `CLIConfig` 中添加 `toolAllow: [String]?` 字段
  - [x] 在 `CLIConfig` 中添加 `toolDeny: [String]?` 字段
  - [x] 在 `CLIConfig` 中添加 `output: String?` 字段
  - [x] 验证 `Decodable` 的默认行为已忽略未知字段（前向兼容 AC#7）

- [x] Task 2: 更新 ConfigLoader.apply() 覆盖新增字段 (AC: #1, #2, #3, #4)
  - [x] 在 `apply()` 方法中添加 `mcpConfigPath` 的 nil-fill 逻辑
  - [x] 在 `apply()` 方法中添加 `hooksConfigPath` 的 nil-fill 逻辑
  - [x] 在 `apply()` 方法中添加 `skillDir` 的 nil-fill 逻辑
  - [x] 在 `apply()` 方法中添加 `toolAllow` 的 nil-fill 逻辑
  - [x] 在 `apply()` 方法中添加 `toolDeny` 的 nil-fill 逻辑
  - [x] 在 `apply()` 方法中添加 `output` 的 sentinel/default-fill 逻辑
  - [x] 确保每个字段都遵循 "CLI 参数 > 配置文件" 的优先级规则（AC#2）

- [x] Task 3: 修复 sentinel-value 比较问题 (AC: #2)
  - [x] 在 `ParsedArgs` 中添加 `explicitlySet: Set<String>` 属性追踪用户显式设置的参数
  - [x] 修改 `ArgumentParser.parse()` 在解析每个值标志时将标志名加入 `explicitlySet`
  - [x] 重构 `ConfigLoader.apply()` 使用 `explicitlySet` 而非 sentinel-value 比较
  - [x] 移除 `apply()` 中的 TODO 注释

- [x] Task 4: 添加 ~/.openagent/ 目录自动创建 (AC: #5)
  - [x] 在 `ConfigLoader` 中添加 `ensureConfigDirectory()` 静态方法
  - [x] 使用 `FileManager.default.createDirectory(atPath:withIntermediateDirectories:)` 创建目录
  - [x] 仅在 CLI 需要读取或引用配置时调用，不阻塞主流程
  - [x] 目录创建失败时不阻塞启动（静默忽略或 stderr 警告）

- [x] Task 5: 添加路径字段验证和警告 (AC: #6)
  - [x] 在 `ConfigLoader.apply()` 中，对 `mcpConfigPath` 和 `hooksConfigPath` 检查文件是否存在
  - [x] 若文件不存在，打印警告到 stderr 但不中断
  - [x] 对 `skillDir` 检查目录是否存在，不存在时警告

- [x] Task 6: 添加测试覆盖 (AC: #1-#7)
  - [x] 测试：新增字段（mcpConfigPath, hooksConfigPath, skillDir）从配置文件正确加载
  - [x] 测试：toolAllow/toolDeny 从配置文件正确加载
  - [x] 测试：CLI 参数覆盖配置文件中的新增字段值
  - [x] 测试：explicitlySet 正确追踪用户指定的参数
  - [x] 测试：sentinel-value 问题修复（`--mode default` 不被配置覆盖）
  - [x] 测试：配置文件包含未知字段时不报错（前向兼容）
  - [x] 测试：路径字段引用不存在文件时产生警告
  - [x] 测试：~/.openagent/ 目录不存在时自动创建
  - [x] 回归测试：所有现有 ConfigLoaderTests 和 AgentFactoryTests 通过

## Dev Notes

### 前一故事的关键学习

Story 7.2（JSON 输出模式）完成后的项目状态：

1. **ConfigLoader.swift 已存在** — 在 Story 1.2 中创建，实现了 `~/.openagent/config.json` 的加载逻辑。`CLIConfig` 结构体已支持 `apiKey`、`baseURL`、`model`、`provider`、`mode`、`tools`、`maxTurns`、`maxBudgetUsd`、`systemPrompt`、`thinking`、`logLevel` 字段。

2. **ConfigLoader.apply() 有已知的 sentinel-value 问题** — 代码中的 TODO 注释明确指出：对于有非 Optional 默认值的字段（`mode="default"`、`tools="core"`、`maxTurns=10`、`model="glm-5.1"`），当前通过比较硬编码默认值来判断"用户是否显式设置"。这意味着用户显式传入 `--mode default` 时，配置文件中的值会覆盖它（因为 `args.mode == "default"` 被视为"未设置"）。需要通过 `explicitlySet` 集合来修复。

3. **CLIConfig 中缺少多个 ParsedArgs 字段** — `mcpConfigPath`、`hooksConfigPath`、`skillDir`、`toolAllow`、`toolDeny`、`output` 这些字段在 `CLIConfig` 中没有对应属性，因此无法通过配置文件设置。用户必须在每次命令中指定这些参数。

4. **Swift `Decodable` 天然忽略未知字段** — 当 JSON 包含 `CLIConfig` 中未定义的键时，`JSONDecoder` 不会报错，只是忽略它们。这自动满足 AC#7（前向兼容）。

5. **`~/.openagent/` 目录已存在** — 当前环境下该目录已存在且包含 `config.json`。但首次使用的用户不会有此目录。

### 当前实现分析

#### ConfigLoader.swift 的当前状态

```swift
struct CLIConfig: Decodable {
    var apiKey: String? = nil
    var baseURL: String? = nil
    var model: String? = nil
    var provider: String? = nil
    var mode: String? = nil
    var tools: String? = nil
    var maxTurns: Int? = nil
    var maxBudgetUsd: Double? = nil
    var systemPrompt: String? = nil
    var thinking: Int? = nil
    var logLevel: String? = nil
}
```

**缺失的字段（本故事需要添加）：**
- `mcpConfigPath: String?` — MCP 服务器配置文件路径
- `hooksConfigPath: String?` — Hook 配置文件路径
- `skillDir: String?` — 技能目录路径
- `toolAllow: [String]?` — 工具白名单
- `toolDeny: [String]?` — 工具黑名单
- `output: String?` — 输出格式

#### ConfigLoader.apply() 的 sentinel-value 问题

当前实现：

```swift
// 问题：用户显式传入 --mode default 时，这里也会触发覆盖
if args.mode == "default", let mode = config.mode {
    args.mode = mode
}
// 问题：用户显式传入 --tools core 时，这里也会触发覆盖
if args.tools == "core", let tools = config.tools {
    args.tools = tools
}
// 类似问题存在于 model、maxTurns
```

**修复方案：**

在 `ParsedArgs` 中添加 `explicitlySet: Set<String>` 集合。在 `ArgumentParser.parse()` 中，当解析到某个值标志时，将标志名加入集合。然后在 `ConfigLoader.apply()` 中检查 `!args.explicitlySet.contains("mode")` 而非 `args.mode == "default"`。

```swift
// ParsedArgs 中新增:
var explicitlySet: Set<String> = []

// ArgumentParser.parse() 中:
} else if arg == "--mode" {
    // ...
    result.mode = value
    result.explicitlySet.insert("mode")  // 标记为用户显式设置
    // ...
}

// ConfigLoader.apply() 中:
if !args.explicitlySet.contains("mode"), let mode = config.mode {
    args.mode = mode
}
```

#### 目录自动创建

```swift
static func ensureConfigDirectory() {
    let dir = configFilePath
        .components(separatedBy: "/")
        .dropLast()
        .joined(separator: "/")
    do {
        try FileManager.default.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true
        )
    } catch {
        // 非阻塞 — 仅打印警告
        let msg = "Warning: Could not create config directory \(dir): \(error.localizedDescription)\n"
        FileHandle.standardError.write(msg.data(using: .utf8)!)
    }
}
```

#### 需要修改的文件

**1. `Sources/OpenAgentCLI/ArgumentParser.swift`（修改）**

- 在 `ParsedArgs` 中添加 `var explicitlySet: Set<String> = []`
- 在 `parse()` 方法的每个值标志解析后，调用 `result.explicitlySet.insert("fieldName")`

**2. `Sources/OpenAgentCLI/ConfigLoader.swift`（修改）**

- 扩展 `CLIConfig` 添加 6 个缺失字段
- 重构 `apply()` 方法使用 `explicitlySet` 集合
- 添加 `ensureConfigDirectory()` 方法
- 添加路径验证和警告逻辑

**3. `Sources/OpenAgentCLI/CLI.swift`（可能修改）**

- 若需要在启动时调用 `ensureConfigDirectory()`，在此处添加调用

**不需要修改的文件**

```
Sources/OpenAgentCLI/
  AgentFactory.swift                # 无变更 — Agent 创建逻辑不变
  OutputRenderer.swift              # 无变更
  OutputRenderer+SDKMessage.swift   # 无变更
  REPLLoop.swift                    # 无变更
  PermissionHandler.swift           # 无变更
  SessionManager.swift              # 无变更
  MCPConfigLoader.swift             # 无变更
  HookConfigLoader.swift            # 无变更
  ANSI.swift                        # 无变更
  Version.swift                     # 无变更
  main.swift                        # 无变更
  SignalHandler.swift               # 无变更
  MarkdownRenderer.swift            # 无变更
  CLISingleShot.swift               # 无变更
  JsonOutputRenderer.swift          # 无变更
```

### SDK API 参考

本故事不使用新的 SDK API。配置文件加载是纯 CLI 层面的逻辑，不涉及 SDK 类型。

相关现有 API：
- `ArgumentParser.parse()` — 已有
- `ConfigLoader.load()` / `ConfigLoader.apply()` — 已有
- `FileManager` — Foundation API，用于目录创建和文件检查

无 SDK-GAP 预期。

[Source: architecture.md#FR1.6 — "通过配置文件持久化配置"]
[Source: architecture.md#配置分层 — "CLI 参数 > 环境变量 > 配置文件 > SDK 默认值"]
[Source: prd.md#FR1.6 — "通过配置文件 .openagent/config.yaml 持久化配置 (P2)"]
[Source: Sources/OpenAgentCLI/ConfigLoader.swift — 当前实现]
[Source: Sources/OpenAgentCLI/ArgumentParser.swift — ParsedArgs, parse()]

### 架构合规性

本故事涉及架构文档中的 **FR1.6**：

- **FR1.6:** 通过配置文件持久化配置 (P2)
- **覆盖组件：** `ConfigLoader.swift`（扩展）、`ArgumentParser.swift`（添加 explicitlySet）、`CLI.swift`（调用 ensureConfigDirectory）

**FR 覆盖映射：**
- FR1.6 -> Epic 7, Story 7.3 (本故事)

**架构模式遵循：**
- "配置分层" — CLI 参数 > 环境变量 > 配置文件 > SDK 默认值。本故事确保此分层正确实现。
- "薄编排层" — 配置加载是无副作用的纯数据合并逻辑
- "基于协议的分离" — 不引入新协议，扩展现有结构体

[Source: epics.md#Story 7.3]
[Source: prd.md#FR1.6]
[Source: architecture.md#配置分层]

### 关键约束

1. **零 internal 访问** — 整个项目仅允许 `import OpenAgentSDK`
2. **零第三方依赖** — 不引入外部库，使用 Foundation 的 `JSONDecoder`
3. **不修改 SDK** — 如遇 SDK 限制，记录为 `// SDK-GAP:` 注释
4. **JSON 格式** — PRD 提到 `.openagent/config.yaml`，但架构文档在 MVP 阶段决定使用 JSON。当前实现已使用 JSON。不要引入 YAML 解析器。保持 JSON 格式。
5. **前向兼容** — 配置文件必须容忍未知字段。Swift `Decodable` 天然支持此行为（不会因未知键报错）。
6. **非阻塞** — 配置加载、目录创建、路径验证失败都不应阻塞 CLI 启动
7. **跨平台兼容** — `FileManager` 和 `homeDirectoryForCurrentUser` 在 macOS 和 Linux 上行为一致

### 不要做的事

1. **不要引入 YAML 格式** — PRD 提到了 `config.yaml`，但架构文档明确推迟了 YAML 决策（"推迟的决策：配置文件格式（YAML vs TOML） — P2；JSON 足以满足 MVP"）。当前实现已使用 JSON，本故事继续使用 JSON。

2. **不要在配置文件中存储 API Key** — 虽然当前 `CLIConfig` 有 `apiKey` 字段且用户正在使用它，但架构文档指出"不在配置文件中存储 Key（仅环境变量）"。本故事不修改此行为，但开发者应了解这是一个已知的安全权衡。不在此故事中解决。

3. **不要修改 ArgumentParser 的标志验证逻辑** — 不添加 `--config` 标志来指定自定义配置路径（超出本故事范围，当前 ConfigLoader 硬编码 `~/.openagent/config.json`）。

4. **不要让 `ensureConfigDirectory()` 在每次调用时都创建目录** — 使用 `createDirectory(atPath:withIntermediateDirectories:)` 的 `true` 参数，即使目录已存在也不会报错，所以无需检查先决条件。

5. **不要为目录创建引入新的依赖** — 使用 Foundation 的 `FileManager`，不引入任何第三方文件系统库。

6. **不要在 `apply()` 中对数组字段做 merge** — `toolAllow` 和 `toolDeny` 如果 CLI 参数和配置文件都指定了，CLI 参数完全覆盖配置文件的值（不做合并）。这与其他字段的行为一致。

7. **不要在配置文件中支持注释** — JSON 标准不支持注释。如果需要注释功能，应在未来引入 YAML 或 JSONC 格式时解决。

### 项目结构说明

本故事修改 2-3 个现有源文件，不创建新文件：

```
Sources/OpenAgentCLI/
  ArgumentParser.swift    # 修改：添加 explicitlySet 追踪
  ConfigLoader.swift      # 修改：扩展 CLIConfig 字段，重构 apply()，添加目录创建和路径验证
  CLI.swift               # 可能修改：调用 ensureConfigDirectory()（如果决定在启动时触发）
```

新增/修改测试文件：
```
Tests/OpenAgentCLITests/
  ConfigLoaderTests.swift       # 修改：添加新字段测试、explicitlySet 测试、路径验证测试
  ArgumentParserTests.swift     # 可能修改：验证 explicitlySet 集合行为
```

[Source: architecture.md#项目结构]

### 测试策略

**新增测试分布预期：**

| 测试方法名 | 覆盖 AC | 说明 |
|-----------|---------|------|
| testLoad_configWithMcpPath | #3 | mcpConfigPath 从配置文件正确加载 |
| testLoad_configWithHooksPath | #3 | hooksConfigPath 从配置文件正确加载 |
| testLoad_configWithSkillDir | #3 | skillDir 从配置文件正确加载 |
| testLoad_configWithToolAllow | #4 | toolAllow 从配置文件正确加载 |
| testLoad_configWithToolDeny | #4 | toolDeny 从配置文件正确加载 |
| testApply_mcpPath_filledWhenNil | #3 | nil mcpConfigPath 被配置文件填充 |
| testApply_mcpPath_notOverriddenByConfig | #2 | CLI --mcp 不被配置覆盖 |
| testApply_toolAllow_filledWhenNil | #4 | nil toolAllow 被配置文件填充 |
| testApply_toolAllow_notOverriddenByConfig | #2 | CLI --tool-allow 不被配置覆盖 |
| testApply_explicitlySet_preventsOverride | #2 | 用户显式 --mode default 不被配置覆盖 |
| testApply_pathValidation_warnsOnMissingFile | #6 | 不存在的路径字段产生 stderr 警告 |
| testApply_unknownFieldsIgnored | #7 | 未知字段被忽略不报错 |
| testEnsureConfigDirectory_createsDir | #5 | 目录不存在时自动创建 |
| testEnsureConfigDirectory_existingDir | #5 | 目录已存在时不报错 |
| testExplicitlySet_tracksFlaggedValues | #2 | ArgumentParser 正确追踪显式设置的字段 |
| testExplicitlySet_doesNotTrackDefaults | #2 | 默认值不在 explicitlySet 中 |

**测试方法：**

1. **ConfigLoader 单元测试** — 扩展现有 `ConfigLoaderTests`，添加新字段的加载和应用测试。使用临时文件路径（现有模式）。

2. **ArgumentParser 单元测试** — 验证 `explicitlySet` 集合在解析值标志时正确填充。

3. **回归测试** — 确保所有现有 ConfigLoaderTests（6 个）和 AgentFactoryTests 通过。

### 延迟工作

- **`--config` 自定义路径标志** — 当前硬编码 `~/.openagent/config.json`。未来可添加 `--config <path>` 标志支持自定义路径。
- **配置文件 schema 验证** — 当前仅做 JSON 解析，未来可添加 schema 验证和更丰富的错误信息。
- **配置文件自动生成** — 可添加 `openagent --init-config` 命令生成模板配置文件。

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.3]
- [Source: _bmad-output/planning-artifacts/prd.md#FR1.6]
- [Source: _bmad-output/planning-artifacts/architecture.md#配置分层]
- [Source: _bmad-output/planning-artifacts/architecture.md#推迟的决策 — "配置文件格式（YAML vs TOML）"]
- [Source: Sources/OpenAgentCLI/ConfigLoader.swift — 当前实现]
- [Source: Sources/OpenAgentCLI/ArgumentParser.swift — ParsedArgs, parse()]
- [Source: Sources/OpenAgentCLI/CLI.swift — ConfigLoader.apply() 调用点]
- [Source: _bmad-output/implementation-artifacts/7-2-json-output-mode.md — 前一故事]
- [Source: _bmad-output/implementation-artifacts/1-2-agent-factory-with-core-configuration.md — ConfigLoader 原始实现]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md — 延迟项]

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Implemented 6 new fields on CLIConfig: mcpConfigPath, hooksConfigPath, skillDir, toolAllow, toolDeny, output
- Added explicitlySet: Set<String> to ParsedArgs and populated it in all 20 value-flag branches of ArgumentParser.parse()
- Refactored ConfigLoader.apply() to use explicitlySet instead of sentinel-value comparison, fixing the bug where --mode default would be overridden by config file
- Added ConfigLoader.ensureConfigDirectory(at:) static method for ~\/.openagent/ auto-creation
- Added path validation warnings for mcpConfigPath, hooksConfigPath, and skillDir in apply()
- All 16 ATDD tests pass (12 ConfigLoader + 4 ArgumentParser)
- Full regression suite: 548 tests, 0 failures
- Decodable naturally ignores unknown JSON fields (AC#7 verified by testLoad_unknownFieldsIgnored)
- No new files created; all changes to existing source files

### File List

- Sources/OpenAgentCLI/ConfigLoader.swift (modified: added 6 CLIConfig fields, refactored apply() with explicitlySet, added ensureConfigDirectory(), added path validation warnings)
- Sources/OpenAgentCLI/ArgumentParser.swift (modified: added explicitlySet property to ParsedArgs, added explicitlySet.insert() in all value-flag parse branches)
- Tests/OpenAgentCLITests/ConfigLoaderTests.swift (ATDD tests from Step 2 - 12 new test methods)
- Tests/OpenAgentCLITests/ArgumentParserTests.swift (ATDD tests from Step 2 - 4 new test methods)

### Change Log

- 2026-04-22: Story 7.3 implementation complete - persistent configuration file with explicitlySet fix, new config fields, directory auto-creation, and path validation warnings
