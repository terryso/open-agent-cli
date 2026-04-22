# 下一阶段功能储备

**创建日期：** 2026-04-22
**状态：** 待定（所有 PRD Story 已完成，以下为 PRD 之外的建议功能）
**来源：** PM Agent (John) 基于 PRD 审查和代码现状分析

---

## 阶段 1: SDK 验证收尾（核心使命）

PRD 定义的 5 项验证完成标准中，以下尚未系统完成：

### 8.2: 端到端场景验证

PRD 要求"至少 3 个真实场景端到端验证通过"：

- **场景 A：多轮编程任务** — 工具调用 + 会话持久化
  - 启动 CLI → "帮我创建一个 Swift Hello World 项目" → Agent 调用 Write 工具
  - "运行它" → Agent 调用 Bash 工具
  - 退出 → 重启 CLI → 自动恢复会话 → "给它加个命令行参数"
  - 验证：跨会话连续性、工具调用链正确

- **场景 B：MCP 集成 + SubAgent 委派**
  - 配置 MCP 服务器 → 提交复杂任务 → Agent 连接 MCP 并使用外部工具
  - Agent 派生子代理执行子任务 → 子代理汇报结果
  - 验证：MCP 工具发现/调用正常、子代理生命周期正确

- **场景 C：权限控制 + Hook 回调**
  - 以 `--mode plan` 启动 → Agent 提出计划 → 用户批准 → 执行
  - Hook 在工具执行前记录日志
  - 验证：权限控制生效、Hook 回调正确触发

### 8.3: API 缺口报告

- 扫描所有 `// SDK-GAP:` 注释
- 为每个缺口在 SDK 仓库创建 Issue
- 输出结构化的 API 缺口清单文档

### 8.4: 跨平台验证

- 在 Linux (Ubuntu 20.04+) 上编译运行
- 验证所有 P0 功能在 Linux 上行为一致
- 记录平台差异（如有）

---

## 阶段 2: REPL 体验升级

当前 REPL 使用原始的 `readLine`，缺少现代 CLI 工具的基本交互能力。

### 9.1: Tab 命令补全

- 按 Tab 自动补全 `/` 命令
- 补全 `/mcp` → `/mcp status` / `/mcp reconnect`
- 补全 `/mode` → 列出所有有效模式
- 补全 `/model` → 列出常用模型
- 补全文件路径（工具参数场景）

**复杂度：** 中（需要自定义 readline 或引入 swift-line-editing）
**用户价值：** 高

### 9.2: 历史回溯

- 上/下箭头浏览之前输入的命令
- 历史持久化到 `~/.openagent/history`
- `/history` 命令查看完整历史

**复杂度：** 低
**用户价值：** 高

### 9.3: 多行输入

- 用 `\` 续行
- 或用 `"""` 包裹多行文本
- 显示续行提示符 `...>`

**复杂度：** 中
**用户价值：** 中

### 9.4: 欢迎界面

启动时显示：
```
OpenAgentCLI v1.0.0 (OpenAgentSDK v0.x.x)
Model: glm-5.1 | Tools: 10 core | Mode: default
Type /help for available commands.
```

**复杂度：** 低
**用户价值：** 中

### 9.5: 彩色提示符

- `>` 带颜色显示当前状态
- 不同权限模式使用不同颜色（default=绿, plan=黄, bypass=红）
- 显示当前模型名缩写

**复杂度：** 低
**用户价值：** 低（但有专业感）

---

## 阶段 3: 高级 Agent 能力

PRD 中标记但实现较浅的能力，深度集成到 REPL 层。

### 10.1: Task/Todo REPL 命令

- `/tasks` — 列出当前会话的任务
- `/task <id>` — 查看任务详情
- 集成 SDK 的 TaskStore 到 REPL 界面

**依据：** FR8.4 (P2) SendMessage 相关的 Task/Team 工具族

### 10.2: Worktree REPL 命令

- `/worktree` — 显示当前 worktree 状态
- `/worktree enter <name>` — 进入 worktree
- `/worktree exit` — 退出 worktree

**依据：** FR3.3 Specialist 层中的 Worktree 工具

### 10.3: Session 导出

- `/export` — 将当前会话导出为 Markdown 文件
- `/export json` — 导出为 JSON 格式
- 用于分享和记录 AI 辅助的工作过程

**依据：** 新需求，PRD 未覆盖但有实际价值

### 10.4: 配置向导

- 首次运行时检测缺少 API Key，引导用户配置
- `openagent --setup` 交互式配置向导
- 配置 provider、model、default mode 等

**依据：** NFR3.1 "零配置即可使用" 的进一步优化

---

## 阶段 4: 分发与可达性

### 11.1: Homebrew Formula

- 创建 Homebrew formula
- `brew install openagent` 一键安装
- 支持自动更新

### 11.2: GitHub Release 自动化

- CI/CD 编译 macOS (arm64/x86_64) 和 Linux 二进制
- 自动发布到 GitHub Releases
- 附带 SHA256 校验和

### 11.3: Docker 镜像

- 基于 Swift Docker 镜像
- 用于 CI/CD 管道集成
- `docker run openagent "问题"`

### 11.4: Shell 自动补全

- 生成 Bash/Zsh/Fish 补全脚本
- `openagent --generate-completion bash > /etc/bash_completion.d/openagent`
- 补全所有 CLI 参数

---

## 优先级矩阵

| 功能 | 用户价值 | 实现复杂度 | 建议优先级 |
|------|----------|-----------|-----------|
| 8.2 端到端验证 | 极高（核心使命） | 中 | P0 |
| 8.3 API 缺口报告 | 高（核心使命） | 低 | P0 |
| 9.2 历史回溯 | 高 | 低 | P1 |
| 9.4 欢迎界面 | 中 | 低 | P1 |
| 10.4 配置向导 | 中 | 低 | P1 |
| 9.1 Tab 补全 | 高 | 中 | P1 |
| 8.4 跨平台验证 | 中 | 中 | P2 |
| 9.3 多行输入 | 中 | 中 | P2 |
| 10.3 Session 导出 | 中 | 低 | P2 |
| 9.5 彩色提示符 | 低 | 低 | P2 |
| 11.2 GitHub Release | 中 | 中 | P3 |
| 11.1 Homebrew | 中 | 中 | P3 |
| 10.1 Task 命令 | 中 | 中 | P3 |
| 10.2 Worktree 命令 | 低 | 中 | P3 |
| 11.3 Docker | 低 | 中 | P4 |
| 11.4 Shell 补全 | 低 | 低 | P4 |
