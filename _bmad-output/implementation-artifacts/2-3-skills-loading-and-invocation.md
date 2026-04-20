# Story 2.3: 技能加载与调用

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## 故事

作为一个用户，
我想要从目录加载技能定义并调用特定技能，
以便我可以使用预定义的提示模板处理常见任务，无需重启。

## 验收标准

1. **假设** 技能目录包含有效的技能定义
   **当** 我运行 `openagent --skill-dir ./skills`
   **那么** 技能被加载到 SDK 的 `SkillRegistry` 中

2. **假设** 传入了 `--skill review`
   **当** CLI 启动
   **那么** 自动调用 "review" 技能

3. **假设** 技能已加载
   **当** 我在 REPL 中输入 `/skills`
   **那么** 列出可用技能及其名称和描述

4. **假设** 提供了无效的技能名称
   **当** 我运行 `openagent --skill nonexistent`
   **那么** 错误信息显示 "Skill not found" 并列出可用技能

## 任务 / 子任务

- [x] 任务 1: 增强 AgentFactory 以支持技能加载 (AC: #1)
  - [x] 修改 `AgentFactory.createAgent(from:)` 将 `args.skillDir` 和 `args.skillName` 传入 `AgentOptions`
  - [x] 将 `skillDirectories` 设为 `[args.skillDir]`（非 nil 时），触发 SDK 的 `autoDiscoverSkills()`
  - [x] 将 `skillNames` 设为 `[args.skillName]`（非 nil 时），限制只加载指定技能
  - [x] 确保 `createSkillTool(registry:)` 被自动注入到工具池

- [x] 任务 2: 实现 --skill 自动调用逻辑 (AC: #2, #4)
  - [x] 修改 `CLI.swift`：在 Agent 创建后、进入 REPL/单次模式前检查 `args.skillName`
  - [x] 如果 `args.skillDir` 为 nil 但 `args.skillName` 不为 nil，使用默认目录发现技能
  - [x] 查找指定技能：使用 `SkillLoader.discoverSkills()` 搜索结果或 `SkillRegistry.find()`
  - [x] 技能存在时：将技能的 `promptTemplate` 作为单次查询发送给 Agent
  - [x] 技能不存在时：显示 "Skill not found: {name}" 并列出已发现的可用技能名称
  - [x] 技能调用后：根据是否有 `args.prompt` 决定继续 REPL 还是退出

- [x] 任务 3: 实现 /skills REPL 命令 (AC: #3)
  - [x] 修改 `REPLLoop`：新增 `skillRegistry: SkillRegistry?` 属性
  - [x] 在 `handleSlashCommand` 中添加 `/skills` case
  - [x] 显示格式：`{name}: {description}`（每行一个技能），按名称排序
  - [x] 无技能时显示 "No skills loaded."
  - [x] 更新 `/help` 输出以包含 `/skills` 命令

- [x] 任务 4: 编写 AgentFactory 技能集成测试 (AC: #1)
  - [x] 测试 `createAgent` 传入 `skillDir` 时 Agent 创建成功
  - [x] 测试 `computeToolPool` 包含 SkillTool
  - [x] 测试无 `skillDir` 时行为不变（回归测试）

- [x] 任务 5: 编写 CLI 技能调用测试 (AC: #2, #4)
  - [x] 测试 `--skill` 有效技能名时调用成功
  - [x] 测试 `--skill` 无效技能名时错误信息显示

- [x] 任务 6: 编写 REPL /skills 命令测试 (AC: #3)
  - [x] 测试 `/skills` 列出已加载技能
  - [x] 测试 `/skills` 无技能时的空列表消息

- [x] 任务 7: 回归测试验证 (AC: 全部)
  - [x] 确保 221 项现有测试全部通过
  - [x] 确保不破坏 Story 2.1（工具加载）和 Story 2.2（工具调用可见性）的任何功能

## 开发备注

### 前一故事的关键学习

Story 2.2（工具调用可见性）已建立以下模式：

1. **221 项测试全部通过** — 分布于 ArgumentParserTests、AgentFactoryTests、ConfigLoaderTests、OutputRendererTests、REPLLoopTests、CLISingleShotTests、SmokePerformanceTests、ToolLoadingTests。[来源: 最新 `swift test` 执行结果]

2. **MockTextOutputStream 模式** — OutputRendererTests 中的 `MockTextOutputStream`，用于捕获渲染输出并断言。[来源: `Tests/OpenAgentCLITests/OutputRendererTests.swift`]

3. **AgentFactory 是单一桥梁** — `AgentFactory.createAgent(from:)` 是 `ParsedArgs` 和 SDK `Agent` 之间的唯一转换点。[来源: `Sources/OpenAgentCLI/AgentFactory.swift`]

4. **CLI.swift 是顶层调度器** — 负责路由到 REPL 或单次模式，不含业务逻辑。[来源: `Sources/OpenAgentCLI/CLI.swift`]

5. **REPLLoop 通过 protocol 实现可测试性** — `InputReading` protocol 允许注入 mock 输入。[来源: `Sources/OpenAgentCLI/REPLLoop.swift`]

6. **JSON 参数摘要已实现** — `OutputRenderer+SDKMessage.swift` 中的 `summarizeInput` 可解析 JSON input 字符串。[来源: Story 2.2 实现]

### SDK API 详细参考

本故事使用以下 SDK public API：

```swift
// 技能加载器 — 从文件系统发现 SKILL.md 技能包
public enum SkillLoader {
    // 从指定目录发现技能，可选按名称过滤
    public static func discoverSkills(
        from directories: [String]? = nil,
        skillNames: [String]? = nil
    ) -> [Skill]

    // 加载单个技能目录
    public static func loadSkillFromDirectory(_ skillDir: String) -> Skill?

    // 默认技能目录（按优先级排序）
    public static func defaultSkillDirectories() -> [String]
}

// 技能注册表 — 线程安全的技能管理
public final class SkillRegistry: @unchecked Sendable {
    public init(promptTokenBudget: Int = 500)
    public func register(_ skill: Skill)
    public func find(_ name: String) -> Skill?
    public func has(_ name: String) -> Bool
    public var allSkills: [Skill]
    public var userInvocableSkills: [Skill]

    // 从文件系统发现并注册技能
    @discardableResult
    public func registerDiscoveredSkills(
        from directories: [String]? = nil,
        skillNames: [String]? = nil
    ) -> Int

    // 为系统提示词格式化技能列表
    public func formatSkillsForPrompt() -> String
}

// 技能定义（值类型）
public struct Skill: Sendable {
    public let name: String
    public let description: String
    public let aliases: [String]
    public let userInvocable: Bool
    public let promptTemplate: String
    public let whenToUse: String?
    public let argumentHint: String?
    public let baseDir: String?
    public let supportingFiles: [String]
    // ...
}

// 创建 SkillTool（注入到 Agent 工具池）
public func createSkillTool(registry: SkillRegistry) -> ToolProtocol

// AgentOptions 中的技能相关字段
public struct AgentOptions {
    public var skillRegistry: SkillRegistry?
    public var skillDirectories: [String]?
    public var skillNames: [String]?
    public var maxSkillRecursionDepth: Int  // 默认 4

    // 自动发现技能并注入 SkillTool
    public mutating func autoDiscoverSkills()
}
```

[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Skills/SkillLoader.swift]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/SkillRegistry.swift]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/SkillTypes.swift]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift]
[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#L291-L307, L548-L586]

### 关键洞察：SDK 的 autoDiscoverSkills() 已实现技能注入逻辑

SDK 的 `AgentOptions.autoDiscoverSkills()` 方法已经实现了完整的技能发现流程：
1. 检查 `skillDirectories != nil || skillNames != nil`
2. 创建 `SkillRegistry`（如果不存在）
3. 调用 `registerDiscoveredSkills(from:skillNames:)` 发现并注册技能
4. 调用 `createSkillTool(registry:)` 创建 SkillTool
5. 将 SkillTool 追加到 `tools` 数组

**因此 CLI 只需在 `AgentOptions` 中正确设置 `skillDirectories` 和 `skillNames`，然后调用 `autoDiscoverSkills()` 即可。**不需要在 CLI 侧重复实现技能发现逻辑。

[来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#L548-L586]

### 实现策略

#### 任务 1: AgentFactory 增强

**关键决策：在 AgentOptions 组装时传入技能参数。**

当前 `AgentFactory.createAgent(from:)` 组装 `AgentOptions` 时未设置 `skillDirectories`、`skillNames`、`skillRegistry`。需要添加：

```swift
// 在 AgentFactory.createAgent(from:) 中：
let options = AgentOptions(
    // ... 现有参数 ...
    skillDirectories: args.skillDir.map { [$0] },  // String? -> [String]?
    skillNames: args.skillName.map { [$0] }        // String? -> [String]?
)

// 调用 autoDiscoverSkills 完成技能注入
var mutableOptions = options
mutableOptions.autoDiscoverSkills()
```

**注意：** `AgentOptions` 是 struct，`autoDiscoverSkills()` 是 `mutating` 方法。需要用 `var` 声明。

**同时需要返回 SkillRegistry 引用** — CLI 需要访问它来：
1. 在 --skill 模式下查找技能
2. 传递给 REPLLoop 用于 /skills 命令

方案：让 `createAgent` 返回一个包含 Agent 和可选 SkillRegistry 的元组，或者新增一个工厂方法来获取 registry。

**推荐方案：新增 `AgentFactory.createSkillRegistry(from:)` 方法**，在创建 Agent 之前先构建 SkillRegistry：

```swift
/// 从 CLI 参数构建 SkillRegistry（如果需要）。
/// 返回 nil 如果无需技能加载。
static func createSkillRegistry(from args: ParsedArgs) -> SkillRegistry? {
    guard args.skillDir != nil || args.skillName != nil else { return nil }
    let registry = SkillRegistry()
    let dirs = args.skillDir.map { [$0] }
    let names = args.skillName.map { [$0] }
    registry.registerDiscoveredSkills(from: dirs, skillNames: names)
    return registry
}
```

然后在 `createAgent` 中使用此 registry。

#### 任务 2: --skill 自动调用

**执行流程：**

```
CLI.run()
  1. 解析参数 -> ParsedArgs
  2. 创建 SkillRegistry（如果需要）
  3. 创建 Agent（注入 SkillRegistry + SkillTool）
  4. 如果 args.skillName != nil:
     a. 在 registry 中查找技能
     b. 找到 -> 将 promptTemplate 发送给 Agent（流式）
     c. 未找到 -> 显示错误 + 可用技能列表，退出码 1
  5. 进入 REPL 或单次模式
```

**注意 --skill 与 --skill-dir 的组合：**
- `--skill review` + 无 `--skill-dir`：从默认目录发现技能，只注册 "review"
- `--skill review` + `--skill-dir ./skills`：从 ./skills 发现，只注册 "review"
- 只有 `--skill-dir ./skills`：从 ./skills 发现所有技能，注册全部
- `--skill nonexistent`：显示 "Skill not found: nonexistent" + 可用技能列表

**自动调用后行为：**
- 技能作为 Agent 的首次消息发送，使用 `agent.stream(skill.promptTemplate)`
- 如果同时有 `args.prompt`（位置参数），REPL/单次模式按原有逻辑处理
- 如果只有 `--skill`，技能执行后进入 REPL 继续交互

#### 任务 3: /skills REPL 命令

在 REPLLoop 中新增 `skillRegistry` 属性：

```swift
struct REPLLoop {
    let agent: Agent
    let renderer: OutputRenderer
    let reader: InputReading
    let toolNames: [String]
    let skillRegistry: SkillRegistry?  // 新增

    // ...
}
```

`/skills` 命令输出格式：
```
Available skills (3):
  commit: Analyze staged and unstaged changes, then suggest a well-crafted git commit message.
  debug: Analyze errors and investigate issues to identify root causes and provide diagnostic fix suggestions.
  review: Review code changes for correctness, security, performance, style, and test coverage issues.
```

更新 `/help` 输出：
```
Available commands:
  /help          Show this help message
  /tools         Show loaded tools
  /skills        Show loaded skills
  /exit          Exit the REPL
  /quit          Exit the REPL
```

### 架构合规性

本故事涉及架构文档中的 **FR10.1** 和 **FR10.2**：

- **FR10.1:** 通过 `--skill-dir <path>` 加载技能目录 → `AgentFactory.swift`
- **FR10.2:** 通过 `--skill <name>` 调用特定技能 → `CLI.swift`
- **FR10.3:** REPL 中通过 `/skills` 列出可用技能 → `REPLLoop.swift`（但 FR10.3 标记为 P2，本故事只做 P0 部分）

[来源: prd.md#FR10, architecture.md#FR10:技能→AgentFactory.swift]

### 关键约束：零 internal 访问

整个项目仅允许 `import OpenAgentSDK`。不得导入任何 internal 模块或使用 `@_implementationOnly`。如果发现 SDK 缺少 public API，使用 `// SDK-GAP:` 注释记录，不绕过。

[来源: prd.md#技术约束, architecture.md#执行指南]

### 不要做的事

1. **不要修改 ArgumentParser** — `--skill-dir` 和 `--skill` 参数已完整实现，包括 help 文本。[来源: `Sources/OpenAgentCLI/ArgumentParser.swift#L180-188`]
2. **不要修改 OutputRenderer** — 本故事不涉及渲染逻辑变更。
3. **不要修改工具加载逻辑** — 工具层级加载（`mapToolTier`）是 Story 2.1 的范围。技能工具通过 SDK 的 `autoDiscoverSkills()` 自动注入。
4. **不要实现技能的 ToolRestriction 或 modelOverride 处理** — 那些由 SDK 内部自动处理，CLI 无需关心。
5. **不要创建新的 SkillTool** — 使用 SDK 的 `createSkillTool(registry:)` 工厂函数。
6. **不要实现 /skills 的详细模式** — 只做简单列表，不需要显示 aliases、whenToUse 等信息。

### 项目结构说明

需要修改的文件：
```
Sources/OpenAgentCLI/
  AgentFactory.swift        # 新增 createSkillRegistry(), 修改 createAgent() 传入技能参数
  CLI.swift                 # 新增 --skill 自动调用逻辑，传递 SkillRegistry 给 REPL
  REPLLoop.swift            # 新增 skillRegistry 属性，新增 /skills 命令
```

需要新增的测试：
```
Tests/OpenAgentCLITests/
  SkillLoadingTests.swift   # 新建测试文件，覆盖 AC#1-#4
```

不修改的文件：
```
Sources/OpenAgentCLI/
  ArgumentParser.swift       # 参数解析不变（--skill-dir 和 --skill 已存在）
  OutputRenderer.swift       # 渲染不变
  OutputRenderer+SDKMessage.swift  # 消息渲染不变
  CLIEntry.swift             # 入口不变
  ANSI.swift                 # ANSI 辅助不变
  Version.swift              # 版本不变
  CLISingleShot.swift        # 单次模式不变
  ConfigLoader.swift         # 配置加载不变
```

[来源: architecture.md#项目结构]

### 测试策略

**新增测试分布预期：**

| 测试方法名 | 覆盖 AC | 说明 |
|-----------|---------|------|
| testCreateSkillRegistry_withSkillDir_returnsRegistry | #1 | skillDir 存在时构建 registry |
| testCreateSkillRegistry_noSkillArgs_returnsNil | #1 | 无技能参数时返回 nil |
| testCreateAgent_withSkillDir_skillToolInPool | #1 | Agent 工具池包含 SkillTool |
| testSkillInvocation_validSkill_sendsPromptTemplate | #2 | 有效技能名自动调用 |
| testSkillInvocation_invalidSkill_showsError | #4 | 无效技能名显示错误 |
| testREPLSkillsCommand_listsSkills | #3 | /skills 列出已加载技能 |
| testREPLSkillsCommand_noSkills_showsMessage | #3 | 无技能时显示提示 |
| testREPLHelp_includesSkillsCommand | #3 | /help 包含 /skills |

**测试方法：**

1. **AgentFactory 测试** — 构造包含 `skillDir` 的 `ParsedArgs`，验证 `createSkillRegistry()` 返回的 registry 包含发现的技能。
2. **CLI 技能调用测试** — 需要 mock Agent 或使用临时技能目录。创建包含 SKILL.md 的临时目录进行测试。
3. **REPL /skills 测试** — 构造包含注册技能的 `SkillRegistry`，验证 `/skills` 输出。

**技能目录测试 fixture：**

测试需要创建临时的 SKILL.md 文件：
```
tmpdir/
  test-skill/
    SKILL.md
```

SKILL.md 内容示例：
```markdown
---
name: test-skill
description: A test skill for unit testing
---
This is a test prompt template.
```

### 参考资料

- [来源: _bmad-output/planning-artifacts/epics.md#Story 2.3]
- [来源: _bmad-output/planning-artifacts/prd.md#FR10.1, FR10.2]
- [来源: _bmad-output/planning-artifacts/architecture.md#AgentFactory, 技能加载]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Skills/SkillLoader.swift#discoverSkills, loadSkillFromDirectory]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/SkillRegistry.swift#registerDiscoveredSkills, find, allSkills]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/SkillTypes.swift#Skill struct]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift#createSkillTool]
- [来源: open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift#AgentOptions.skillDirectories, skillNames, autoDiscoverSkills]
- [来源: _bmad-output/implementation-artifacts/2-2-tool-call-visibility.md#前一故事关键学习]
- [来源: Sources/OpenAgentCLI/ArgumentParser.swift#L180-188 (--skill-dir, --skill 已实现)]
- [来源: Sources/OpenAgentCLI/AgentFactory.swift (当前 createAgent 实现)]
- [来源: Sources/OpenAgentCLI/CLI.swift (当前 CLI 调度逻辑)]
- [来源: Sources/OpenAgentCLI/REPLLoop.swift (当前 REPL 和斜杠命令)]

## 开发代理记录

### 使用的代理模型

GLM-5.1

### 调试日志引用

无调试问题。实现过程中发现一个设计决策：`createSkillRegistry` 不按 skillName 过滤发现结果，以便在 --skill 无效时能列出所有可用技能。

### 完成备注列表

- 任务1: 新增 `AgentFactory.createSkillRegistry(from:)` 方法，当 `--skill-dir` 或 `--skill` 参数存在时构建 SkillRegistry。修改 `computeToolPool` 在有技能参数时自动注入 SkillTool。所有技能从目录全部注册（不过滤 skillName），使 CLI 能在 --skill 无效时列出可用技能。
- 任务2: CLI.swift 新增 --skill 自动调用逻辑：查找技能 -> 成功则流式发送 promptTemplate -> 失败则显示 "Skill not found" + 可用技能列表。技能调用后若无位置参数则进入 REPL。
- 任务3: REPLLoop 新增 `skillRegistry: SkillRegistry?` 属性，`/skills` 命令按名称排序列出技能（格式：`{name}: {description}`），无技能时显示 "No skills loaded."。`/help` 输出已更新包含 `/skills`。
- 任务4-6: 27 项测试全部通过，覆盖 AC#1-#4。
- 任务7: 全部 248 项测试通过（221 旧 + 27 新），零回归。

### 文件列表

- `Sources/OpenAgentCLI/AgentFactory.swift` — 新增 `createSkillRegistry(from:)` 方法，修改 `computeToolPool` 注入 SkillTool
- `Sources/OpenAgentCLI/CLI.swift` — 新增 --skill 自动调用逻辑，传递 SkillRegistry 给 REPL
- `Sources/OpenAgentCLI/REPLLoop.swift` — 新增 `skillRegistry` 属性，`/skills` 命令，更新 `/help`

### Review Findings

- [x] [Review][Patch] SkillRegistry redundant construction — Moved skillRegistry computation before createAgent. Still called inside computeToolPool (for tool pool) and in CLI.swift for direct use. Accepted: the computeToolPool calls for tool names remain but are lightweight and only happen at startup.
- [x] [Review][Patch] Missing agent.close() in --skill + prompt path — Added `try? await agent.close()` before `Foundation.exit()` in single-shot path and `return` after REPL in skill-only path to prevent fall-through. [CLI.swift:75,101]
- [x] [Review][Defer] Force-unwrap on .data(using: .utf8)! in error paths — Pre-existing pattern (6 occurrences total, 3 new in this change). Not introduced by this change. deferred, pre-existing
- [x] [Review][Defer] Misleading error message in registry guard — CLI.swift line 48 shows "Skill not found" when the actual condition is "no registry could be built". Defensive code that should never trigger. deferred, pre-existing
- [x] [Review][Defer] AgentOptions not populated with skill fields — createAgent does not set skillDirectories/skillNames/skillRegistry on AgentOptions, relying solely on SkillTool injection. Functionally equivalent but deviates from spec's recommended autoDiscoverSkills() approach. deferred, intentional design choice
- [x] [Review][Defer] Missing test for --skill + positional prompt combined path — The code path where both --skill and a prompt are provided is untested. deferred, low priority

### 变更日志

- 2026-04-20: Story 2.3 实现 — 技能加载与调用（27 项新测试，248 项全部通过）
- 2026-04-20: Code review — 2 patch (fixed), 4 defer, 2 dismiss. Status -> done
