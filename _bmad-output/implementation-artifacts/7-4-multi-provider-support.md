# Story 7.4: 多提供商支持

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为一个用户，
我想要使用非 Anthropic 的 LLM 提供商，
以便我可以将 CLI 与 OpenAI 或其他兼容的 API 一起使用。

## Acceptance Criteria

1. **假设** 传入了 `--provider openai --base-url https://api.openai.com/v1`
   **当** 创建 Agent
   **那么** 使用兼容 OpenAI 的客户端

2. **假设** 传入了 `--provider anthropic`（或默认）
   **当** 创建 Agent
   **那么** 使用 Anthropic 客户端

3. **假设** 传入了 `--provider openai` 但未传入 `--base-url`
   **当** 创建 Agent
   **那么** 使用 OpenAI 的默认 base URL（由 SDK 决定）

4. **假设** 传入了 `--provider openai` 但未传入 `--model`
   **当** 创建 Agent
   **那么** 使用适合该提供商的默认模型（由 SDK 默认值决定）

5. **假设** 配置文件包含 `"provider": "openai"` 和 `"baseURL": "https://my-proxy.example.com/v1"`
   **当** CLI 启动且未传入 `--provider` 和 `--base-url`
   **那么** 从配置文件加载提供商和 base URL

6. **假设** 传入了无效的提供商名称（如 `--provider google`）
   **当** CLI 启动
   **那么** 显示清晰的错误信息，列出有效的提供商

7. **假设** 传入了 `--provider openai`
   **当** Agent 调用工具并产生流式响应
   **那么** 输出行为与 Anthropic 提供商完全一致（OutputRenderer 无需变更）

## Tasks / Subtasks

- [ ] Task 1: 验证 SDK LLMProvider 支持完整性 (AC: #1, #2, #3)
  - [ ] 确认 `LLMProvider.openai` 在 SDK 中已完整实现（非 stub）
  - [ ] 确认 `AgentOptions.provider` 和 `AgentOptions.baseURL` 正确传递给底层 HTTP 客户端
  - [ ] 确认 `--provider openai` 无 `--base-url` 时 SDK 使用 OpenAI 默认 URL
  - [ ] 如发现 SDK-GAP，用 `// SDK-GAP:` 注释记录

- [ ] Task 2: 更新 CLI 默认模型逻辑 (AC: #4)
  - [ ] 在 `AgentFactory` 或 `CLI.swift` 中，当 provider 为 openai 且未指定 model 时，使用 OpenAI 合适的默认模型而非 `glm-5.1`
  - [ ] 确保默认模型选择逻辑与 `ParsedArgs.model` 默认值协调
  - [ ] 测试：`--provider openai` 不传 `--model` 时使用正确的默认模型

- [ ] Task 3: 验证配置文件提供商支持 (AC: #5)
  - [ ] 确认 `CLIConfig.provider` 和 `CLIConfig.baseURL` 已存在于 ConfigLoader（已由 Story 7.3 添加）
  - [ ] 确认 `ConfigLoader.apply()` 正确将 provider 和 baseURL 从配置文件应用到 ParsedArgs
  - [ ] 测试：配置文件中设置 `"provider": "openai"` 被正确加载

- [ ] Task 4: 增强验证和错误信息 (AC: #6)
  - [ ] 确认 `AgentFactoryError.invalidProvider` 提供清晰的错误信息（已有）
  - [ ] 确认 `ArgumentParser` 中 `validProviders` 列表与 SDK `LLMProvider` 枚举同步（已有）
  - [ ] 测试：`--provider google` 产生包含有效提供商列表的错误信息

- [ ] Task 5: 端到端验证 (AC: #7)
  - [ ] 确认 OutputRenderer 无需修改即可正确渲染 OpenAI 提供商的响应
  - [ ] 确认流式输出、工具调用显示、权限提示等均与提供商无关
  - [ ] 测试：`--provider openai` 的完整流程（创建 Agent、发送消息、接收流式响应）

- [ ] Task 6: 添加测试覆盖 (AC: #1-#7)
  - [ ] 测试：`mapProvider("openai")` 返回 `.openai`
  - [ ] 测试：`mapProvider("anthropic")` 返回 `.anthropic`
  - [ ] 测试：`mapProvider(nil)` 返回 `.anthropic`（默认）
  - [ ] 测试：`mapProvider("google")` 抛出 `invalidProvider` 错误
  - [ ] 测试：`--provider openai` 不传 `--base-url` 时 Agent 仍可创建
  - [ ] 测试：配置文件 provider 字段被正确应用
  - [ ] 测试：`--provider openai` 不传 `--model` 时使用 OpenAI 默认模型
  - [ ] 回归测试：所有现有 AgentFactoryTests 通过

## Dev Notes

### 当前实现分析

本故事的核心工作范围较小，因为 CLI 的多提供商支持在之前的故事中已基本搭好框架。以下是对当前代码的详细分析：

#### ArgumentParser.swift — 已完成

`--provider` 标志已完整实现：
- 第 138-145 行：解析 `--provider` 参数，验证值是否在 `validProviders` 集合中
- 第 60-62 行：`validProviders` 定义为 `["anthropic", "openai"]`
- 第 79 行：`--provider` 在 `valueFlags` 集合中
- 第 222 行：`--base-url` 在 `valueFlags` 集合中
- `ParsedArgs` 结构体已有 `provider: String?` 和 `baseURL: String?` 字段
- `explicitlySet` 已正确追踪这两个字段

**无需修改 ArgumentParser.swift。**

#### AgentFactory.swift — 已完成

`mapProvider()` 方法已完整实现（第 215-223 行）：
```swift
static func mapProvider(_ value: String?) throws -> LLMProvider {
    guard let value else {
        return .anthropic  // CLI default
    }
    guard let provider = LLMProvider(rawValue: value) else {
        throw AgentFactoryError.invalidProvider(value)
    }
    return provider
}
```

`AgentFactoryError.invalidProvider` 已定义（第 9 行），错误信息清晰。
`createAgent(from:)` 中第 68 行已调用 `mapProvider(args.provider)`。
`AgentOptions` 构造中 `provider` 和 `baseURL` 已正确传递（第 118-119 行）。

**大部分无需修改。可能需要调整默认模型逻辑。**

#### ConfigLoader.swift — 已完成

`CLIConfig` 已有 `provider: String?` 和 `baseURL: String?` 字段（第 10-11 行）。
`ConfigLoader.apply()` 已正确处理这两个字段（第 75-80 行）：
```swift
if !args.explicitlySet.contains("baseURL"), let url = config.baseURL {
    args.baseURL = url
}
if !args.explicitlySet.contains("provider"), let provider = config.provider {
    args.provider = provider
}
```

**无需修改 ConfigLoader.swift。**

#### SDK LLMProvider — 已就绪

SDK 定义了 `LLMProvider` 枚举（AgentTypes.swift 第 7-12 行）：
```swift
public enum LLMProvider: String, Sendable, Equatable {
    case anthropic
    case openai
}
```

`AgentOptions` 的 `provider` 参数默认为 `.anthropic`，`baseURL` 默认为 `nil`（使用提供商默认 URL）。

### 唯一可能需要修改的文件

1. **`AgentFactory.swift`** — 可能需要添加默认模型选择逻辑（当 provider 为 openai 时使用非 `glm-5.1` 的默认模型）
2. **`Tests/OpenAgentCLITests/AgentFactoryTests.swift`** — 添加提供商相关的测试

### 默认模型问题

当前 CLI 默认模型是 `glm-5.1`（在 ParsedArgs 中硬编码）。这是 Anthropic/GLM 风格的模型名称。当用户使用 `--provider openai` 时，需要考虑：

- **方案 A（推荐）：** 保持 `glm-5.1` 作为 CLI 默认值不变。当 provider 为 openai 时，由 SDK 的 `AgentOptions` 默认值决定模型。SDK 的 `AgentOptions.model` 默认值是 `"claude-sonnet-4-6"`，但 CLI 会覆盖它为 `"glm-5.1"`。
- **方案 B：** 在 AgentFactory 中根据 provider 调整默认模型。但这增加了维护成本，且 CLI 的理念是"让用户通过 --model 指定"。

**建议采用方案 A** — 当用户不传 `--model` 时，`ParsedArgs.model` 默认为 `"glm-5.1"`，这个值会传递给 SDK。如果用户使用 `--provider openai`，他们应该同时传入 `--model` 指定 OpenAI 的模型名称。CLI 不做自动模型选择，保持简单。

这与 AC#4 的描述一致："使用适合该提供商的默认模型（由 SDK 默认值决定）"。但实际上 CLI 的 `ParsedArgs.model` 有硬编码默认值 `"glm-5.1"`，所以即使用户不传 `--model`，CLI 也会传 `"glm-5.1"` 给 SDK。

**最终建议：** 在 `AgentFactory.createAgent(from:)` 中，当 provider 为 openai 且 model 未被用户显式设置时（`!args.explicitlySet.contains("model")`），不传 model 给 AgentOptions（使用 SDK 默认）。或者保持当前行为，让用户自行指定。**选择权在开发者。**

### 关键约束

1. **零 internal 访问** — 整个项目仅允许 `import OpenAgentSDK`
2. **零第三方依赖** — 不引入外部库
3. **不修改 SDK** — 如遇 SDK 限制，记录为 `// SDK-GAP:` 注释
4. **OutputRenderer 与提供商无关** — 所有输出渲染逻辑已通过 `SDKMessage` 抽象，不依赖特定提供商的响应格式
5. **配置分层正确** — CLI 参数 > 环境变量 > 配置文件 > SDK 默认值

### 不要做的事

1. **不要修改 ArgumentParser.swift** — `--provider` 和 `--base-url` 解析已完整实现
2. **不要修改 ConfigLoader.swift** — provider 和 baseURL 配置文件加载已完整实现
3. **不要修改 OutputRenderer** — 输出渲染与提供商无关，通过 `SDKMessage` 抽象层工作
4. **不要为不同提供商引入不同的代码路径** — CLI 应保持提供商无关的设计
5. **不要硬编码提供商特定的默认 URL** — 让 SDK 处理默认 URL 逻辑
6. **不要修改 CLI.swift 的主流程** — 创建 Agent 的流程已正确传递 provider 和 baseURL

### 前一故事的关键学习

Story 7.3（持久化配置文件）完成后的关键信息：

1. **`explicitlySet` 机制已就绪** — 可以精确区分"用户未传此参数"和"用户传了默认值"
2. **ConfigLoader 已支持所有字段** — provider 和 baseURL 已在配置文件加载路径中
3. **测试模式已建立** — AgentFactoryTests 使用 `makeArgs` 辅助方法构建测试参数
4. **全量回归测试通过** — 548 个测试，0 个失败

### 项目结构说明

本故事可能修改 1-2 个现有文件，不创建新文件：

```
Sources/OpenAgentCLI/
  AgentFactory.swift       # 可能修改：调整默认模型逻辑
  (ArgumentParser.swift    # 无需修改)
  (ConfigLoader.swift      # 无需修改)
  (CLI.swift               # 无需修改)
  (OutputRenderer.swift    # 无需修改)

Tests/OpenAgentCLITests/
  AgentFactoryTests.swift  # 修改：添加提供商相关测试
```

### 测试策略

**新增测试分布预期：**

| 测试方法名 | 覆盖 AC | 说明 |
|-----------|---------|------|
| testMapProvider_openai_returnsOpenai | #1 | mapProvider("openai") 返回 .openai |
| testMapProvider_anthropic_returnsAnthropic | #2 | mapProvider("anthropic") 返回 .anthropic |
| testMapProvider_nil_returnsAnthropicDefault | #2 | mapProvider(nil) 返回 .anthropic |
| testMapProvider_invalid_throwsError | #6 | mapProvider("google") 抛出 invalidProvider |
| testMapProvider_errorMessage_containsValidProviders | #6 | 错误信息包含有效提供商列表 |
| testCreateAgent_openaiProvider_withoutBaseURL | #3 | --provider openai 不传 base-url 仍可创建 Agent |
| testCreateAgent_openaiProvider_withoutModel | #4 | --provider openai 不传 --model 时使用合理默认 |
| testCreateAgent_fullOpenaiConfig | #1, #7 | --provider openai --base-url --model 完整配置 |
| testConfigLoader_providerApplied | #5 | 配置文件 provider 字段正确应用 |
| testConfigLoader_baseURLApplied | #5 | 配置文件 baseURL 字段正确应用 |
| testConfigLoader_providerNotOverriddenByCliArg | #5 | CLI --provider 不被配置文件覆盖 |

**注意：** 部分 mapProvider 测试可能已在现有 AgentFactoryTests 中。检查后避免重复。

### SDK API 参考

本故事使用以下 SDK API（均已在项目中使用过）：

- `LLMProvider` 枚举 — `.anthropic`, `.openai`（String rawValue）
- `AgentOptions.provider` — 类型 `LLMProvider`，默认 `.anthropic`
- `AgentOptions.baseURL` — 类型 `String?`，默认 `nil`（使用提供商默认 URL）
- `AgentOptions.model` — 类型 `String`，默认 `"claude-sonnet-4-6"`（但 CLI 覆盖为 `"glm-5.1"`）

无新 SDK API 需要引入。无 SDK-GAP 预期。

### 架构合规性

本故事涉及架构文档中的 **FR1.4** 和 **FR1.5**：

- **FR1.4:** 通过 `--base-url` 参数配置自定义 API 端点 (P1)
- **FR1.5:** 通过 `--provider` 参数选择 LLM 提供商 (P1)

**FR 覆盖映射：**
- FR1.4 -> Epic 7, Story 7.4 (本故事)
- FR1.5 -> Epic 7, Story 7.4 (本故事)

**架构模式遵循：**
- "薄编排层" — CLI 仅传递 provider 选择给 SDK，不实现提供商特定逻辑
- "SDK 之上的薄 CLI" — 所有 HTTP 客户端逻辑由 SDK 处理
- "基于协议的分离" — OutputRenderer 通过 SDKMessage 抽象，与提供商无关

[Source: epics.md#Story 7.4]
[Source: prd.md#FR1.4, FR1.5]
[Source: architecture.md#SDK 边界 — "CLI 仅在单一点接触 SDK"]
[Source: architecture.md#配置分层 — "CLI 参数 > 环境变量 > 配置文件 > SDK 默认值"]

### 延迟工作

- **更多提供商支持** — 当 SDK 添加新的 LLMProvider case（如 `.google`, `.mistral`）时，只需更新 `validProviders` 集合
- **提供商特定的配置验证** — 如 OpenAI 需要 org ID 等额外参数
- **提供商健康检查** — `/mcp status` 风格的提供商连接状态检查

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.4]
- [Source: _bmad-output/planning-artifacts/prd.md#FR1.4, FR1.5]
- [Source: _bmad-output/planning-artifacts/architecture.md#SDK 边界]
- [Source: _bmad-output/planning-artifacts/architecture.md#配置分层]
- [Source: Sources/OpenAgentCLI/AgentFactory.swift — mapProvider(), createAgent()]
- [Source: Sources/OpenAgentCLI/ArgumentParser.swift — --provider, --base-url 解析]
- [Source: Sources/OpenAgentCLI/ConfigLoader.swift — provider, baseURL 配置加载]
- [Source: .build/checkouts/open-agent-sdk-swift/Sources/OpenAgentSDK/Types/AgentTypes.swift — LLMProvider enum]
- [Source: _bmad-output/implementation-artifacts/7-3-persistent-configuration-file.md — 前一故事]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
