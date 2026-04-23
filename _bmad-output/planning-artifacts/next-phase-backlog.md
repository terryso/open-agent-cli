# 下一阶段功能储备

**创建日期：** 2026-04-22
**最后更新：** 2026-04-23
**状态：** 进行中
**来源：** PM Agent (John) 基于 PRD 审查和代码现状分析
**技术决策：** 阶段 2 引入 [linenoise-swift](https://github.com/andybest/linenoise-swift)（纯 Swift readline 替代品）替代手写终端输入处理

---

## 阶段 1: SDK 验证收尾（核心使命） — 已完成 ✅

**完成日期：** 2026-04-22

PRD 定义的核心验证使命已全部完成。708 个测试通过，Epic 1-8 全部交付。

### 8.2: 端到端场景验证 — 已完成 ✅

**完成提交：** `90cea8f` feat: expose sessionId in JSON output + add E2E scenario tests — Story 8.2

### 8.3: API 缺口报告 / Deferred Work 清零 — 已完成 ✅

**完成提交：** `563ece0` fix: resolve last deferred items — Story 8.3 (Epic 8 complete)

### 8.4: 跨平台验证 — 部分完成

- macOS (arm64) 已验证通过
- Linux 验证待执行（不阻塞后续开发）

---

## 阶段 2: REPL 体验升级 — 已规划 📋

**规划日期：** 2026-04-23
**Epic 文档：** `epics.md` — Epic 9

以下功能已分解为 Epic 9（5 个 Story），按依赖顺序编号。技术方案基于 [linenoise-swift](https://github.com/andybest/linenoise-swift)：

### 9.1: 欢迎界面 — 已规划

- 启动时显示版本、模型、工具数、模式
- **复杂度：** 低 | **用户价值：** 中
- **Epic/Story：** Epic 9 — Story 9.1

### 9.2: 彩色提示符 — 已规划

- `>` 按权限模式变色（default=绿, plan=黄, bypass=红）
- **复杂度：** 低 | **用户价值：** 低（但有专业感）
- **Epic/Story：** Epic 9 — Story 9.2

### 9.3: 历史回溯 — 已规划

- 上/下箭头浏览之前输入的命令
- 历史持久化到 `~/.openagent/history`
- 引入 linenoise-swift，创建 `LinenoiseInputReader`（替换 `FileHandleInputReader`）
- **复杂度：** 低（linenoise 内置） | **用户价值：** 高
- **Epic/Story：** Epic 9 — Story 9.3

### 9.4: Tab 命令补全 — 已规划

- 按 Tab 自动补全 `/` 命令和子命令
- 利用 linenoise 的 `completionCallback` API
- 依赖 Story 9.3 的 `LinenoiseInputReader`
- **复杂度：** 低（linenoise 内置） | **用户价值：** 高
- **Epic/Story：** Epic 9 — Story 9.4

### 9.5: 多行输入 — 已规划

- 用 `\` 续行或 `"""` 包裹多行文本
- 多行状态机在 REPLLoop 层实现，linenoise 负责行级输入
- 依赖 Story 9.3 的 `LinenoiseInputReader`
- **复杂度：** 中 | **用户价值：** 中
- **Epic/Story：** Epic 9 — Story 9.5

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

| 功能 | 用户价值 | 实现复杂度 | 当前状态 | Epic/Story |
|------|----------|-----------|---------|-----------|
| 8.2 端到端验证 | 极高（核心使命） | 中 | ✅ 已完成 | Epic 8 |
| 8.3 API 缺口报告 | 高（核心使命） | 低 | ✅ 已完成 | Epic 8 |
| 9.1 欢迎界面 | 中 | 低 | 📋 已规划 | Epic 9 — Story 9.1 |
| 9.2 彩色提示符 | 低 | 低 | 📋 已规划 | Epic 9 — Story 9.2 |
| 9.3 历史回溯 | 高 | 低（linenoise） | 📋 已规划 | Epic 9 — Story 9.3 |
| 9.4 Tab 补全 | 高 | 低（linenoise） | 📋 已规划 | Epic 9 — Story 9.4 |
| 9.5 多行输入 | 中 | 中 | 📋 已规划 | Epic 9 — Story 9.5 |
| 10.4 配置向导 | 中 | 低 | 待定 | — |
| 8.4 跨平台验证 | 中 | 中 | 部分完成 | — |
| 10.3 Session 导出 | 中 | 低 | 待定 | — |
| 11.2 GitHub Release | 中 | 中 | 待定 | — |
| 11.1 Homebrew | 中 | 中 | 待定 | — |
| 10.1 Task 命令 | 中 | 中 | 待定 | — |
| 10.2 Worktree 命令 | 低 | 中 | 待定 | — |
| 11.3 Docker | 低 | 中 | 待定 | — |
| 11.4 Shell 补全 | 低 | 低 | 待定 | — |
