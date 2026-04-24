---
title: '修复交互模式中文(CJK)输入乱码'
type: 'bugfix'
created: '2026-04-24'
status: 'done'
context: []
baseline_commit: '681f0b2'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** linenoise-swift 库逐字节读取输入 (`readCharacter` → `UInt8`)，将多字节 UTF-8 字符的每个字节当作独立的 Latin-1 字符插入，导致中文/日文/韩文等多字节字符在交互模式中显示为乱码。

**Approach:** 用 [CommandLineKit](https://github.com/objecthub/swift-commandlinekit) 替换 linenoise-swift。CommandLineKit 基于 linenoise-swift 改进，原生支持 Unicode 多字节输入、使用 `text.utf8.count` 正确计算写入字节长度。

## Boundaries & Constraints

**Always:** `LinenoiseInputReader` 的 `InputReading` 协议接口不变；`readLine(prompt:)` 签名不变。

**Ask First:** 无。

**Never:** 不修改 `REPLLoop.swift`；不引入新的系统依赖。

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| ASCII 输入 | 输入 `hello` | 正常显示、编辑、提交 | N/A |
| 中文单字输入 | 输入 `你` (E4 BD A0) | 正确显示为一个中文字符 | N/A |
| 中文混合输入 | 输入 `hello你好world` | 混合字符串正确显示和编辑 | N/A |
| 中文退格 | 输入 `你好` 后按 Backspace | 删除 `好`，保留 `你` | N/A |
| 中文 history | 提交 `测试` 后按上箭头 | 正确回显 `测试` | N/A |
| 中文 Tab 补全 | buffer 含中文时按 Tab | 补全回调收到正确的中文 buffer | N/A |
| Ctrl+C | 编辑中按 Ctrl+C | 抛出 CTRLC 错误，REPL 捕获并重新显示 prompt | N/A |
| Ctrl+D | 空行按 Ctrl+D | 返回 nil，REPL 退出 | N/A |

</frozen-after-approval>

## Code Map

- `Package.swift` -- 替换 linenoise-swift 依赖为 CommandLineKit
- `Sources/OpenAgentCLI/LinenoiseInputReader.swift` -- 更新 import 和类型：`LineNoise` → `LineReader`，`LinenoiseError` → `LineReaderError`
- `Tests/OpenAgentCLITests/LinenoiseInputReaderTests.swift` -- 同步更新 import 和类型名（如存在）

## Tasks & Acceptance

**Execution:**
- [x] `Package.swift` -- 移除 linenoise-swift 依赖，添加 CommandLineKit（`https://github.com/objecthub/swift-commandlinekit`），更新 target 依赖名
- [x] `Sources/OpenAgentCLI/LinenoiseInputReader.swift` -- (1) `import LineNoise` → `import CommandLineKit`；(2) `LineNoise` → `LineReader`（处理 failable init）(3) `linenoise.getLine(prompt:)` → `lineReader.readLine(prompt:)`；(4) `LinenoiseError.CTRL_C` → `LineReaderError.CTRLC`
- [x] 测试文件 -- 无需修改（测试通过 LinenoiseInputReader 间接使用，API 未变）

**Acceptance Criteria:**
- Given 项目根目录, when 运行 `swift build`, then 编译通过无错误
- Given 项目根目录, when 运行 `swift test`, then 所有现有测试通过
- Given 交互模式启动, when 用户输入中文字符, then 终端正确显示中文而非乱码

## Spec Change Log

## Verification

**Commands:**
- `swift build` -- expected: 编译成功
- `swift test` -- expected: 所有测试通过
- 手动运行 `openagent` 输入中文验证显示正确
