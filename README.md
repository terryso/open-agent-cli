# OpenAgentCLI

[![Swift](https://img.shields.io/badge/Swift-6.1-orange)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)](https://developer.apple.com/macos/)
[![CI](https://github.com/terryso/open-agent-cli/actions/workflows/ci.yml/badge.svg)](https://github.com/terryso/open-agent-cli/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/terryso/6cab3cc82b416a51b214640b36a1696e/raw/coverage.json)](https://github.com/terryso/open-agent-cli/actions)
[![BMAD](https://bmad-badge.vercel.app/terryso/open-agent-cli.svg)](https://github.com/bmad-code-org/BMAD-METHOD)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](./LICENSE)

Command-line AI Agent built with [OpenAgentSDK (Swift)](https://github.com/terryso/open-agent-sdk-swift) — a terminal tool that demonstrates the full power of the SDK's public API through a real, usable product.

> **The ultimate proof of SDK capability.** If this CLI runs smoothly, the SDK's public API is complete. If it hits a wall, we've found an API gap.

## Features

- **Streaming Output** — Real-time agent responses with ANSI-styled terminal output
- **Interactive REPL** — Multi-turn conversations in the terminal
- **Single-Shot Mode** — Quick one-off queries via command line
- **Tool Visibility** — See which tools the agent calls and their results
- **Session Persistence** — Save, resume, and fork conversations
- **MCP Integration** — Connect external tool servers via Model Context Protocol
- **Permission Control** — Choose from 6 permission modes for safe execution
- **Multi-Provider LLM** — Anthropic (Claude) and OpenAI-compatible APIs (GLM, Ollama, etc.)
- **Hook System** — Lifecycle event handlers for customization

## Quick Start

### Build & Run

```bash
git clone https://github.com/terryso/open-agent-cli.git
cd open-agent-cli
swift build
```

### Configure

Create `~/.openagent/config.json`:

```json
{
  "apiKey": "your-api-key",
  "provider": "openai",
  "baseURL": "https://open.bigmodel.cn/api/coding/paas/v4",
  "model": "glm-5.1"
}
```

Or set environment variables:

```bash
export OPENAGENT_API_KEY=your-api-key
```

### Usage

```bash
# Single-shot query
swift run openagent "Explain Swift concurrency in one paragraph."

# Interactive REPL
swift run openagent

# With options
swift run openagent --model claude-sonnet-4-6 --max-turns 5 "Analyze this codebase"
```

## Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--model` | LLM model to use | `glm-5.1` |
| `--api-key` | API key | config file or env |
| `--provider` | LLM provider (`anthropic`, `openai`) | `anthropic` |
| `--base-url` | Custom API endpoint | — |
| `--mode` | Permission mode | `default` |
| `--max-turns` | Maximum agent turns | `10` |
| `--max-budget-usd` | Cost cap in USD | — |
| `--system-prompt` | Custom system prompt | — |
| `--thinking` | Thinking budget tokens | — |
| `--log-level` | Log level (`debug`, `info`, `warn`, `error`) | — |
| `--version` | Print version | — |
| `--help` | Print help | — |

## Architecture

```
CLI Entry Point (ArgumentParser)
       │
       ▼
  AgentFactory ──── OpenAgentSDK.createAgent()
       │
       ▼
  OutputRenderer ◀── AsyncStream<SDKMessage>
       │                   │
       ▼                   ▼
   Terminal           Agent Loop (SDK)
```

The CLI consumes only `import OpenAgentSDK` — zero internal module access. Every feature exercises the SDK's public API surface.

## Requirements

- Swift 6.1+
- macOS 13+
- [OpenAgentSDK (Swift)](https://github.com/terryso/open-agent-sdk-swift) (as local dependency)

## Development

```bash
# Build
swift build

# Run tests (124 tests)
swift test

# Run with coverage
swift test --enable-code-coverage

# Open in Xcode
open Package.swift
```

## Related Projects

- [OpenAgentSDK (Swift)](https://github.com/terryso/open-agent-sdk-swift) — The SDK this CLI is built on
- [OpenAgentSDK (TypeScript)](https://github.com/codeany-ai/open-agent-sdk-typescript) — TypeScript version
- [OpenAgentSDK (Go)](https://github.com/codeany-ai/open-agent-sdk-go) — Go version

## License

MIT
